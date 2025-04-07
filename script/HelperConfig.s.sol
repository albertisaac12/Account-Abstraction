// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Script, console, console2} from "forge-std/Script.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address entryPoint;
        address account;
    }

    uint256 constant AMOY = 80002;
    uint256 constant ZK = 300;
    uint256 constant LOCAL = 31337;

    address constant BURNER_WALLET = 0x4910A3E9f7d9A04eEed15093F33f9Ec26d480F2D;
    // address constant FOUNDRY_DEFAULT_WALLET =
    //     0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[AMOY] = getAMOYConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == LOCAL) {
            return getOrCreateAnvilEthConfig();
        } else if (networkConfigs[chainId].account != address(0)) {
            return networkConfigs[chainId];
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getAMOYConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789, account: BURNER_WALLET});
    }

    function ZKConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({entryPoint: address(0), account: BURNER_WALLET});
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.account == address(0)) {
            console2.log("Deploying Mocks...");

            // vm.startBroadcast(FOUNDRY_DEFAULT_WALLET);
            vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT);
            EntryPoint entryPoint = new EntryPoint();
            vm.stopBroadcast();

            localNetworkConfig = NetworkConfig({
                entryPoint: address(entryPoint),
                // account: FOUNDRY_DEFAULT_WALLET
                account: ANVIL_DEFAULT_ACCOUNT
            });

            console2.log(localNetworkConfig.entryPoint);
        }

        return localNetworkConfig;
    }
}
