// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Ownable } from "./utils/Ownable.sol";
import { IERC20 } from "./interfaces/IERC20.sol";
import { IWETH9 } from "./interfaces/IWETH9.sol";
import { ISTBToken } from "./interfaces/ISTBToken.sol";
import { IOracleHub } from "./interfaces/IOracleHub.sol";

contract StableVault is Ownable {
    struct Vault {
        uint256 collateralAmount;
        uint256 debtPrincipal;
        uint256 accruedFee;
        uint256 lastAccruedTimestamp;
        uint256 lastRiskActionBlock;
    }

    uint256 private constant BPS = 10_000;
    uint256 private constant WAD = 1e18;
    uint256 private constant YEAR = 365 days;

    IWETH9 public immutable weth;
    ISTBToken public immutable stb;
    IOracleHub public immutable oracleHub;

    mapping(address => Vault) private vaults;
    mapping(address => bool) public isKeeper;

    uint256 public minCollateralRatioBps = 15_000;
    uint256 public targetCollateralRatioBps = 17_000;
    uint256 public liquidationBonusBps = 800;
    uint256 public maxCloseFactorBps = 5_000;
    uint256 public stabilityFeeBps = 400;

    uint256 public protocolReserveStb;
    uint256 public systemBadDebt;
    bool public paused;

    error Paused();
    error InvalidAmount();
    error NotKeeper(address caller);
    error OracleBreaker();
    error InsufficientCollateral();
    error HealthyVault();
    error SameBlockRiskAction();
    error InvalidParams();

    event Deposited(address indexed owner, uint256 wethAmount);
    event Withdrawn(address indexed owner, uint256 wethAmount);
    event Minted(address indexed owner, uint256 stbAmount);
    event Repaid(address indexed owner, uint256 stbAmount, uint256 feePaid, uint256 principalPaid);
    event Liquidated(
        address indexed owner,
        address indexed liquidator,
        uint256 repayAmount,
        uint256 seizedCollateral,
        uint256 badDebtDelta
    );
    event RiskParamsUpdated(
        uint256 minCollateralRatioBps,
        uint256 targetCollateralRatioBps,
        uint256 liquidationBonusBps,
        uint256 maxCloseFactorBps
    );
    event StabilityFeeUpdated(uint256 stabilityFeeBps);
    event PauseSet(bool paused);
    event KeeperSet(address indexed keeper, bool allowed);
    event BadDebtCovered(uint256 amount);
    event DemoModeSet(bool enabled);
    event DemoPriceSet(uint256 priceE18);
    event OracleConfigSet(uint256 spotMaxAge, uint256 twapMaxAge, uint256 maxDeviationBps);

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    constructor(address initialOwner, address wethToken, address stbToken, address oracle)
        Ownable(initialOwner)
    {
        weth = IWETH9(wethToken);
        stb = ISTBToken(stbToken);
        oracleHub = IOracleHub(oracle);
    }

    function deposit(uint256 wethAmount) external whenNotPaused {
        if (wethAmount == 0) revert InvalidAmount();
        Vault storage vault = vaults[msg.sender];
        _accrue(vault);
        vault.collateralAmount += wethAmount;

        require(
            IERC20(address(weth)).transferFrom(msg.sender, address(this), wethAmount),
            "WETH_TRANSFER"
        );

        emit Deposited(msg.sender, wethAmount);
    }

    function withdraw(uint256 wethAmount) external whenNotPaused {
        if (!oracleHub.canRiskActionProceed()) revert OracleBreaker();
        if (wethAmount == 0) revert InvalidAmount();
        Vault storage vault = vaults[msg.sender];
        _accrue(vault);
        if (vault.collateralAmount < wethAmount) revert InsufficientCollateral();

        vault.collateralAmount -= wethAmount;
        _requireHealthy(vault);
        vault.lastRiskActionBlock = block.number;

        require(IERC20(address(weth)).transfer(msg.sender, wethAmount), "WETH_TRANSFER");

        emit Withdrawn(msg.sender, wethAmount);
    }

    function mint(uint256 stbAmount) external whenNotPaused {
        if (!oracleHub.canRiskActionProceed()) revert OracleBreaker();
        if (stbAmount == 0) revert InvalidAmount();
        Vault storage vault = vaults[msg.sender];
        _accrue(vault);

        vault.debtPrincipal += stbAmount;
        _requireHealthy(vault);
        vault.lastRiskActionBlock = block.number;

        stb.mint(msg.sender, stbAmount);

        emit Minted(msg.sender, stbAmount);
    }

    function repay(uint256 stbAmount) external whenNotPaused {
        if (stbAmount == 0) revert InvalidAmount();
        Vault storage vault = vaults[msg.sender];
        _accrue(vault);

        uint256 debt = vault.debtPrincipal + vault.accruedFee;
        if (debt == 0) revert InvalidAmount();

        uint256 payAmount = stbAmount > debt ? debt : stbAmount;

        require(stb.transferFrom(msg.sender, address(this), payAmount), "STB_TRANSFER");

        (uint256 feePaid, uint256 principalPaid) = _applyDebtPayment(vault, payAmount);
        protocolReserveStb += feePaid;

        if (principalPaid > 0) {
            stb.burn(address(this), principalPaid);
        }

        emit Repaid(msg.sender, payAmount, feePaid, principalPaid);
    }

    function liquidate(address ownerAddress, uint256 repayAmount) external whenNotPaused {
        if (!oracleHub.canRiskActionProceed()) revert OracleBreaker();
        if (repayAmount == 0) revert InvalidAmount();

        if (!isKeeper[msg.sender] && msg.sender != ownerAddress) revert NotKeeper(msg.sender);

        Vault storage vault = vaults[ownerAddress];
        _accrue(vault);

        if (!_isLiquidatable(vault)) revert HealthyVault();
        if (block.number <= vault.lastRiskActionBlock) revert SameBlockRiskAction();

        uint256 debt = vault.debtPrincipal + vault.accruedFee;
        uint256 maxClose = (debt * maxCloseFactorBps) / BPS;

        uint256 targetRepay = _computeRepayForTarget(vault);
        uint256 cappedRepay = targetRepay;
        if (cappedRepay > maxClose) cappedRepay = maxClose;
        if (cappedRepay > debt) cappedRepay = debt;

        uint256 priceE18 = oracleHub.getValidatedPrice();
        uint256 maxRepayByCollateral =
            (vault.collateralAmount * priceE18 * BPS) / ((BPS + liquidationBonusBps) * WAD);

        uint256 finalRepay = repayAmount;
        if (finalRepay > cappedRepay) finalRepay = cappedRepay;
        if (finalRepay > maxRepayByCollateral) finalRepay = maxRepayByCollateral;
        if (finalRepay == 0) revert InvalidAmount();

        require(stb.transferFrom(msg.sender, address(this), finalRepay), "STB_TRANSFER");

        (uint256 feePaid, uint256 principalPaid) = _applyDebtPayment(vault, finalRepay);
        protocolReserveStb += feePaid;

        if (principalPaid > 0) {
            stb.burn(address(this), principalPaid);
        }

        uint256 seizeCollateral =
            (finalRepay * (BPS + liquidationBonusBps) * WAD) / (priceE18 * BPS);

        uint256 badDebtDelta;
        if (seizeCollateral > vault.collateralAmount) seizeCollateral = vault.collateralAmount;

        vault.collateralAmount -= seizeCollateral;

        if (vault.collateralAmount == 0) {
            uint256 remainingDebt = vault.debtPrincipal + vault.accruedFee;
            if (remainingDebt > 0) {
                badDebtDelta = remainingDebt;
                systemBadDebt += remainingDebt;
                vault.debtPrincipal = 0;
                vault.accruedFee = 0;
            }
        }

        require(IERC20(address(weth)).transfer(msg.sender, seizeCollateral), "WETH_TRANSFER");

        emit Liquidated(ownerAddress, msg.sender, finalRepay, seizeCollateral, badDebtDelta);
    }

    function coverBadDebt(uint256 amount) external onlyOwner {
        if (amount == 0) revert InvalidAmount();
        if (amount > protocolReserveStb) amount = protocolReserveStb;
        if (amount > systemBadDebt) amount = systemBadDebt;
        uint256 reserveTokenBalance = stb.balanceOf(address(this));
        if (amount > reserveTokenBalance) amount = reserveTokenBalance;

        if (amount == 0) revert InvalidAmount();

        protocolReserveStb -= amount;
        systemBadDebt -= amount;
        stb.burn(address(this), amount);

        emit BadDebtCovered(amount);
    }

    function setRiskParams(
        uint256 newMinCollateralRatioBps,
        uint256 newTargetCollateralRatioBps,
        uint256 newLiquidationBonusBps,
        uint256 newMaxCloseFactorBps
    ) external onlyOwner {
        if (
            newMinCollateralRatioBps <= BPS
                || newTargetCollateralRatioBps <= newMinCollateralRatioBps
                || newMaxCloseFactorBps == 0 || newMaxCloseFactorBps > BPS
                || newLiquidationBonusBps > 2_000
        ) revert InvalidParams();

        minCollateralRatioBps = newMinCollateralRatioBps;
        targetCollateralRatioBps = newTargetCollateralRatioBps;
        liquidationBonusBps = newLiquidationBonusBps;
        maxCloseFactorBps = newMaxCloseFactorBps;
        emit RiskParamsUpdated(
            newMinCollateralRatioBps,
            newTargetCollateralRatioBps,
            newLiquidationBonusBps,
            newMaxCloseFactorBps
        );
    }

    function setStabilityFeeBps(uint256 newStabilityFeeBps) external onlyOwner {
        if (newStabilityFeeBps > 2_000) revert InvalidParams();
        stabilityFeeBps = newStabilityFeeBps;
        emit StabilityFeeUpdated(newStabilityFeeBps);
    }

    function setPause(bool isPaused) external onlyOwner {
        paused = isPaused;
        emit PauseSet(isPaused);
    }

    function setKeeper(address keeperAddress, bool allowed) external onlyOwner {
        isKeeper[keeperAddress] = allowed;
        emit KeeperSet(keeperAddress, allowed);
    }

    function setDemoMode(bool enabled) external onlyOwner {
        _oracleAdminSetDemoMode(enabled);
        emit DemoModeSet(enabled);
    }

    function setDemoPrice(uint256 priceE18) external onlyOwner {
        if (priceE18 == 0 || priceE18 > 1e24) revert InvalidParams();
        _oracleAdminSetDemoPrice(priceE18);
        emit DemoPriceSet(priceE18);
    }

    function setOracleConfig(uint256 spotMaxAge, uint256 twapMaxAge, uint256 maxDeviationBps)
        external
        onlyOwner
    {
        _oracleAdminSetConfig(spotMaxAge, twapMaxAge, maxDeviationBps);
        emit OracleConfigSet(spotMaxAge, twapMaxAge, maxDeviationBps);
    }

    function getVault(address ownerAddress)
        external
        view
        returns (
            uint256 collateralAmount,
            uint256 debtPrincipal,
            uint256 accruedFee,
            uint256 debtWithFee,
            uint256 lastAccruedTimestamp,
            uint256 lastRiskActionBlock
        )
    {
        Vault memory vault = vaults[ownerAddress];
        return (
            vault.collateralAmount,
            vault.debtPrincipal,
            vault.accruedFee,
            _debtWithAccruedFee(vault),
            vault.lastAccruedTimestamp,
            vault.lastRiskActionBlock
        );
    }

    function getCollateralRatioBps(address ownerAddress) external view returns (uint256) {
        return _collateralRatioBps(vaults[ownerAddress]);
    }

    function isLiquidatable(address ownerAddress) external view returns (bool) {
        return _isLiquidatable(vaults[ownerAddress]);
    }

    function getSystemBadDebt() external view returns (uint256) {
        return systemBadDebt;
    }

    function _accrue(Vault storage vault) internal {
        if (vault.lastAccruedTimestamp == 0) {
            vault.lastAccruedTimestamp = block.timestamp;
            return;
        }

        if (
            (vault.debtPrincipal + vault.accruedFee) == 0
                || block.timestamp <= vault.lastAccruedTimestamp
        ) {
            vault.lastAccruedTimestamp = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - vault.lastAccruedTimestamp;
        uint256 fee = (vault.debtPrincipal * stabilityFeeBps * elapsed) / (BPS * YEAR);
        vault.accruedFee += fee;
        vault.lastAccruedTimestamp = block.timestamp;
    }

    function _debtWithAccruedFee(Vault memory vault) internal view returns (uint256) {
        if ((vault.debtPrincipal + vault.accruedFee) == 0 || vault.lastAccruedTimestamp == 0) {
            return vault.debtPrincipal + vault.accruedFee;
        }

        if (block.timestamp <= vault.lastAccruedTimestamp) {
            return vault.debtPrincipal + vault.accruedFee;
        }

        uint256 elapsed = block.timestamp - vault.lastAccruedTimestamp;
        uint256 fee = (vault.debtPrincipal * stabilityFeeBps * elapsed) / (BPS * YEAR);
        return vault.debtPrincipal + vault.accruedFee + fee;
    }

    function _applyDebtPayment(Vault storage vault, uint256 amount)
        internal
        returns (uint256 feePaid, uint256 principalPaid)
    {
        if (amount == 0) {
            return (0, 0);
        }

        if (vault.accruedFee >= amount) {
            vault.accruedFee -= amount;
            feePaid = amount;
            principalPaid = 0;
        } else {
            feePaid = vault.accruedFee;
            vault.accruedFee = 0;

            principalPaid = amount - feePaid;
            if (principalPaid > vault.debtPrincipal) {
                principalPaid = vault.debtPrincipal;
            }
            vault.debtPrincipal -= principalPaid;
        }

        vault.lastAccruedTimestamp = block.timestamp;
    }

    function _requireHealthy(Vault memory vault) internal view {
        if ((vault.debtPrincipal + vault.accruedFee) == 0) return;
        uint256 ratioBps = _collateralRatioBps(vault);
        if (ratioBps < minCollateralRatioBps) revert InsufficientCollateral();
    }

    function _isLiquidatable(Vault memory vault) internal view returns (bool) {
        if ((vault.debtPrincipal + vault.accruedFee) == 0) return false;
        uint256 ratioBps = _collateralRatioBps(vault);
        return ratioBps < minCollateralRatioBps;
    }

    function _collateralRatioBps(Vault memory vault) internal view returns (uint256) {
        uint256 debt = _debtWithAccruedFee(vault);
        if (debt == 0) {
            return type(uint256).max;
        }
        uint256 priceE18 = oracleHub.getValidatedPrice();
        uint256 collateralValue = (vault.collateralAmount * priceE18) / WAD;
        return (collateralValue * BPS) / debt;
    }

    function _computeRepayForTarget(Vault memory vault) internal view returns (uint256) {
        uint256 priceE18 = oracleHub.getValidatedPrice();
        uint256 collateralValue = (vault.collateralAmount * priceE18) / WAD;

        uint256 debt = vault.debtPrincipal + vault.accruedFee;

        if (targetCollateralRatioBps <= BPS + liquidationBonusBps) {
            return debt;
        }

        uint256 left = targetCollateralRatioBps * debt;
        uint256 right = BPS * collateralValue;
        if (left <= right) {
            return 0;
        }

        uint256 numerator = left - right;
        uint256 denominator = targetCollateralRatioBps - (BPS + liquidationBonusBps);
        uint256 repayAmount = numerator / denominator;
        if (repayAmount > debt) repayAmount = debt;
        return repayAmount;
    }

    function _oracleAdminSetDemoMode(bool enabled) internal {
        oracleHub.setDemoMode(enabled);
    }

    function _oracleAdminSetDemoPrice(uint256 priceE18) internal {
        oracleHub.setDemoPrice(priceE18);
    }

    function _oracleAdminSetConfig(uint256 spotMaxAge, uint256 twapMaxAge, uint256 maxDeviationBps)
        internal
    {
        oracleHub.setConfig(spotMaxAge, twapMaxAge, maxDeviationBps);
    }
}
