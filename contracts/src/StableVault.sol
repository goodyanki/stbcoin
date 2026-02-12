// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Ownable } from "./utils/Ownable.sol";
import { ReentrancyGuard } from "./utils/ReentrancyGuard.sol";
import { ISTBToken } from "./interfaces/ISTBToken.sol";
import { IOracleHub } from "./interfaces/IOracleHub.sol";

contract StableVault is Ownable, ReentrancyGuard {
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
    error EthTransferFailed();

    event Deposited(address indexed owner, uint256 ethAmount);
    event Withdrawn(address indexed owner, uint256 ethAmount);
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

    constructor(address initialOwner, address stbToken, address oracle) Ownable(initialOwner) {
        stb = ISTBToken(stbToken);
        oracleHub = IOracleHub(oracle);
    }

    /// @notice Deposits ETH collateral into caller's vault.
    /// @dev `msg.value` must equal `ethAmount`.
    /// @param ethAmount Amount of ETH collateral to deposit (wei).
    function deposit(uint256 ethAmount) external payable whenNotPaused nonReentrant {
        if (ethAmount == 0 || msg.value != ethAmount) revert InvalidAmount();
        Vault storage vault = vaults[msg.sender];
        _accrue(vault);
        vault.collateralAmount += ethAmount;

        emit Deposited(msg.sender, ethAmount);
    }

    /// @notice Withdraws ETH collateral from caller's vault.
    /// @dev Reverts if oracle breaker is on or vault would become undercollateralized.
    /// @param ethAmount Amount of ETH to withdraw (wei).
    function withdraw(uint256 ethAmount) external whenNotPaused nonReentrant {
        if (!oracleHub.canRiskActionProceed()) revert OracleBreaker();
        if (ethAmount == 0) revert InvalidAmount();
        Vault storage vault = vaults[msg.sender];
        _accrue(vault);
        if (vault.collateralAmount < ethAmount) revert InsufficientCollateral();

        vault.collateralAmount -= ethAmount;
        _requireHealthy(vault);
        vault.lastRiskActionBlock = block.number;

        (bool ok,) = payable(msg.sender).call{ value: ethAmount }("");
        if (!ok) revert EthTransferFailed();

        emit Withdrawn(msg.sender, ethAmount);
    }

    /// @notice Mints STB against caller's collateral.
    /// @dev Reverts if oracle breaker is on or collateral ratio falls below minimum.
    /// @param stbAmount Amount of STB to mint (18 decimals).
    function mint(uint256 stbAmount) external whenNotPaused nonReentrant {
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

    /// @notice Repays caller's STB debt, covering fee first then principal.
    /// @param stbAmount Requested repayment amount (18 decimals).
    function repay(uint256 stbAmount) external whenNotPaused nonReentrant {
        if (stbAmount == 0) revert InvalidAmount();
        Vault storage vault = vaults[msg.sender];
        _accrue(vault);

        uint256 debt = vault.debtPrincipal + vault.accruedFee;
        if (debt == 0) revert InvalidAmount();

        uint256 payAmount = stbAmount > debt ? debt : stbAmount;

        (uint256 feePaid, uint256 principalPaid) = _applyDebtPayment(vault, payAmount);
        protocolReserveStb += feePaid;

        require(stb.transferFrom(msg.sender, address(this), payAmount), "STB_TRANSFER");

        if (principalPaid > 0) {
            stb.burn(address(this), principalPaid);
        }

        emit Repaid(msg.sender, payAmount, feePaid, principalPaid);
    }

    /// @notice Liquidates an unhealthy vault by repaying debt and seizing collateral.
    /// @dev Callable by keeper or vault owner while breaker is off.
    /// @param ownerAddress Vault owner to liquidate.
    /// @param repayAmount Requested STB repay amount by liquidator.
    function liquidate(address ownerAddress, uint256 repayAmount)
        external
        whenNotPaused
        nonReentrant
    {
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

        (uint256 feePaid, uint256 principalPaid) = _applyDebtPayment(vault, finalRepay);
        protocolReserveStb += feePaid;

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

        require(stb.transferFrom(msg.sender, address(this), finalRepay), "STB_TRANSFER");
        if (principalPaid > 0) {
            stb.burn(address(this), principalPaid);
        }

        (bool ok,) = payable(msg.sender).call{ value: seizeCollateral }("");
        if (!ok) revert EthTransferFailed();

        emit Liquidated(ownerAddress, msg.sender, finalRepay, seizeCollateral, badDebtDelta);
    }

    /// @notice Burns protocol reserve STB to reduce recorded system bad debt.
    /// @dev Callable only by owner. Actual covered amount is capped by reserve and bad debt.
    /// @param amount Requested bad debt cover amount (18 decimals).
    function coverBadDebt(uint256 amount) external onlyOwner nonReentrant {
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

    /// @notice Updates core liquidation and collateral ratio parameters.
    /// @dev Callable only by owner. Inputs are validated for safe bounds.
    /// @param newMinCollateralRatioBps Minimum collateral ratio in bps.
    /// @param newTargetCollateralRatioBps Target ratio after liquidation in bps.
    /// @param newLiquidationBonusBps Liquidator bonus in bps.
    /// @param newMaxCloseFactorBps Max repay share per liquidation in bps.
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

    /// @notice Sets annualized stability fee rate.
    /// @dev Callable only by owner.
    /// @param newStabilityFeeBps Stability fee in bps per year.
    function setStabilityFeeBps(uint256 newStabilityFeeBps) external onlyOwner {
        if (newStabilityFeeBps > 2_000) revert InvalidParams();
        stabilityFeeBps = newStabilityFeeBps;
        emit StabilityFeeUpdated(newStabilityFeeBps);
    }

    /// @notice Pauses or unpauses user mutation actions.
    /// @dev Callable only by owner.
    /// @param isPaused True to pause, false to unpause.
    function setPause(bool isPaused) external onlyOwner {
        paused = isPaused;
        emit PauseSet(isPaused);
    }

    /// @notice Grants or revokes keeper permission.
    /// @dev Callable only by owner.
    /// @param keeperAddress Keeper address to update.
    /// @param allowed True to grant keeper role, false to revoke.
    function setKeeper(address keeperAddress, bool allowed) external onlyOwner {
        isKeeper[keeperAddress] = allowed;
        emit KeeperSet(keeperAddress, allowed);
    }

    /// @notice Enables or disables oracle demo mode via OracleHub.
    /// @dev Callable only by owner.
    /// @param enabled True to enable demo mode.
    function setDemoMode(bool enabled) external onlyOwner {
        _oracleAdminSetDemoMode(enabled);
        emit DemoModeSet(enabled);
    }

    /// @notice Sets manual demo ETH price via OracleHub.
    /// @dev Callable only by owner. Price must be within basic sanity bounds.
    /// @param priceE18 ETH/USD price in 1e18 precision.
    function setDemoPrice(uint256 priceE18) external onlyOwner {
        if (priceE18 > 1e24) revert InvalidParams();
        _oracleAdminSetDemoPrice(priceE18);
        emit DemoPriceSet(priceE18);
    }

    /// @notice Updates OracleHub breaker config.
    /// @dev Callable only by owner.
    /// @param spotMaxAge Maximum accepted spot age in seconds.
    /// @param twapMaxAge Maximum accepted TWAP age in seconds.
    /// @param maxDeviationBps Maximum spot/TWAP deviation in bps.
    function setOracleConfig(uint256 spotMaxAge, uint256 twapMaxAge, uint256 maxDeviationBps)
        external
        onlyOwner
    {
        _oracleAdminSetConfig(spotMaxAge, twapMaxAge, maxDeviationBps);
        emit OracleConfigSet(spotMaxAge, twapMaxAge, maxDeviationBps);
    }

    /// @notice Returns full vault snapshot for a user.
    /// @param ownerAddress Vault owner address.
    /// @return collateralAmount ETH collateral in wei.
    /// @return debtPrincipal Outstanding principal debt.
    /// @return accruedFee Accrued stability fee amount.
    /// @return debtWithFee Principal plus pending fee accrual.
    /// @return lastAccruedTimestamp Last fee accrual timestamp.
    /// @return lastRiskActionBlock Last block where risk action occurred.
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

    /// @notice Returns current collateral ratio for a vault.
    /// @param ownerAddress Vault owner address.
    /// @return Collateral ratio in bps.
    function getCollateralRatioBps(address ownerAddress) external view returns (uint256) {
        return _collateralRatioBps(vaults[ownerAddress]);
    }

    /// @notice Returns whether a vault is currently liquidatable.
    /// @param ownerAddress Vault owner address.
    /// @return True if vault is below minimum collateral ratio.
    function isLiquidatable(address ownerAddress) external view returns (bool) {
        return _isLiquidatable(vaults[ownerAddress]);
    }

    /// @notice Returns total recorded protocol bad debt.
    /// @return Total bad debt amount in STB units (18 decimals).
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

    receive() external payable { }
}
