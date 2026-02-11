// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import { MockAggregatorV3 } from "../mocks/MockAggregatorV3.sol";
import { STBToken } from "../../src/STBToken.sol";
import { TwapOracle } from "../../src/TwapOracle.sol";
import { OracleHub } from "../../src/OracleHub.sol";
import { StableVault } from "../../src/StableVault.sol";

contract StableVaultAdminUnitTest is Test {
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

        vm.deal(alice, 100e18);
    }

    function testPauseBlocksMutations() public {
        vault.setPause(true);
        assertTrue(vault.paused());

        vm.prank(alice);
        vm.expectRevert(StableVault.Paused.selector);
        vault.deposit{ value: 1e18 }(1e18);
    }

    function testSetRiskParamsAndStabilityFee() public {
        vault.setRiskParams(16_000, 18_000, 900, 4_000);
        assertEq(vault.minCollateralRatioBps(), 16_000);
        assertEq(vault.targetCollateralRatioBps(), 18_000);
        assertEq(vault.liquidationBonusBps(), 900);
        assertEq(vault.maxCloseFactorBps(), 4_000);

        vault.setStabilityFeeBps(500);
        assertEq(vault.stabilityFeeBps(), 500);
    }

    function testSetRiskParamsRevertsOnInvalidInputs() public {
        vm.expectRevert(StableVault.InvalidParams.selector);
        vault.setRiskParams(10_000, 18_000, 800, 5_000);

        vm.expectRevert(StableVault.InvalidParams.selector);
        vault.setRiskParams(15_000, 15_000, 800, 5_000);

        vm.expectRevert(StableVault.InvalidParams.selector);
        vault.setRiskParams(15_000, 17_000, 3_000, 5_000);

        vm.expectRevert(StableVault.InvalidParams.selector);
        vault.setRiskParams(15_000, 17_000, 800, 0);

        vm.expectRevert(StableVault.InvalidParams.selector);
        vault.setStabilityFeeBps(2_001);
    }

    function testKeeperAndOracleAdminPassThrough() public {
        vault.setKeeper(keeper, true);
        assertTrue(vault.isKeeper(keeper));

        vault.setDemoMode(true);
        vault.setDemoPrice(1200e18);
        (uint256 effective,,,,, bool breaker) = oracleHub.getPriceStatus();
        assertEq(effective, 1200e18);
        assertFalse(breaker);

        vault.setOracleConfig(7200, 1800, 900);
        assertEq(oracleHub.spotMaxAge(), 7200);
        assertEq(oracleHub.twapMaxAge(), 1800);
        assertEq(oracleHub.maxDeviationBps(), 900);
    }

    function testViewHelpersAndReceiveEther() public {
        assertEq(vault.getSystemBadDebt(), 0);
        assertEq(vault.getCollateralRatioBps(alice), type(uint256).max);
        assertFalse(vault.isLiquidatable(alice));

        vm.prank(alice);
        (bool ok,) = address(vault).call{ value: 1e18 }("");
        assertTrue(ok);
        assertEq(address(vault).balance, 1e18);
    }

    function testTransferOwnership() public {
        vault.transferOwnership(alice);
        assertEq(vault.owner(), alice);

        vm.expectRevert();
        vault.setPause(true);

        vm.prank(alice);
        vault.setPause(true);
        assertTrue(vault.paused());
    }
}
