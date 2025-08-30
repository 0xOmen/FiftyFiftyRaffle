// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "../lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {FiftyFiftyRaffle} from "../src/FiftyFiftyRaffle.sol";

contract DeployRaffle is Script {
    uint256 public constant PROTOCOL_FEE = 50; // 0.5%

    function run() public returns (FiftyFiftyRaffle, address) {
        HelperConfig helperConfig = new HelperConfig();
        (address usdc, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        if (deployerKey == 0) {
            vm.startBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
        }
        FiftyFiftyRaffle raffle = new FiftyFiftyRaffle(usdc, PROTOCOL_FEE);
        vm.stopBroadcast();

        return (raffle, usdc);
    }
}
