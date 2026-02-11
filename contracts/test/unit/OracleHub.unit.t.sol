// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import { MockAggregatorV3 } from "../mocks/MockAggregatorV3.sol";
import { TwapOracle } from "../../src/TwapOracle.sol";
import { OracleHub } from "../../src/OracleHub.sol";

contract OracleHubUnitTest is Test {
    address internal owner = address(this);
    address internal stranger = address(0xCAFE);

    MockAggregatorV3 internal feed;
    TwapOracle internal twap;
    OracleHub internal hub;

    function setUp() public {
        feed = new MockAggregatorV3(8, 2500e8);
        twap = new TwapOracle(owner);
        twap.setPublisher(owner, true);
        twap.updateTwap(2500e18);
        hub = new OracleHub(owner, address(feed), address(twap));
    }

    function testGetPriceStatusNormal() public view {
        (uint256 effective, uint256 spot, uint256 twapPrice,,, bool breaker) = hub.getPriceStatus();
        assertEq(effective, 2500e18);
        assertEq(spot, 2500e18);
        assertEq(twapPrice, 2500e18);
        assertFalse(breaker);
    }

    function testDeviationTriggersBreaker() public {
        feed.setAnswer(4000e8);
        (,,,,, bool breaker) = hub.getPriceStatus();
        assertTrue(breaker);
        assertFalse(hub.canRiskActionProceed());
    }

    function testStalePriceTriggersBreaker() public {
        vm.warp(10_000);
        uint256 stale = block.timestamp - 2 hours;
        feed.setAnswerWithTimestamp(2500e8, stale);
        (,,,,, bool breaker) = hub.getPriceStatus();
        assertTrue(breaker);
    }

    function testGetValidatedPriceRevertsOnBreaker() public {
        feed.setAnswer(4000e8);
        vm.expectRevert(OracleHub.InvalidPrice.selector);
        hub.getValidatedPrice();
    }

    function testConfigAndDemoMode() public {
        hub.setConfig(7200, 1800, 800);
        assertEq(hub.spotMaxAge(), 7200);
        assertEq(hub.twapMaxAge(), 1800);
        assertEq(hub.maxDeviationBps(), 800);

        hub.setDemoMode(true);
        hub.setDemoPrice(1800e18);

        (uint256 effective,,,,, bool breaker) = hub.getPriceStatus();
        assertEq(effective, 1800e18);
        assertFalse(breaker);
        assertEq(hub.getValidatedPrice(), 1800e18);
    }

    function testDemoPriceRevertsWithoutDemoModeOrZero() public {
        vm.expectRevert(OracleHub.InvalidPrice.selector);
        hub.setDemoPrice(1e18);

        hub.setDemoMode(true);
        vm.expectRevert(OracleHub.InvalidPrice.selector);
        hub.setDemoPrice(0);
    }

    function testOnlyOwnerMethodsRevertForStranger() public {
        vm.startPrank(stranger);
        vm.expectRevert();
        hub.setConfig(1, 1, 1);
        vm.expectRevert();
        hub.setDemoMode(true);
        vm.expectRevert();
        hub.setDemoPrice(1e18);
        vm.stopPrank();
    }

    function testTransferOwnership() public {
        hub.transferOwnership(stranger);
        assertEq(hub.owner(), stranger);

        vm.expectRevert();
        hub.setConfig(1, 1, 1);

        vm.prank(stranger);
        hub.setConfig(2, 2, 2);
        assertEq(hub.spotMaxAge(), 2);
    }
}
