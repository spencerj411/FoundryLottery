// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A Raffle Smart Contract
 * @author spencerj411
 * @notice Smart contract for creating raffles
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    error Raffle__EntranceFeeNotMet();
    error Raffle__TransferFailed();

    /* Constant variables */
    uint16 private REQUEST_CONFIRMATIONS = 3;
    uint16 private NUM_WORDS = 1;

    /* Immutable variables */
    uint256 private immutable i_entranceFee;
    // The duration/length of the lottery in seconds
    uint256 private immutable i_interval;

    /* Chainlink VRF related variables */
    // id of the subscription contract counterpart (on the chainlink end)
    uint256 private immutable i_subscriptionId;
    // determines how much gas to use when requesting for words/numbers from Chainlink ???
    bytes32 private immutable i_gasLane;
    // limit on how much gas can be used by the subscription contract when calling back to return requested words/numbers
    uint32 private immutable i_callbackGasLimit;

    /* Storage variables */
    address payable[] private s_players;
    uint256 private s_lastStartTimestamp;

    /* Events */
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address payable indexed player);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        uint256 subscriptionId,
        bytes32 gasLane, // keyHash
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        s_lastStartTimestamp = block.timestamp;
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_gasLane = gasLane;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__EntranceFeeNotMet();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function pickWinner() external {
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] calldata randomWords
    ) internal override {
        address payable winner = s_players[randomWords[0] % s_players.length];
        emit WinnerPicked(winner);
        s_players = new address payable[](0);
        s_lastStartTimestamp = block.timestamp;
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /* Getter Functions */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayers() external view returns (address payable[] memory) {
        return s_players;
    }
}
