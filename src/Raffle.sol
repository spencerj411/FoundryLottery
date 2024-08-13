// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title A Raffle Smart Contract
 * @author spencerj411
 * @notice Smart contract for creating raffles
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle {
    error Raffle__EntranceFeeNotMet();

    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    /* Events */
    event EnteredRaffle(address indexed player);

    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__EntranceFeeNotMet();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function pickWinner() public {}

    /* Getter Functions */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayers() external view returns (address payable[] memory) {
        return s_players;
    }
}
