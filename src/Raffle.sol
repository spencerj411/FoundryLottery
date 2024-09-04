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
    /* Errors */
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );
    error Raffle__EntranceFeeNotMet();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();

    /* Type declarations */
    enum RaffleState {
        OPEN,
        PENDING
    }

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
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /* Events */
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address payable indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);

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
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__EntranceFeeNotMet();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool timePassed = ((block.timestamp - s_lastStartTimestamp) >
            i_interval);
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0"); // can we comment this out?
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        // require(upkeepNeeded, "Upkeep not needed");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.PENDING;

        // Will revert if subscription is not set and funded.
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

        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] calldata randomWords
    ) internal override {
        address payable winner = s_players[randomWords[0] % s_players.length];
        emit WinnerPicked(winner);
        s_players = new address payable[](0);
        s_lastStartTimestamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /* Getter Functions */
    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayers() external view returns (address payable[] memory) {
        return s_players;
    }
}
