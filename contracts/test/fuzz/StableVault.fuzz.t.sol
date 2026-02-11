// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import { MockAggregatorV3 } from "../mocks/MockAggregatorV3.sol";
import { STBToken } from "../../src/STBToken.sol";
import { TwapOracle } from "../../src/TwapOracle.sol";
import { OracleHub } from "../../src/OracleHub.sol";
import { StableVault } from "../../src/StableVault.sol";

contract StableVaultFuzzTest is Test {
    address internal owner = address(this);
    address internal alice = address(0xA11CE);

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

        vm.deal(alice, 1_000_000e18);
    }

    function testFuzzMintRespectsMinCR(uint96 collateralIn, uint96 mintIn) public {
        uint256 collateral = bound(uint256(collateralIn), 1e18, 1_000e18);
        // max mint that still stays >= 150% CR at 2500 usd/ETH
        uint256 maxMint = (collateral * 2500e18 * 10_000) / (15_000 * 1e18);
        maxMint = bound(maxMint, 1e18, 1_000_000e18);
        uint256 mintAmount = bound(uint256(mintIn), 1e18, maxMint);

        vm.startPrank(alice);
        vault.deposit{ value: collateral }(collateral);
        vault.mint(mintAmount);
        vm.stopPrank();

        uint256 cr = vault.getCollateralRatioBps(alice);
        assertGe(cr, vault.minCollateralRatioBps());
    }

    function testFuzzRepayNeverIncreasesDebt(uint96 mintIn, uint96 repayIn) public {
        uint256 mintAmount = bound(uint256(mintIn), 1e18, 20_000e18);

        vm.startPrank(alice);
        vault.deposit{ value: 20e18 }(20e18);
        vault.mint(mintAmount);
        vm.stopPrank();

        vm.warp(block.timestamp + 60 days);

        (, , , uint256 debtBefore,,) = vault.getVault(alice);
        uint256 available = stb.balanceOf(alice);
        uint256 upper = available < debtBefore ? available : debtBefore;
        uint256 repayAmount = bound(uint256(repayIn), 1e18, upper);

        vm.startPrank(alice);
        stb.approve(address(vault), type(uint256).max);
        vault.repay(repayAmount);
        vm.stopPrank();

        (, , , uint256 debtAfter,,) = vault.getVault(alice);
        assertLe(debtAfter, debtBefore);
    }
}
