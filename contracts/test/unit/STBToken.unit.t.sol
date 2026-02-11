// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import { STBToken } from "../../src/STBToken.sol";

contract STBTokenUnitTest is Test {
    address internal owner = address(this);
    address internal vault = address(0xBEEF);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    STBToken internal token;

    function setUp() public {
        token = new STBToken(owner);
    }

    function testSetVaultOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.setVault(vault);

        token.setVault(vault);
        assertEq(token.vault(), vault);
    }

    function testTransferOwnership() public {
        token.transferOwnership(alice);
        assertEq(token.owner(), alice);

        vm.prank(owner);
        vm.expectRevert();
        token.setVault(vault);

        vm.prank(alice);
        token.setVault(vault);
        assertEq(token.vault(), vault);
    }

    function testSetVaultRevertZeroAddress() public {
        vm.expectRevert(STBToken.ZeroAddress.selector);
        token.setVault(address(0));
    }

    function testMintAndBurnOnlyVault() public {
        vm.expectRevert(abi.encodeWithSelector(STBToken.NotVault.selector, address(this)));
        token.mint(alice, 1e18);

        token.setVault(vault);

        vm.prank(vault);
        token.mint(alice, 5e18);
        assertEq(token.balanceOf(alice), 5e18);
        assertEq(token.totalSupply(), 5e18);

        vm.prank(vault);
        token.burn(alice, 2e18);
        assertEq(token.balanceOf(alice), 3e18);
        assertEq(token.totalSupply(), 3e18);
    }

    function testTransferApproveTransferFrom() public {
        token.setVault(vault);
        vm.prank(vault);
        token.mint(alice, 10e18);

        vm.prank(alice);
        assertTrue(token.transfer(bob, 3e18));
        assertEq(token.balanceOf(alice), 7e18);
        assertEq(token.balanceOf(bob), 3e18);

        vm.prank(alice);
        assertTrue(token.approve(bob, 2e18));
        assertEq(token.allowance(alice, bob), 2e18);

        vm.prank(bob);
        assertTrue(token.transferFrom(alice, bob, 1e18));
        assertEq(token.allowance(alice, bob), 1e18);
        assertEq(token.balanceOf(alice), 6e18);
        assertEq(token.balanceOf(bob), 4e18);
    }

    function testTransferFromWithInfiniteAllowance() public {
        token.setVault(vault);
        vm.prank(vault);
        token.mint(alice, 10e18);

        vm.prank(alice);
        token.approve(bob, type(uint256).max);

        vm.prank(bob);
        token.transferFrom(alice, bob, 4e18);
        assertEq(token.allowance(alice, bob), type(uint256).max);
    }

    function testFuzzTransferConservesSupply(uint96 amount) public {
        uint256 mintAmount = bound(uint256(amount), 1, 1_000_000e18);

        token.setVault(vault);
        vm.prank(vault);
        token.mint(alice, mintAmount);

        vm.prank(alice);
        token.transfer(bob, mintAmount);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), mintAmount);
        assertEq(token.totalSupply(), mintAmount);
    }
}
