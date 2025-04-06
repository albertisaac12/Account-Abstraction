// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {MinimalAccount} from "./../src/Ethereum/Minimal-Account.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMinimal is Script {
    function run() public {}

    function deployMinimalAccount()
        public
        returns (HelperConfig, MinimalAccount)
    {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // console.log("This is the fucking cause: ", config.account);

        vm.startBroadcast(config.account);

        MinimalAccount minimalAccount = new MinimalAccount(config.entryPoint);

        // console.log("This is the msg.sender", msg.sender);
        minimalAccount.transferOwnership(config.account);

        vm.stopBroadcast();

        return (helperConfig, minimalAccount);
    }
}
