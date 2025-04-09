// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {MinimalAccount} from "./../src/Ethereum/Minimal-Account.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {dappunkCreations} from "./../src/dappunk/dappunkCreations.sol";
import {logic} from "./../src/dappunk/forwarder.sol";

contract DeployMinimal is Script {
    function run() public {}

    function deployMinimalAccount() public returns (HelperConfig, MinimalAccount, dappunkCreations) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address account = config.account;
        address[] memory relayers = new address[](1);
        relayers[0] = account;
        // console.log("This is the fucking cause: ", config.account);

        vm.startBroadcast(config.account);

        MinimalAccount minimalAccount = new MinimalAccount(config.entryPoint);
        // console.log("This is the msg.sender", msg.sender);
        minimalAccount.transferOwnership(config.account);

        logic lc = new logic("meow");
        dappunkCreations dc =
            new dappunkCreations(account, account, account, account, account, account, account, relayers, address(lc));
        dc.grantRole(0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6, address(minimalAccount));

        vm.stopBroadcast();

        return (helperConfig, minimalAccount, dc);
    }
}
