'forge clean' running (wd: /home/nick/stbcoin/contracts)
'forge config --json' running
'forge build --build-info --skip ./test/** ./script/** --force' running (wd: /home/nick/stbcoin/contracts)
INFO:Detectors:
Detector: divide-before-multiply
StableVault._collateralRatioBps(StableVault.Vault) (src/StableVault.sol#394-402) performs a multiplication on the result of a division:
	- collateralValue = (vault.collateralAmount * priceE18) / WAD (src/StableVault.sol#400)
	- (collateralValue * BPS) / debt (src/StableVault.sol#401)
StableVault._computeRepayForTarget(StableVault.Vault) (src/StableVault.sol#404-425) performs a multiplication on the result of a division:
	- collateralValue = (vault.collateralAmount * priceE18) / WAD (src/StableVault.sol#406)
	- right = BPS * collateralValue (src/StableVault.sol#415)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#divide-before-multiply
INFO:Detectors:
Detector: incorrect-equality
StableVault._collateralRatioBps(StableVault.Vault) (src/StableVault.sol#394-402) uses a dangerous strict equality:
	- debt == 0 (src/StableVault.sol#396)
StableVault._debtWithAccruedFee(StableVault.Vault) (src/StableVault.sol#342-354) uses a dangerous strict equality:
	- (vault.debtPrincipal + vault.accruedFee) == 0 || vault.lastAccruedTimestamp == 0 (src/StableVault.sol#343)
StableVault._isLiquidatable(StableVault.Vault) (src/StableVault.sol#388-392) uses a dangerous strict equality:
	- (vault.debtPrincipal + vault.accruedFee) == 0 (src/StableVault.sol#389)
StableVault.coverBadDebt(uint256) (src/StableVault.sol#211-225) uses a dangerous strict equality:
	- amount == 0 (src/StableVault.sol#218)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#dangerous-strict-equalities
INFO:Detectors:
Detector: uninitialized-local
StableVault.liquidate(address,uint256).badDebtDelta (src/StableVault.sol#185) is a local variable never initialized
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#uninitialized-local-variables
INFO:Detectors:
Detector: unused-return
OracleHub._readChainlinkE18() (src/OracleHub.sol#100-116) ignores return value by (None,answer,None,timestamp,None) = chainlinkEthUsd.latestRoundData() (src/OracleHub.sol#101)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#unused-return
INFO:Detectors:
Detector: reentrancy-events
Reentrancy in StableVault.setDemoMode(bool) (src/StableVault.sol#268-271):
	External calls:
	- _oracleAdminSetDemoMode(enabled) (src/StableVault.sol#269)
		- oracleHub.setDemoMode(enabled) (src/StableVault.sol#428)
	Event emitted after the call(s):
	- DemoModeSet(enabled) (src/StableVault.sol#270)
Reentrancy in StableVault.setDemoPrice(uint256) (src/StableVault.sol#273-277):
	External calls:
	- _oracleAdminSetDemoPrice(priceE18) (src/StableVault.sol#275)
		- oracleHub.setDemoPrice(priceE18) (src/StableVault.sol#432)
	Event emitted after the call(s):
	- DemoPriceSet(priceE18) (src/StableVault.sol#276)
Reentrancy in StableVault.setOracleConfig(uint256,uint256,uint256) (src/StableVault.sol#279-285):
	External calls:
	- _oracleAdminSetConfig(spotMaxAge,twapMaxAge,maxDeviationBps) (src/StableVault.sol#283)
		- oracleHub.setConfig(spotMaxAge,twapMaxAge,maxDeviationBps) (src/StableVault.sol#438)
	Event emitted after the call(s):
	- OracleConfigSet(spotMaxAge,twapMaxAge,maxDeviationBps) (src/StableVault.sol#284)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-4
INFO:Detectors:
Detector: timestamp
OracleHub.getPriceStatus() (src/OracleHub.sol#64-98) uses timestamp for comparisons
	Dangerous comparisons:
	- spotStale = spotUpdatedAt > block.timestamp || (block.timestamp - spotUpdatedAt > spotMaxAge) (src/OracleHub.sol#84-85)
	- twapStale = twapUpdatedAt > block.timestamp || (block.timestamp - twapUpdatedAt > twapMaxAge) (src/OracleHub.sol#86-87)
	- spotStale || twapStale || twapPrice == 0 (src/OracleHub.sol#89)
StableVault._accrue(StableVault.Vault) (src/StableVault.sol#322-340) uses timestamp for comparisons
	Dangerous comparisons:
	- (vault.debtPrincipal + vault.accruedFee) == 0 || block.timestamp <= vault.lastAccruedTimestamp (src/StableVault.sol#329-330)
StableVault._debtWithAccruedFee(StableVault.Vault) (src/StableVault.sol#342-354) uses timestamp for comparisons
	Dangerous comparisons:
	- block.timestamp <= vault.lastAccruedTimestamp (src/StableVault.sol#347)
StableVault._requireHealthy(StableVault.Vault) (src/StableVault.sol#382-386) uses timestamp for comparisons
	Dangerous comparisons:
	- ratioBps < minCollateralRatioBps (src/StableVault.sol#385)
StableVault._isLiquidatable(StableVault.Vault) (src/StableVault.sol#388-392) uses timestamp for comparisons
	Dangerous comparisons:
	- ratioBps < minCollateralRatioBps (src/StableVault.sol#391)
StableVault._collateralRatioBps(StableVault.Vault) (src/StableVault.sol#394-402) uses timestamp for comparisons
	Dangerous comparisons:
	- debt == 0 (src/StableVault.sol#396)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#block-timestamp
INFO:Detectors:
Detector: cyclomatic-complexity
StableVault.liquidate(address,uint256) (src/StableVault.sol#146-209) has a high cyclomatic complexity (16).
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#cyclomatic-complexity
INFO:Detectors:
Detector: low-level-calls
Low level call in StableVault.withdraw(uint256) (src/StableVault.sol#92-107):
	- (ok,None) = address(msg.sender).call{value: ethAmount}() (src/StableVault.sol#103)
Low level call in StableVault.liquidate(address,uint256) (src/StableVault.sol#146-209):
	- (ok,None) = address(msg.sender).call{value: seizeCollateral}() (src/StableVault.sol#205)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#low-level-calls
INFO:Detectors:
Detector: missing-inheritance
OracleHub (src/OracleHub.sol#8-117) should inherit from IOracleHub (src/interfaces/IOracleHub.sol#4-27)
STBToken (src/STBToken.sol#7-86) should inherit from ISTBToken (src/interfaces/ISTBToken.sol#6-10)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#missing-inheritance
INFO:Slither:. analyzed (12 contracts with 101 detectors), 22 result(s) found
