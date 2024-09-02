// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

import {CONSTANTS} from "script/libraries/Constants.sol";

contract SetupVRF is Script {
    error SetupVRF__SubscriptionRequired();

    HelperConfig helperConfig;

    function run() external {
        helperConfig = new HelperConfig();
        createSubscription();
        fundSubscription();
        addConsumer();
    }

    function createSubscription()
        private
        returns (HelperConfig.NetworkConfig memory)
    {
        HelperConfig.NetworkConfig memory activeConfig = helperConfig
            .getActiveConfig();
        if (activeConfig.subscriptionId == 0) {
            vm.startBroadcast();
            vm.roll(block.number + 1);
            activeConfig.subscriptionId = VRFCoordinatorV2_5Mock(
                activeConfig.vrfCoordinator
            ).createSubscription();
            vm.stopBroadcast();

            helperConfig.updateConfig(activeConfig);
        }
        console.log(
            "CreateSubscription - New VRF Subscription created. Update HelperConfig with the subscription ID:",
            activeConfig.subscriptionId
        );
        return activeConfig;
    }

    function fundSubscription() public {
        HelperConfig.NetworkConfig memory activeConfig = helperConfig
            .getActiveConfig();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = VRFCoordinatorV2_5Mock(
            activeConfig.vrfCoordinator
        );
        if (activeConfig.subscriptionId == 0) {
            createSubscription();
            activeConfig = helperConfig.getActiveConfig();
        }

        if (block.chainid == CONSTANTS.ANVIL_ID) {
            vm.startBroadcast();
            // VRF Coordinator mock gives us a function to mimic funding the mock contract with LINK
            vrfCoordinatorMock.fundSubscription(
                activeConfig.subscriptionId,
                CONSTANTS.LINK_FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            // if blockchain is either testnet or a mainnet (not a local chain)
            vm.startBroadcast();
            LinkToken(activeConfig.link).transferAndCall(
                activeConfig.vrfCoordinator,
                CONSTANTS.LINK_FUND_AMOUNT,
                abi.encode(activeConfig.subscriptionId)
            );
            vm.stopBroadcast();
        }
        console.log(
            "FundSubscription - VRF Subscription funded with the subscription ID",
            activeConfig.subscriptionId
        );
    }

    function addConsumer() private {
        HelperConfig.NetworkConfig memory activeConfig = helperConfig
            .getActiveConfig();
        if (activeConfig.subscriptionId == 0) {
            createSubscription();
            activeConfig = helperConfig.getActiveConfig();
        }

        address mostRecentlyDeployedRaffleContract = DevOpsTools
            .get_most_recent_deployment("Raffle", block.chainid);
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(activeConfig.vrfCoordinator).addConsumer(
            activeConfig.subscriptionId,
            mostRecentlyDeployedRaffleContract
        );
        vm.stopBroadcast();
    }
}
