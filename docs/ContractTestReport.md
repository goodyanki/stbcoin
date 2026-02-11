1.test report
run $ forge test

**Result:**
[⠊] Compiling...
No files changed, compilation skipped

Ran 8 tests for test/unit/OracleHub.unit.t.sol:OracleHubUnitTest
[PASS] testConfigAndDemoMode() (gas: 78197)
[PASS] testDemoPriceRevertsWithoutDemoModeOrZero() (gas: 40301)
[PASS] testDeviationTriggersBreaker() (gas: 42339)
[PASS] testGetPriceStatusNormal() (gas: 31390)
[PASS] testGetValidatedPriceRevertsOnBreaker() (gas: 39630)
[PASS] testOnlyOwnerMethodsRevertForStranger() (gas: 20204)
[PASS] testStalePriceTriggersBreaker() (gas: 37670)
[PASS] testTransferOwnership() (gas: 38311)
Suite result: ok. 8 passed; 0 failed; 0 skipped; finished in 516.40µs (448.19µs CPU time)

Ran 6 tests for test/unit/StableVault.admin.unit.t.sol:StableVaultAdminUnitTest
[PASS] testKeeperAndOracleAdminPassThrough() (gas: 118068)
[PASS] testPauseBlocksMutations() (gas: 44935)
[PASS] testSetRiskParamsAndStabilityFee() (gas: 41186)
[PASS] testSetRiskParamsRevertsOnInvalidInputs() (gas: 24918)
[PASS] testTransferOwnership() (gas: 45170)
[PASS] testViewHelpersAndReceiveEther() (gas: 34173)
Suite result: ok. 6 passed; 0 failed; 0 skipped; finished in 656.90µs (299.00µs CPU time)

Ran 4 tests for test/unit/TwapOracle.unit.t.sol:TwapOracleUnitTest
[PASS] testSetPublisherOnlyOwner() (gas: 43260)
[PASS] testTransferOwnership() (gas: 48131)
[PASS] testUpdateTwapByOwnerOrPublisher() (gas: 90323)
[PASS] testUpdateTwapRevertsForNonPublisherAndZeroPrice() (gas: 21287)
Suite result: ok. 4 passed; 0 failed; 0 skipped; finished in 457.74µs (130.71µs CPU time)

Ran 2 tests for test/integration/StableVault.integration.t.sol:StableVaultIntegrationTest
[PASS] testEndToEndDepositMintRepayWithdraw() (gas: 274284)
[PASS] testEndToEndLiquidationCreatesBadDebtWhenCollateralExhausted() (gas: 398814)
Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 1.20ms (543.10µs CPU time)

Ran 4 tests for test/gas/StableVault.gas.t.sol:StableVaultGasTest
[PASS] testGasDeposit() (gas: 65734)
[PASS] testGasLiquidate() (gas: 359333)
[PASS] testGasMint() (gas: 204039)
[PASS] testGasRepay() (gas: 248319)
Suite result: ok. 4 passed; 0 failed; 0 skipped; finished in 1.37ms (461.00µs CPU time)

Ran 7 tests for test/unit/STBToken.unit.t.sol:STBTokenUnitTest
[PASS] testFuzzTransferConservesSupply(uint96) (runs: 256, μ: 97746, ~: 97640)
[PASS] testMintAndBurnOnlyVault() (gas: 98228)
[PASS] testSetVaultOnlyOwner() (gas: 42912)
[PASS] testSetVaultRevertZeroAddress() (gas: 10708)
[PASS] testTransferApproveTransferFrom() (gas: 154593)
[PASS] testTransferFromWithInfiniteAllowance() (gas: 141711)
[PASS] testTransferOwnership() (gas: 50199)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 6.95ms (6.97ms CPU time)

Ran 2 tests for test/fuzz/StableVault.fuzz.t.sol:StableVaultFuzzTest
[PASS] testFuzzMintRespectsMinCR(uint96,uint96) (runs: 256, μ: 215078, ~: 215357)
[PASS] testFuzzRepayNeverIncreasesDebt(uint96,uint96) (runs: 257, μ: 301028, ~: 301035)
Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 24.90ms (42.82ms CPU time)

