export const STABLE_VAULT_ABI = [
  "event Deposited(address indexed owner, uint256 wethAmount)",
  "event Withdrawn(address indexed owner, uint256 wethAmount)",
  "event Minted(address indexed owner, uint256 stbAmount)",
  "event Repaid(address indexed owner, uint256 stbAmount, uint256 feePaid, uint256 principalPaid)",
  "function getVault(address owner) view returns (uint256 collateralAmount, uint256 debtPrincipal, uint256 accruedFee, uint256 debtWithFee, uint256 lastAccruedTimestamp, uint256 lastRiskActionBlock)",
  "function getCollateralRatioBps(address owner) view returns (uint256)",
  "function isLiquidatable(address owner) view returns (bool)",
  "function getSystemBadDebt() view returns (uint256)",
  "function protocolReserveStb() view returns (uint256)",
  "function liquidate(address owner, uint256 repayAmount)",
  "event Liquidated(address indexed owner, address indexed liquidator, uint256 repayAmount, uint256 seizedCollateral, uint256 badDebtDelta)",
  "function deposit(uint256 ethAmount) payable",
  "function mint(uint256 stbAmount)"
];

export const ORACLE_HUB_ABI = [
  "function getPriceStatus() view returns (uint256 effectivePrice, uint256 spotPrice, uint256 twapPrice, uint256 spotUpdatedAt, uint256 twapUpdatedAt, bool breakerTriggered)",
  "function canRiskActionProceed() view returns (bool)"
];

export const TWAP_ORACLE_ABI = [
  "function updateTwap(uint256 priceE18)",
  "function getTwap() view returns (uint256 priceE18, uint256 timestamp)"
];
