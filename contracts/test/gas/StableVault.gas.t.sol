// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import { MockAggregatorV3 } from "../mocks/MockAggregatorV3.sol";
import { STBToken } from "../../src/STBToken.sol";
import { TwapOracle } from "../../src/TwapOracle.sol";
import { OracleHub } from "../../src/OracleHub.sol";
import { StableVault } from "../../src/StableVault.sol";

contract StableVaultGasTest is Test {
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

    function testGasDeposit() public {
        vm.startPrank(alice);
        uint256 gasStart = gasleft();
        vault.deposit{ value: 1e18 }(1e18);
        uint256 gasUsed = gasStart - gasleft();
        vm.stopPrank();

        assertLt(gasUsed, 120_000);
    }

    function testGasMint() public {
        vm.startPrank(alice);
        vault.deposit{ value: 10e18 }(10e18);
        uint256 gasStart = gasleft();
        vault.mint(2_000e18);
        uint256 gasUsed = gasStart - gasleft();
        vm.stopPrank();

        assertLt(gasUsed, 200_000);
    }

    function testGasRepay() public {
        vm.startPrank(alice);
        vault.deposit{ value: 10e18 }(10e18);
        vault.mint(2_000e18);
        stb.approve(address(vault), type(uint256).max);
        uint256 gasStart = gasleft();
        vault.repay(500e18);
        uint256 gasUsed = gasStart - gasleft();
        vm.stopPrank();

        assertLt(gasUsed, 180_000);
    }

    function testGasLiquidate() public {
        vm.startPrank(alice);
        vault.deposit{ value: 10e18 }(10e18);
        vault.mint(14_000e18);
        assertTrue(stb.transfer(keeper, 2_000e18));
        vm.stopPrank();

        feed.setAnswer(1400e8);
        twap.updateTwap(1400e18);

        vm.startPrank(keeper);
        stb.approve(address(vault), type(uint256).max);
        vm.roll(block.number + 1);
        uint256 gasStart = gasleft();
        vault.liquidate(alice, 1_000e18);
        uint256 gasUsed = gasStart - gasleft();
        vm.stopPrank();

        assertLt(gasUsed, 320_000);
    }
}
