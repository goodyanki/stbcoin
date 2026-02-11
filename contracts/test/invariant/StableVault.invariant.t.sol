// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import { MockAggregatorV3 } from "../mocks/MockAggregatorV3.sol";
import { STBToken } from "../../src/STBToken.sol";
import { TwapOracle } from "../../src/TwapOracle.sol";
import { OracleHub } from "../../src/OracleHub.sol";
import { StableVault } from "../../src/StableVault.sol";

contract StableVaultInvariantTest is Test {
    address internal owner = address(this);
    address internal user = address(0xBEEF);

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

        vm.deal(user, 1000e18);
        vm.startPrank(user);
        vault.deposit{ value: 100e18 }(100e18);
        vault.mint(50_000e18);
        vm.stopPrank();

        excludeSender(owner);
        bytes4[] memory blocked = new bytes4[](2);
        blocked[0] = bytes4(keccak256("setDemoMode(bool)"));
        blocked[1] = bytes4(keccak256("setDemoPrice(uint256)"));
        excludeSelector(FuzzSelector({ addr: address(vault), selectors: blocked }));

        targetContract(address(vault));
    }

    function invariantSupplyCoversDebtOrBadDebt() public view {
        (, uint256 principal, uint256 accruedFee, uint256 debtWithFee,,) = vault.getVault(user);
        uint256 outstanding = principal + accruedFee;

        uint256 supply = stb.totalSupply();
        uint256 reserve = vault.protocolReserveStb();
        uint256 badDebt = vault.getSystemBadDebt();

        assertGe(supply + reserve + badDebt, outstanding);
        assertGe(debtWithFee, principal + accruedFee);
    }

    function invariantLiquidatableFlagConsistent() public view {
        (,,, uint256 debtWithFee,,) = vault.getVault(user);
        bool liquidatable = vault.isLiquidatable(user);
        if (debtWithFee == 0) {
            assertFalse(liquidatable);
        }
    }
}
