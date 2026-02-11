# Smart Contract API Documentation

This document describes the public/external API of the StableVault contracts in `contracts/src`.

## 1. Ownable (`contracts/src/utils/Ownable.sol`)

### Public State
- `owner() -> address`

### External Functions
- `transferOwnership(address newOwner)`
  - Access: `onlyOwner`
  - Purpose: transfer contract ownership to `newOwner`

### Events
- `OwnershipTransferred(address previousOwner, address newOwner)`

### Errors
- `OwnableUnauthorizedAccount(address account)`
- `OwnableInvalidOwner(address owner)`

## 2. ReentrancyGuard (`contracts/src/utils/ReentrancyGuard.sol`)

Utility guard used by `StableVault`.

### Errors
- `ReentrancyGuardReentrantCall()`

## 3. STBToken (`contracts/src/STBToken.sol`)

ERC20-compatible token used by StableVault.

### Public State
- `name() -> string`
- `symbol() -> string`
- `decimals() -> uint8`
- `totalSupply() -> uint256`
- `vault() -> address`
- `balanceOf(address) -> uint256`
- `allowance(address owner, address spender) -> uint256`
- `owner() -> address` (from `Ownable`)

### External Functions
- `setVault(address vaultAddress)`
  - Access: `onlyOwner`
  - Purpose: set authorized vault contract for mint/burn
- `transfer(address to, uint256 amount) -> bool`
- `approve(address spender, uint256 amount) -> bool`
- `transferFrom(address from, address to, uint256 amount) -> bool`
- `mint(address to, uint256 amount)`
  - Access: `onlyVault`
- `burn(address from, uint256 amount)`
  - Access: `onlyVault`
- `transferOwnership(address newOwner)` (inherited)

### Events
- `Transfer(address from, address to, uint256 amount)`
- `Approval(address owner, address spender, uint256 amount)`
- `VaultSet(address vaultAddress)`
- `OwnershipTransferred(address previousOwner, address newOwner)`

### Errors
- `NotVault(address caller)`
- `ZeroAddress()`
- Ownable errors

## 4. TwapOracle (`contracts/src/TwapOracle.sol`)

Stores a published TWAP ETH/USD price.

### Public State
- `twapPriceE18() -> uint256`
- `updatedAt() -> uint256`
- `isPublisher(address) -> bool`
- `owner() -> address` (from `Ownable`)

### External Functions
- `setPublisher(address publisher, bool allowed)`
  - Access: `onlyOwner`
- `updateTwap(uint256 priceE18)`
  - Access: owner or approved publisher
  - Purpose: update TWAP price
- `getTwap() -> (uint256 priceE18, uint256 timestamp)`
- `transferOwnership(address newOwner)` (inherited)

### Events
- `PublisherSet(address publisher, bool allowed)`
- `TwapUpdated(uint256 priceE18, uint256 updatedAt)`
- `OwnershipTransferred(address previousOwner, address newOwner)`

### Errors
- `NotPublisher(address caller)`
- `InvalidPrice()`
- Ownable errors

## 5. OracleHub (`contracts/src/OracleHub.sol`)

Price validation hub that combines Chainlink spot price and TWAP.

### Public State
- `chainlinkEthUsd() -> address`
- `twapOracle() -> address`
- `spotMaxAge() -> uint256`
- `twapMaxAge() -> uint256`
- `maxDeviationBps() -> uint256`
- `demoMode() -> bool`
- `demoPriceE18() -> uint256`
- `owner() -> address` (from `Ownable`)

### External/Public Functions
- `setConfig(uint256 newSpotMaxAge, uint256 newTwapMaxAge, uint256 newMaxDeviationBps)`
  - Access: `onlyOwner`
- `setDemoMode(bool enabled)`
  - Access: `onlyOwner`
- `setDemoPrice(uint256 priceE18)`
  - Access: `onlyOwner`
  - Requires demo mode enabled
- `getValidatedPrice() -> uint256`
  - Reverts if breaker triggered
- `canRiskActionProceed() -> bool`
- `getPriceStatus() -> (uint256 effectivePrice, uint256 spotPrice, uint256 twapPrice, uint256 spotUpdatedAt, uint256 twapUpdatedAt, bool breakerTriggered)`
- `transferOwnership(address newOwner)` (inherited)

### Events
- `OracleConfigUpdated(uint256 spotMaxAge, uint256 twapMaxAge, uint256 maxDeviationBps)`
- `DemoModeSet(bool enabled)`
- `DemoPriceSet(uint256 demoPriceE18)`
- `OwnershipTransferred(address previousOwner, address newOwner)`

