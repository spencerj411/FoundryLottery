// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

import {BLOCKCHAIN_IDS} from "script/libraries/BlockchainIds.sol";
import {MOCK_CONSTANTS} from "script/libraries/MockConstants.sol";

contract HelperConfig is Script {
    error HelperConfig__BlockchainNotCompatible(uint256 blockchainId);

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        uint256 subscriptionId;
        bytes32 gasLane; // keyHash
        uint32 callbackGasLimit;
        address link;
    }

    uint256 private constant ENTRACE_FEE = 0.01 ether;
    uint256 private constant INTERVAL = 60; // seconds
    uint32 private constant CALLBACK_GAS_LIMIT = 500_000;
    uint96 private constant LINK_FUND_AMOUNT = 3 ether; // 3 LINK

    NetworkConfig private s_activeNetworkConfig;

    constructor() {
        console.log("msg.sender of HelperConfig:", msg.sender);
        if (block.chainid == BLOCKCHAIN_IDS.SEPOLIA_ID) {
            s_activeNetworkConfig = NetworkConfig({
                entranceFee: ENTRACE_FEE,
                interval: INTERVAL,
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                subscriptionId: 0, // If left as 0, one will be created
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                callbackGasLimit: CALLBACK_GAS_LIMIT,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            });
        } else if (block.chainid == BLOCKCHAIN_IDS.ANVIL_ID) {
            // deploy mock of vrf coordinator to local chain
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
                    MOCK_CONSTANTS.BASE_FEE,
                    MOCK_CONSTANTS.GAS_PRICE_LINK,
                    MOCK_CONSTANTS.WEI_PER_UNIT_LINK
                );
            LinkToken linkToken = new LinkToken();
            vm.stopBroadcast();
            //  add mocks' addresses in network config
            s_activeNetworkConfig = NetworkConfig({
                entranceFee: ENTRACE_FEE,
                interval: INTERVAL,
                vrfCoordinator: address(vrfCoordinatorMock),
                subscriptionId: 0, // If left as 0, one will be created
                gasLane: 0x0, // apparently does not matter
                callbackGasLimit: CALLBACK_GAS_LIMIT,
                link: address(linkToken)
            });
        } else {
            revert HelperConfig__BlockchainNotCompatible(block.chainid);
        }
        setUpVRFSubscriptionAndConsumer();
    }

    function setUpVRFSubscriptionAndConsumer() internal {
        uint256 subId;
        address vrfCoordinator = s_activeNetworkConfig.vrfCoordinator;
        // if no subscription is set up, create one
        if (s_activeNetworkConfig.subscriptionId == 0) {
            subId = _createVRFSubscription(vrfCoordinator);
        } else {
            subId = s_activeNetworkConfig.subscriptionId;
        }

        // fund subscription
        // if (block.chainid == BLOCKCHAIN_IDS.ANVIL_ID) {
        //     vm.startBroadcast();
        //     // VRF Coordinator mock gives us a function to mimick funding the mock contract with LINK
        //     VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
        //         subId,
        //         LINK_FUND_AMOUNT
        //     );
        //     vm.stopBroadcast();
        // } else {
        //     // if blockchain is either testnet or a mainnet (not a local chain)
        //     LinkToken(s_activeNetworkConfig.link).transferAndCall(
        //         vrfCoordinator,
        //         LINK_FUND_AMOUNT,
        //         abi.encode(subId)
        //     );
        // }
        console.log("balance of transaction sender:", msg.sender);
        console.log(
            LinkToken(s_activeNetworkConfig.link).balanceOf(msg.sender)
        );
        console.log("balance of this:", address(this));
        console.log(
            LinkToken(s_activeNetworkConfig.link).balanceOf(address(this))
        );
        console.log("LINK FUND AMOUNT:", LINK_FUND_AMOUNT);
        console.log("balance of msg.sender > link fund amount");
        console.log(
            LinkToken(s_activeNetworkConfig.link).balanceOf(msg.sender) >
                LINK_FUND_AMOUNT
        );
        LinkToken(s_activeNetworkConfig.link).transferAndCall(
            vrfCoordinator,
            LINK_FUND_AMOUNT,
            abi.encode(subId)
        );

        // TODO: add consumer to subscription
    }

    function _createVRFSubscription(
        address vrfCoordinator
    ) internal returns (uint256) {
        console.log("creating a VRF subscription");
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        console.log("subscription ID:", subId);
        return subId;
    }

    function getActiveConfig() external view returns (NetworkConfig memory) {
        return s_activeNetworkConfig;
    }
}
