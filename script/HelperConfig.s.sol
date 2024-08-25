// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

import {CONSTANTS} from "script/libraries/Constants.sol";

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

    NetworkConfig private s_activeNetworkConfig;

    constructor() {
        if (block.chainid == CONSTANTS.SEPOLIA_ID) {
            s_activeNetworkConfig = NetworkConfig({
                entranceFee: CONSTANTS.ENTRACE_FEE,
                interval: CONSTANTS.INTERVAL,
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                subscriptionId: 0, // placeholder
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                callbackGasLimit: CONSTANTS.CALLBACK_GAS_LIMIT,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            });
        } else if (block.chainid == CONSTANTS.ANVIL_ID) {
            // deploy mock of vrf coordinator to local chain
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
                    CONSTANTS.BASE_FEE,
                    CONSTANTS.GAS_PRICE_LINK,
                    CONSTANTS.WEI_PER_UNIT_LINK
                );
            LinkToken linkToken = new LinkToken();
            vm.stopBroadcast();
            //  add mocks' addresses in network config
            s_activeNetworkConfig = NetworkConfig({
                entranceFee: CONSTANTS.ENTRACE_FEE,
                interval: CONSTANTS.INTERVAL,
                vrfCoordinator: address(vrfCoordinatorMock),
                subscriptionId: 0, // placeholder
                gasLane: 0x0, // apparently does not matter
                callbackGasLimit: CONSTANTS.CALLBACK_GAS_LIMIT,
                link: address(linkToken)
            });
        } else {
            revert HelperConfig__BlockchainNotCompatible(block.chainid);
        }
    }

    function getActiveConfig() external view returns (NetworkConfig memory) {
        return s_activeNetworkConfig;
    }
}
