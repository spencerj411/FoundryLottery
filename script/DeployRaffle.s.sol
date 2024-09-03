// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {SetupVRF} from "script/Interactions.s.sol";

contract DeployRaffle is Script {
    function run() public returns (Raffle, HelperConfig) {
        return deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        SetupVRF setupVRF = new SetupVRF(helperConfig);
        if (setupVRF.getActiveConfig().subscriptionId == 0) {
            setupVRF.createSubscription();
            setupVRF.fundSubscription();
        }
        HelperConfig.NetworkConfig memory networkConfig = setupVRF
            .getActiveConfig();
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.subscriptionId,
            networkConfig.gasLane,
            networkConfig.callbackGasLimit
        );
        vm.stopBroadcast();
        setupVRF.addConsumer(address(raffle));
        return (raffle, setupVRF.helperConfig());
    }
}