Ran 11 tests for test/unit/StableVault.unit.t.sol:StableVaultUnitTest
[PASS] testAdminDemoPriceMode() (gas: 72567)
[PASS] testBadDebtCoverBurnsReserveTokens() (gas: 398477)
[PASS] testCircuitBreakerAllowsDepositAndRepay() (gas: 286318)
[PASS] testDepositAndMintFlow() (gas: 209693)
[PASS] testLiquidationFlowAfterRiskAction() (gas: 404222)
[PASS] testMintRevertsWhenBreakerTriggered() (gas: 104417)
[PASS] testPartialLiquidationByKeeper() (gas: 371252)
[PASS] testRepayAccruedFeeAndPrincipal() (gas: 314749)
[PASS] testSameBlockLiquidationRevertsThenSucceedsNextBlock() (gas: 382925)
[PASS] testUnderwaterPositionDoesNotCreateBadDebtInPartialLiquidation() (gas: 390075)
[PASS] testWithdrawRevertsWhenCRTooLow() (gas: 218214)
Suite result: ok. 11 passed; 0 failed; 0 skipped; finished in 2.27s (2.07ms CPU time)

Ran 2 tests for test/invariant/StableVault.invariant.t.sol:StableVaultInvariantTest
[PASS] invariantLiquidatableFlagConsistent() (runs: 256, calls: 128000, reverts: 124221)

╭-------------+--------------------+-------+---------+----------╮
| Contract    | Selector           | Calls | Reverts | Discards |
+===============================================================+
| StableVault | coverBadDebt       | 10712 | 10712   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | deposit            | 10517 | 10517   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | liquidate          | 10563 | 10563   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | mint               | 10577 | 8616    | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | repay              | 10815 | 10815   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | setKeeper          | 10582 | 10582   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | setOracleConfig    | 10765 | 10765   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | setPause           | 10713 | 10713   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | setRiskParams      | 10930 | 10930   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | setStabilityFeeBps | 10636 | 10636   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | transferOwnership  | 10737 | 10737   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | withdraw           | 10453 | 8635    | 0        |
╰-------------+--------------------+-------+---------+----------╯

[PASS] invariantSupplyCoversDebtOrBadDebt() (runs: 256, calls: 128000, reverts: 123811)

╭-------------+--------------------+-------+---------+----------╮
| Contract    | Selector           | Calls | Reverts | Discards |
+===============================================================+
| StableVault | coverBadDebt       | 10556 | 10556   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | deposit            | 10526 | 10526   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | liquidate          | 10618 | 10618   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | mint               | 10770 | 8600    | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | repay              | 10774 | 10774   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | setKeeper          | 10753 | 10753   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | setOracleConfig    | 10651 | 10651   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | setPause           | 10673 | 10673   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | setRiskParams      | 10596 | 10596   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | setStabilityFeeBps | 10636 | 10636   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | transferOwnership  | 10817 | 10817   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | withdraw           | 10630 | 8611    | 0        |
╰-------------+--------------------+-------+---------+----------╯

Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 2.27s (4.53s CPU time)

Ran 9 test suites in 2.27s (4.58s CPU time): 46 tests passed, 0 failed, 0 skipped (46 total tests)


2. Coverage
$ forge coverage
Warning: optimizer settings and `viaIR` have been disabled for accurate coverage reports.
If you encounter "stack too deep" errors, consider using `--ir-minimum` which enables `viaIR` with minimum optimization resolving most of the errors
[⠊] Compiling...
[⠊] Compiling 43 files with Solc 0.8.24
[⠒] Solc 0.8.24 finished in 900.58ms
Compiler run successful!
Analysing contracts...
Running tests...

Ran 4 tests for test/unit/TwapOracle.unit.t.sol:TwapOracleUnitTest
[PASS] testSetPublisherOnlyOwner() (gas: 45598)
[PASS] testTransferOwnership() (gas: 51317)
[PASS] testUpdateTwapByOwnerOrPublisher() (gas: 93987)
[PASS] testUpdateTwapRevertsForNonPublisherAndZeroPrice() (gas: 23161)
Suite result: ok. 4 passed; 0 failed; 0 skipped; finished in 1.23ms (1.14ms CPU time)

