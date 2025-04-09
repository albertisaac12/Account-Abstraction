// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {dappunkCreations} from "./../src/dappunk/dappunkCreations.sol";
import {logic} from "./../src/dappunk/forwarder.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMinimal is Script {
    function run() public {}

    function deployDappunkCreations() public returns (dappunkCreations, address) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address account = config.account;
        address[] memory relayers = new address[](1);
        relayers[0] = account;

        vm.startBroadcast(account);
        logic lc = new logic("meow");
        dappunkCreations dc =
            new dappunkCreations(account, account, account, account, account, account, account, relayers, address(lc));
        vm.stopBroadcast();

        return (dc, address(dc));
    }
}