### Errors
- `InvalidPrice()`
- Ownable errors

## 6. StableVault (`contracts/src/StableVault.sol`)

Core protocol contract for collateralized debt positions.

### Public State
- `stb() -> address`
- `oracleHub() -> address`
- `isKeeper(address) -> bool`
- `minCollateralRatioBps() -> uint256`
- `targetCollateralRatioBps() -> uint256`
- `liquidationBonusBps() -> uint256`
- `maxCloseFactorBps() -> uint256`
- `stabilityFeeBps() -> uint256`
- `protocolReserveStb() -> uint256`
- `systemBadDebt() -> uint256`
- `paused() -> bool`
- `owner() -> address` (from `Ownable`)

### External Functions (mutating)
- `deposit(uint256 ethAmount)` payable
  - Access: when not paused
  - Purpose: deposit ETH collateral
- `withdraw(uint256 ethAmount)`
  - Access: when not paused
  - Requires healthy CR after withdrawal
- `mint(uint256 stbAmount)`
  - Access: when not paused
  - Requires healthy CR after mint
- `repay(uint256 stbAmount)`
  - Access: when not paused
  - Repays fee first, then principal
- `liquidate(address ownerAddress, uint256 repayAmount)`
  - Access: when not paused, keeper or owner
  - Liquidates unhealthy vaults
- `coverBadDebt(uint256 amount)`
  - Access: `onlyOwner`
  - Burns reserve STB and reduces `systemBadDebt`
- `setRiskParams(uint256 newMinCollateralRatioBps, uint256 newTargetCollateralRatioBps, uint256 newLiquidationBonusBps, uint256 newMaxCloseFactorBps)`
  - Access: `onlyOwner`
- `setStabilityFeeBps(uint256 newStabilityFeeBps)`
  - Access: `onlyOwner`
- `setPause(bool isPaused)`
  - Access: `onlyOwner`
- `setKeeper(address keeperAddress, bool allowed)`
  - Access: `onlyOwner`
- `setDemoMode(bool enabled)`
  - Access: `onlyOwner`
  - Forwards to `OracleHub`
- `setDemoPrice(uint256 priceE18)`
  - Access: `onlyOwner`
  - Forwards to `OracleHub`
- `setOracleConfig(uint256 spotMaxAge, uint256 twapMaxAge, uint256 maxDeviationBps)`
  - Access: `onlyOwner`
  - Forwards to `OracleHub`
- `transferOwnership(address newOwner)` (inherited)

### External Functions (view)
- `getVault(address ownerAddress) -> (uint256 collateralAmount, uint256 debtPrincipal, uint256 accruedFee, uint256 debtWithFee, uint256 lastAccruedTimestamp, uint256 lastRiskActionBlock)`
- `getCollateralRatioBps(address ownerAddress) -> uint256`
- `isLiquidatable(address ownerAddress) -> bool`
- `getSystemBadDebt() -> uint256`

### Receive
- `receive() external payable`

### Events
- `Deposited(address owner, uint256 ethAmount)`
- `Withdrawn(address owner, uint256 ethAmount)`
- `Minted(address owner, uint256 stbAmount)`
- `Repaid(address owner, uint256 stbAmount, uint256 feePaid, uint256 principalPaid)`
- `Liquidated(address owner, address liquidator, uint256 repayAmount, uint256 seizedCollateral, uint256 badDebtDelta)`
- `RiskParamsUpdated(uint256 minCollateralRatioBps, uint256 targetCollateralRatioBps, uint256 liquidationBonusBps, uint256 maxCloseFactorBps)`
- `StabilityFeeUpdated(uint256 stabilityFeeBps)`
- `PauseSet(bool paused)`
- `KeeperSet(address keeper, bool allowed)`
- `BadDebtCovered(uint256 amount)`
- `DemoModeSet(bool enabled)`
- `DemoPriceSet(uint256 priceE18)`
- `OracleConfigSet(uint256 spotMaxAge, uint256 twapMaxAge, uint256 maxDeviationBps)`
- `OwnershipTransferred(address previousOwner, address newOwner)`

### Errors
- `Paused()`
- `InvalidAmount()`
- `NotKeeper(address caller)`
- `OracleBreaker()`
- `InsufficientCollateral()`
- `HealthyVault()`
- `SameBlockRiskAction()`
- `InvalidParams()`
- `EthTransferFailed()`
- reentrancy guard error
- Ownable errors

## ABI/Interface References
- `contracts/src/interfaces/IOracleHub.sol`
- `contracts/src/interfaces/ISTBToken.sol`
- `contracts/src/interfaces/IStableVaultEvents.sol`
