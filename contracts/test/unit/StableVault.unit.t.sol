// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import { MockAggregatorV3 } from "../mocks/MockAggregatorV3.sol";
import { STBToken } from "../../src/STBToken.sol";
import { TwapOracle } from "../../src/TwapOracle.sol";
import { OracleHub } from "../../src/OracleHub.sol";
import { StableVault } from "../../src/StableVault.sol";

contract StableVaultUnitTest is Test {
    address internal owner = address(this);
    address internal alice = address(0xBEEF);
    address internal keeper = address(0xCAFE);

    MockAggregatorV3 internal feed;
    TwapOracle internal twap;
    OracleHub internal oracleHub;
    STBToken internal stb;
    StableVault internal vault;

    function setUp() public {
        feed = new MockAggregatorV3(8, 2500e8);
        twap = new TwapOracle(owner);
        oracleHub = new OracleHub(owner, address(feed), address(twap));
        stb = new STBToken(owner);
        vault = new StableVault(owner, address(stb), address(oracleHub));

        stb.setVault(address(vault));
        twap.setPublisher(owner, true);
        twap.updateTwap(2500e18);

        oracleHub.transferOwnership(address(vault));
        vm.deal(alice, 1000e18);
    }

    function testDepositAndMintFlow() public {
        vm.startPrank(alice);
        vault.deposit{ value: 10e18 }(10e18);
        vault.mint(10_000e18);
        vm.stopPrank();

        (uint256 collateral, uint256 principal,, uint256 debtWithFee,,) = vault.getVault(alice);
        assertEq(collateral, 10e18);
        assertEq(principal, 10_000e18);
        assertEq(debtWithFee, 10_000e18);
        assertEq(stb.balanceOf(alice), 10_000e18);
    }

    function testWithdrawRevertsWhenCRTooLow() public {
        vm.startPrank(alice);
        vault.deposit{ value: 10e18 }(10e18);
        vault.mint(16_000e18);
        vm.expectRevert();
        vault.withdraw(1e18);
        vm.stopPrank();
    }

    function testMintRevertsWhenBreakerTriggered() public {
        vm.startPrank(alice);
        vault.deposit{ value: 10e18 }(10e18);
        vm.stopPrank();

        vm.prank(owner);
        feed.setAnswer(3500e8);

        vm.prank(alice);
        vm.expectRevert();
        vault.mint(1e18);
    }

    function testRepayAccruedFeeAndPrincipal() public {
        vm.startPrank(alice);
        vault.deposit{ value: 10e18 }(10e18);
        vault.mint(10_000e18);
        vault.mint(5_000e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days / 2);

        vm.startPrank(alice);
        stb.approve(address(vault), type(uint256).max);
        vault.repay(6_000e18);
        vm.stopPrank();

        (, uint256 principal, uint256 accruedFee, uint256 debtWithFee,,) = vault.getVault(alice);
        assertLt(principal, 10_000e18);
        assertEq(accruedFee, 0);
        assertEq(debtWithFee, principal);
        assertGt(vault.protocolReserveStb(), 0);
    }

    function testPartialLiquidationByKeeper() public {
        vm.startPrank(alice);
        vault.deposit{ value: 10e18 }(10e18);
        vault.mint(15_000e18);
        vm.stopPrank();

        vm.prank(owner);
        vault.setKeeper(keeper, true);

        vm.prank(owner);
        feed.setAnswer(1800e8);

        vm.prank(owner);
        twap.updateTwap(1800e18);

        vm.prank(alice);
        assertTrue(stb.transfer(keeper, 5_000e18));

        vm.startPrank(keeper);
        stb.approve(address(vault), type(uint256).max);
        vm.roll(block.number + 1);
        vault.liquidate(alice, 5_000e18);
        vm.stopPrank();

        (uint256 collateral,,, uint256 debtWithFee,,) = vault.getVault(alice);
        assertLt(collateral, 10e18);
        assertLt(debtWithFee, 15_000e18 + 1);
        assertGt(keeper.balance, 0);
    }

    function testUnderwaterPositionDoesNotCreateBadDebtInPartialLiquidation() public {
        vm.startPrank(alice);
        vault.deposit{ value: 2e18 }(2e18);
        vault.mint(2000e18);
        vault.mint(1000e18);
        vm.stopPrank();

        vm.prank(owner);
        vault.setKeeper(keeper, true);

        vm.prank(owner);
        feed.setAnswer(900e8);

        vm.prank(owner);
        twap.updateTwap(900e18);

        vm.prank(alice);
        assertTrue(stb.transfer(keeper, 1500e18));

        vm.startPrank(keeper);
        stb.approve(address(vault), type(uint256).max);
        vm.roll(block.number + 1);
        vault.liquidate(alice, 1500e18);
        vm.stopPrank();

        assertEq(vault.getSystemBadDebt(), 0);
    }

    function testCircuitBreakerAllowsDepositAndRepay() public {
        vm.startPrank(alice);
        vault.deposit{ value: 10e18 }(10e18);
        vault.mint(10_000e18);
        vault.mint(5_000e18);
        vm.stopPrank();

        vm.prank(owner);
        feed.setAnswer(4000e8);

        vm.startPrank(alice);
        vault.deposit{ value: 1e18 }(1e18);
        stb.approve(address(vault), type(uint256).max);
        vault.repay(100e18);
        vm.stopPrank();
    }

    function testLiquidationFlowAfterRiskAction() public {
        vm.startPrank(alice);
        vault.deposit{ value: 10e18 }(10e18);
        vault.mint(14_000e18);
        vm.stopPrank();

        vm.prank(owner);
        vault.setKeeper(keeper, true);

        vm.prank(alice);
        assertTrue(stb.transfer(keeper, 3_000e18));

        vm.prank(owner);
        feed.setAnswer(1400e8);

        vm.prank(owner);
        twap.updateTwap(1400e18);

        vm.roll(block.number + 1);

        vm.startPrank(alice);
        vm.expectRevert();
        vault.withdraw(0.2e18);
        vm.stopPrank();

        vm.startPrank(keeper);
        stb.approve(address(vault), type(uint256).max);
        vm.roll(block.number + 1);
        vault.liquidate(alice, 1_000e18);
        vm.stopPrank();

        assertGt(keeper.balance, 0);
    }

    function testAdminDemoPriceMode() public {
        vm.prank(owner);
        vault.setDemoMode(true);

        vm.prank(owner);
        vault.setDemoPrice(1500e18);

        (uint256 effectivePrice,,,,,) = oracleHub.getPriceStatus();
        assertEq(effectivePrice, 1500e18);
    }

    function testSameBlockLiquidationRevertsThenSucceedsNextBlock() public {
        vm.startPrank(alice);
        vault.deposit{ value: 10e18 }(10e18);
        vault.mint(14_000e18);
        vm.stopPrank();

        vm.prank(owner);
        vault.setKeeper(keeper, true);

        vm.prank(owner);
        feed.setAnswer(1400e8);

        vm.prank(owner);
        twap.updateTwap(1400e18);

        vm.prank(alice);
        assertTrue(stb.transfer(keeper, 1_000e18));

        vm.startPrank(keeper);
        stb.approve(address(vault), type(uint256).max);
        vm.expectRevert(StableVault.SameBlockRiskAction.selector);
        vault.liquidate(alice, 1_000e18);

        vm.roll(block.number + 1);
        vault.liquidate(alice, 1_000e18);
        vm.stopPrank();
    }

    function testBadDebtCoverBurnsReserveTokens() public {
        vm.startPrank(alice);
        vault.deposit{ value: 10e18 }(10e18);
        vault.mint(16_000e18);
        assertTrue(stb.transfer(keeper, 12_000e18));
        vm.stopPrank();

        vm.warp(block.timestamp + 4 * 365 days);

        vm.prank(owner);
        vault.setKeeper(keeper, true);

        vm.prank(owner);
        feed.setAnswer(972e8);

        vm.prank(owner);
        twap.updateTwap(972e18);

        vm.prank(alice);
        assertTrue(stb.transfer(keeper, 1e18));

        vm.startPrank(keeper);
        stb.approve(address(vault), type(uint256).max);
        vm.roll(block.number + 1);
        vault.liquidate(alice, 20_000e18);
        vm.stopPrank();

        uint256 reserveBefore = vault.protocolReserveStb();
        uint256 badDebtBeforeCover = vault.getSystemBadDebt();
        assertGt(reserveBefore, 0);
        assertGt(badDebtBeforeCover, 0);

        uint256 reserveTokenBalanceBefore = stb.balanceOf(address(vault));
        uint256 coverAmount =
            reserveBefore > badDebtBeforeCover ? badDebtBeforeCover : reserveBefore;

        vm.prank(owner);
        vault.coverBadDebt(coverAmount);

        assertEq(vault.getSystemBadDebt(), badDebtBeforeCover - coverAmount);
        assertEq(vault.protocolReserveStb(), reserveBefore - coverAmount);
        assertEq(stb.balanceOf(address(vault)), reserveTokenBalanceBefore - coverAmount);
    }
}
