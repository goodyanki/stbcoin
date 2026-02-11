// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import { MockAggregatorV3 } from "../mocks/MockAggregatorV3.sol";
import { STBToken } from "../../src/STBToken.sol";
import { TwapOracle } from "../../src/TwapOracle.sol";
import { OracleHub } from "../../src/OracleHub.sol";
import { StableVault } from "../../src/StableVault.sol";

contract StableVaultIntegrationTest is Test {
    address internal owner = address(this);
    address internal alice = address(0xA11CE);
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

        vault.setKeeper(keeper, true);
        vm.deal(alice, 100e18);
    }

    function testEndToEndDepositMintRepayWithdraw() public {
        vm.startPrank(alice);
        vault.deposit{ value: 12e18 }(12e18);
        vault.mint(8_000e18);
        stb.approve(address(vault), type(uint256).max);
        vault.repay(3_000e18);
        vault.withdraw(2e18);
        vm.stopPrank();

        (uint256 collateral, uint256 principal,, uint256 debtWithFee,,) = vault.getVault(alice);
        assertEq(collateral, 10e18);
        assertEq(principal, 5_000e18);
        assertGe(debtWithFee, 5_000e18);
        assertEq(stb.balanceOf(alice), 5_000e18);
    }

    function testEndToEndLiquidationCreatesBadDebtWhenCollateralExhausted() public {
        vm.startPrank(alice);
        vault.deposit{ value: 10e18 }(10e18);
        vault.mint(16_000e18);
        assertTrue(stb.transfer(keeper, 12_000e18));
        vm.stopPrank();

        vm.warp(block.timestamp + 4 * 365 days);
        feed.setAnswer(972e8);
        twap.updateTwap(972e18);

        vm.prank(alice);
        assertTrue(stb.transfer(keeper, 1e18));

        vm.startPrank(keeper);
        stb.approve(address(vault), type(uint256).max);
        vm.roll(block.number + 1);
        vault.liquidate(alice, 20_000e18);
        vm.stopPrank();

        (, uint256 principal, uint256 fee,,,) = vault.getVault(alice);
        assertEq(principal + fee, 0);
        assertGt(vault.getSystemBadDebt(), 0);
    }
}
