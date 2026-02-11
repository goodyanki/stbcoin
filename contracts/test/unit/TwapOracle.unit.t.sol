// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import { TwapOracle } from "../../src/TwapOracle.sol";

contract TwapOracleUnitTest is Test {
    address internal owner = address(this);
    address internal publisher = address(0xBEEF);
    address internal stranger = address(0xCAFE);

    TwapOracle internal twap;

    function setUp() public {
        twap = new TwapOracle(owner);
    }

    function testSetPublisherOnlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert();
        twap.setPublisher(publisher, true);

        twap.setPublisher(publisher, true);
        assertTrue(twap.isPublisher(publisher));
    }

    function testUpdateTwapByOwnerOrPublisher() public {
        twap.updateTwap(2500e18);
        (uint256 price, uint256 updatedAt) = twap.getTwap();
        assertEq(price, 2500e18);
        assertEq(updatedAt, block.timestamp);

        twap.setPublisher(publisher, true);
        vm.warp(block.timestamp + 15);

        vm.prank(publisher);
        twap.updateTwap(2400e18);
        (price, updatedAt) = twap.getTwap();
        assertEq(price, 2400e18);
        assertEq(updatedAt, block.timestamp);
    }

    function testUpdateTwapRevertsForNonPublisherAndZeroPrice() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(TwapOracle.NotPublisher.selector, stranger));
        twap.updateTwap(2000e18);

        vm.expectRevert(TwapOracle.InvalidPrice.selector);
        twap.updateTwap(0);
    }

    function testTransferOwnership() public {
        twap.transferOwnership(stranger);
        assertEq(twap.owner(), stranger);

        vm.expectRevert();
        twap.setPublisher(publisher, true);

        vm.prank(stranger);
        twap.setPublisher(publisher, true);
        assertTrue(twap.isPublisher(publisher));
    }
}
