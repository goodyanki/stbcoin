// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";

import { STBToken } from "../src/STBToken.sol";
import { TwapOracle } from "../src/TwapOracle.sol";
import { OracleHub } from "../src/OracleHub.sol";
import { StableVault } from "../src/StableVault.sol";

contract DeploySepolia is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);

        address chainlinkEthUsd = vm.envAddress("CHAINLINK_ETH_USD");
        address weth = vm.envAddress("WETH_ADDRESS");
        address keeper = vm.envOr("KEEPER_ADDRESS", owner);
        address oraclePublisher = vm.envOr("ORACLE_PUBLISHER", keeper);
        bool enableDemoMode = vm.envOr("ENABLE_DEMO_MODE", false);
        uint256 demoPriceE18 = vm.envOr("DEMO_PRICE_E18", uint256(0));

        vm.startBroadcast(deployerPrivateKey);

        STBToken stb = new STBToken(owner);
        TwapOracle twap = new TwapOracle(owner);
        OracleHub oracleHub = new OracleHub(owner, chainlinkEthUsd, address(twap));
        StableVault vault = new StableVault(owner, weth, address(stb), address(oracleHub));

        stb.setVault(address(vault));
        twap.setPublisher(owner, true);
        if (oraclePublisher != owner) {
            twap.setPublisher(oraclePublisher, true);
        }

        vault.setKeeper(keeper, true);

        if (enableDemoMode) {
            vault.setDemoMode(true);
            if (demoPriceE18 > 0) {
                vault.setDemoPrice(demoPriceE18);
            }
        }

        oracleHub.transferOwnership(address(vault));

        vm.stopBroadcast();
    }
}
