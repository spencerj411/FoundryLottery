// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";

import {CONSTANTS} from "script/libraries/Constants.sol";

contract RaffleTest is Test {
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;
    address player = makeAddr("1");
    address player2 = makeAddr("2");

    uint256 constant STARTING_FUNDS = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    uint256 subscriptionId;
    bytes32 gasLane;
    uint32 callbackGasLimit;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        entranceFee = helperConfig.getActiveConfig().entranceFee;
        interval = helperConfig.getActiveConfig().interval;
        vrfCoordinator = helperConfig.getActiveConfig().vrfCoordinator;
        subscriptionId = helperConfig.getActiveConfig().subscriptionId;
        gasLane = helperConfig.getActiveConfig().gasLane;
        callbackGasLimit = helperConfig.getActiveConfig().callbackGasLimit;

        vm.deal(player, STARTING_FUNDS); // fund player with starting funds
        vm.deal(player2, STARTING_FUNDS); // fund player with starting funds
    }

    modifier raffleEntered() {
        // Arrange
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    /* RAFFLE */

    function testInitialisedRaffleIsOpen() external view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenFeeNotMet() external {
        vm.prank(player);
        vm.expectRevert(Raffle.Raffle__EntranceFeeNotMet.selector); // the following line is expected to revert with the specific error
        raffle.enterRaffle();
    }

    function testEnteredPlayersAreRecorded() external {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.getPlayers()[0] == payable(player));
    }

    function testEnteringRaffleEmitsEvent() external {
        vm.prank(player);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(address(player));
        raffle.enterRaffle{value: entranceFee}();
    }

    function testPlayersCantEnterWhenRaffleIsPending() external raffleEntered {
        raffle.performUpkeep("");
        // Act / Assert
        vm.prank(player2);
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    /* CHECKUPKEEP */

    function testCheckUpkeepReturnsFalseIfNoBalance() external {
        // Arrange
        vm.prank(player);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepRetrunsFalseIfRaffleNotOpen()
        external
        raffleEntered
    {
        // Arrange
        raffle.performUpkeep("");
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() external {
        // Arrange
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood()
        external
        raffleEntered
    {
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded);
    }

    /* PERFORMUPKEEP */

    function testPerformUpkeepCanOnlyRunWhenCheckUpkeepIsTrue() external {
        // Arrange
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        // Act / Assert
        // Encode the error with the expected parameters
        bytes memory encodedError = abi.encodeWithSelector(
            Raffle.Raffle__UpkeepNotNeeded.selector,
            entranceFee, // currentBalance
            1, // numPlayers
            Raffle.RaffleState.OPEN // raffleState
        );
        vm.expectRevert(encodedError);
        raffle.performUpkeep("");
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        raffle.performUpkeep("");
        // Assert
        assert(raffle.getRaffleState() == Raffle.RaffleState.PENDING);
    }

    function testPeformUpkeepEmitsEvent() external raffleEntered {
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory eventEntries = vm.getRecordedLogs();
        bytes32 requestId = eventEntries[1].topics[1];
        // Assert
        assert(uint256(requestId) > 0);
    }

    /* FULLFILLRANDOMWORDS */

    function testFullfillRandomWordsCanOnlyExecuteAfterPerformUpkeep(
        uint256 randomRequestId
    ) external {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }
}