Ran 6 tests for test/unit/StableVault.admin.unit.t.sol:StableVaultAdminUnitTest
[PASS] testKeeperAndOracleAdminPassThrough() (gas: 126365)
[PASS] testPauseBlocksMutations() (gas: 46329)
[PASS] testSetRiskParamsAndStabilityFee() (gas: 45149)
[PASS] testSetRiskParamsRevertsOnInvalidInputs() (gas: 31860)
[PASS] testTransferOwnership() (gas: 47322)
[PASS] testViewHelpersAndReceiveEther() (gas: 36465)
Suite result: ok. 6 passed; 0 failed; 0 skipped; finished in 5.20ms (7.21ms CPU time)

Ran 2 tests for test/integration/StableVault.integration.t.sol:StableVaultIntegrationTest
[PASS] testEndToEndDepositMintRepayWithdraw() (gas: 300493)
[PASS] testEndToEndLiquidationCreatesBadDebtWhenCollateralExhausted() (gas: 439444)
Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 7.44ms (4.23ms CPU time)

Ran 4 tests for test/gas/StableVault.gas.t.sol:StableVaultGasTest
[PASS] testGasDeposit() (gas: 66729)
[PASS] testGasLiquidate() (gas: 394968)
[PASS] testGasMint() (gas: 214370)
[PASS] testGasRepay() (gas: 263348)
Suite result: ok. 4 passed; 0 failed; 0 skipped; finished in 8.78ms (8.10ms CPU time)

Ran 11 tests for test/unit/StableVault.unit.t.sol:StableVaultUnitTest
[PASS] testAdminDemoPriceMode() (gas: 76479)
[PASS] testBadDebtCoverBurnsReserveTokens() (gas: 442920)
[PASS] testCircuitBreakerAllowsDepositAndRepay() (gas: 312151)
[PASS] testDepositAndMintFlow() (gas: 222571)
[PASS] testLiquidationFlowAfterRiskAction() (gas: 449597)
[PASS] testMintRevertsWhenBreakerTriggered() (gas: 109887)
[PASS] testPartialLiquidationByKeeper() (gas: 410070)
[PASS] testRepayAccruedFeeAndPrincipal() (gas: 342279)
[PASS] testSameBlockLiquidationRevertsThenSucceedsNextBlock() (gas: 428250)
[PASS] testUnderwaterPositionDoesNotCreateBadDebtInPartialLiquidation() (gas: 436473)
[PASS] testWithdrawRevertsWhenCRTooLow() (gas: 236666)
Suite result: ok. 11 passed; 0 failed; 0 skipped; finished in 8.75ms (28.32ms CPU time)

Ran 2 tests for test/fuzz/StableVault.fuzz.t.sol:StableVaultFuzzTest
[PASS] testFuzzMintRespectsMinCR(uint96,uint96) (runs: 256, μ: 232834, ~: 233405)
[PASS] testFuzzRepayNeverIncreasesDebt(uint96,uint96) (runs: 257, μ: 324739, ~: 324165)
Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 92.48ms (165.79ms CPU time)

Ran 8 tests for test/unit/OracleHub.unit.t.sol:OracleHubUnitTest
[PASS] testConfigAndDemoMode() (gas: 83737)
[PASS] testDemoPriceRevertsWithoutDemoModeOrZero() (gas: 42031)
[PASS] testDeviationTriggersBreaker() (gas: 50513)
[PASS] testGetPriceStatusNormal() (gas: 35780)
[PASS] testGetValidatedPriceRevertsOnBreaker() (gas: 43437)
[PASS] testOnlyOwnerMethodsRevertForStranger() (gas: 22705)
[PASS] testStalePriceTriggersBreaker() (gas: 42752)
[PASS] testTransferOwnership() (gas: 42459)
Suite result: ok. 8 passed; 0 failed; 0 skipped; finished in 92.85ms (7.93ms CPU time)

Ran 7 tests for test/unit/STBToken.unit.t.sol:STBTokenUnitTest
[PASS] testFuzzTransferConservesSupply(uint96) (runs: 256, μ: 102440, ~: 102212)
[PASS] testMintAndBurnOnlyVault() (gas: 104182)
[PASS] testSetVaultOnlyOwner() (gas: 44325)
[PASS] testSetVaultRevertZeroAddress() (gas: 11188)
[PASS] testTransferApproveTransferFrom() (gas: 165701)
[PASS] testTransferFromWithInfiniteAllowance() (gas: 147164)
[PASS] testTransferOwnership() (gas: 52670)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 115.48ms (118.21ms CPU time)

