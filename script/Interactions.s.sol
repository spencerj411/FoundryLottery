// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

import {CONSTANTS} from "script/libraries/Constants.sol";

contract CreateSubscription is Script {
    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory activeConfig = helperConfig
            .getActiveConfig();
        uint256 subId;
        if (activeConfig.subscriptionId == 0) {
            vm.startBroadcast();
            subId = VRFCoordinatorV2_5Mock(activeConfig.vrfCoordinator)
                .createSubscription();
            vm.stopBroadcast();
        } else {
            subId = activeConfig.subscriptionId;
        }
        console.log(
            "CreateSubscription - New VRF Subscription created. Update HelperConfig with the subscription ID:",
            subId
        );
    }
}

contract FundSubscription is Script {
    error FundSubscription__SubscriptionRequired();

    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory activeConfig = helperConfig
            .getActiveConfig();
        uint256 subId;
        if (activeConfig.subscriptionId == 0) {
            // see if you can call CreateSubscription.run() and have it not error
            revert FundSubscription__SubscriptionRequired();
        } else {
            subId = activeConfig.subscriptionId;
        }

        if (block.chainid == CONSTANTS.ANVIL_ID) {
            vm.startBroadcast();
            // VRF Coordinator mock gives us a function to mimick funding the mock contract with LINK
            VRFCoordinatorV2_5Mock(activeConfig.vrfCoordinator)
                .fundSubscription(subId, CONSTANTS.LINK_FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            // if blockchain is either testnet or a mainnet (not a local chain)
            vm.startBroadcast();
            LinkToken(activeConfig.link).transferAndCall(
                activeConfig.vrfCoordinator,
                CONSTANTS.LINK_FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
        console.log(
            "FundSubscription - VRF Subscription funded with the subscription ID",
            subId
        );
    }
}

contract AddConsumer is Script {
    error AddConsumer__SubscriptionRequired();

    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory activeConfig = helperConfig
            .getActiveConfig();
        uint256 subId;
        if (activeConfig.subscriptionId == 0) {
            // see if you can call CreateSubscription.run() and have it not error
            revert AddConsumer__SubscriptionRequired();
        } else {
            subId = activeConfig.subscriptionId;
        }
        address mostRecentlyDeployedRaffleContract = DevOpsTools
            .get_most_recent_deployment("Raffle", block.chainid);
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(activeConfig.vrfCoordinator).addConsumer(
            subId,
            mostRecentlyDeployedRaffleContract
        );
        vm.stopBroadcast();
    }
}