Ran 2 tests for test/invariant/StableVault.invariant.t.sol:StableVaultInvariantTest
[PASS] invariantLiquidatableFlagConsistent() (runs: 256, calls: 128000, reverts: 124065)

╭-------------+--------------------+-------+---------+----------╮
| Contract    | Selector           | Calls | Reverts | Discards |
+===============================================================+
| StableVault | coverBadDebt       | 10677 | 10677   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | deposit            | 10740 | 10740   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | liquidate          | 10655 | 10655   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | mint               | 10512 | 8486    | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | repay              | 10572 | 10572   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | setKeeper          | 10699 | 10699   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | setOracleConfig    | 10653 | 10653   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | setPause           | 10733 | 10733   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | setRiskParams      | 10659 | 10659   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | setStabilityFeeBps | 10826 | 10826   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | transferOwnership  | 10737 | 10737   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | withdraw           | 10537 | 8628    | 0        |
╰-------------+--------------------+-------+---------+----------╯

[PASS] invariantSupplyCoversDebtOrBadDebt() (runs: 256, calls: 128000, reverts: 124065)

╭-------------+--------------------+-------+---------+----------╮
| Contract    | Selector           | Calls | Reverts | Discards |
+===============================================================+
| StableVault | coverBadDebt       | 10677 | 10677   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | deposit            | 10740 | 10740   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | liquidate          | 10655 | 10655   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | mint               | 10512 | 8486    | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | repay              | 10572 | 10572   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | setKeeper          | 10699 | 10699   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | setOracleConfig    | 10653 | 10653   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | setPause           | 10733 | 10733   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | setRiskParams      | 10659 | 10659   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | setStabilityFeeBps | 10826 | 10826   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | transferOwnership  | 10737 | 10737   | 0        |
|-------------+--------------------+-------+---------+----------|
| StableVault | withdraw           | 10537 | 8628    | 0        |
╰-------------+--------------------+-------+---------+----------╯

Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 5.07s (10.01s CPU time)

Ran 9 test suites in 5.07s (5.40s CPU time): 46 tests passed, 0 failed, 0 skipped (46 total tests)

╭---------------------------------+------------------+------------------+----------------+-----------------╮
| File                            | % Lines          | % Statements     | % Branches     | % Funcs         |
+==========================================================================================================+
| script/DeploySepolia.s.sol      | 0.00% (0/24)     | 0.00% (0/33)     | 0.00% (0/3)    | 0.00% (0/1)     |
|---------------------------------+------------------+------------------+----------------+-----------------|
| src/OracleHub.sol               | 95.92% (47/49)   | 94.64% (53/56)   | 60.00% (6/10)  | 100.00% (8/8)   |
|---------------------------------+------------------+------------------+----------------+-----------------|
| src/STBToken.sol                | 100.00% (39/39)  | 94.29% (33/35)   | 63.64% (7/11)  | 100.00% (8/8)   |
|---------------------------------+------------------+------------------+----------------+-----------------|
| src/StableVault.sol             | 97.61% (204/209) | 93.16% (245/263) | 62.26% (33/53) | 100.00% (29/29) |
|---------------------------------+------------------+------------------+----------------+-----------------|
| src/TwapOracle.sol              | 100.00% (12/12)  | 100.00% (12/12)  | 100.00% (2/2)  | 100.00% (4/4)   |
|---------------------------------+------------------+------------------+----------------+-----------------|
| src/utils/Ownable.sol           | 100.00% (11/11)  | 81.82% (9/11)    | 33.33% (1/3)   | 100.00% (3/3)   |
|---------------------------------+------------------+------------------+----------------+-----------------|
| test/mocks/MockAggregatorV3.sol | 100.00% (12/12)  | 100.00% (8/8)    | 100.00% (0/0)  | 100.00% (4/4)   |
|---------------------------------+------------------+------------------+----------------+-----------------|
| test/mocks/MockERC20.sol        | 0.00% (0/30)     | 0.00% (0/24)     | 0.00% (0/7)    | 0.00% (0/6)     |
|---------------------------------+------------------+------------------+----------------+-----------------|
| Total                           | 84.20% (325/386) | 81.45% (360/442) | 55.06% (49/89) | 88.89% (56/63)  |
╰---------------------------------+------------------+------------------+----------------+-----------------╯