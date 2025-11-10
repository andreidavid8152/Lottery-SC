// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle contract
 * @author Andrei Flores
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 playersLength,
        uint256 raffleState
    );

    /* Type Declarations */
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }

    /* State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable I_ENTRANCE_FEE;
    // @dev The duration of the lottery in seconds
    uint256 private immutable I_INTERVAL;
    bytes32 private immutable I_KEY_HASH;
    uint256 private immutable I_SUBSCRIPTION_ID;
    uint32 private immutable I_CALLBACKGASLIMIT;
    address payable[] private sPlayers;
    uint256 private sLastTimeStamp;
    address private sRecentWinner;
    RaffleState private sRaffleState;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        I_ENTRANCE_FEE = entranceFee;
        I_INTERVAL = interval;
        I_KEY_HASH = gasLane;
        I_SUBSCRIPTION_ID = subscriptionId;
        I_CALLBACKGASLIMIT = callbackGasLimit;

        sLastTimeStamp = block.timestamp;
        sRaffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        //require(msg.value >= I_ENTRANCE_FEE, "Not enough ETH sent!");
        if (msg.value < I_ENTRANCE_FEE) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        if (sRaffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        sPlayers.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    // When should the winner be picked?
    /**
     * @dev This is the function that the Chainlink nodes will call to see
     * if the lottery is ready to have a winner picked.
     * The following should be true in order for upkeepNeeded to be true:
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is open
     * 3. The contract has ETH (has players)
     * 4. Implicitly, your subscription has LINK.
     * @param - ignored
     * @return upkeepNeeded - true if it's time to restart the lottery
     * @return - ignored
     */
    function checkUpKeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = ((block.timestamp - sLastTimeStamp) >= I_INTERVAL);
        bool isOpen = sRaffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = sPlayers.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    // 1. Get a random number
    // 2. Use random number to pick a player
    // 3. Be automatically called
    function performUpkeep(bytes calldata /* performData */) external {
        // check to see if enough time has passed
        (bool upkeepNeeded, ) = checkUpKeep("");

        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                sPlayers.length,
                uint256(sRaffleState)
            );
        }

        sRaffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: I_KEY_HASH,
                subId: I_SUBSCRIPTION_ID,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: I_CALLBACKGASLIMIT,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        s_vrfCoordinator.requestRandomWords(request);
    }

    // Callback called after random number is generated
    // Design Pattern
    // CEI: Checks, Effects, Interactions
    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal override {
        // Checks (conditionals)

        // Effects (Internal Contract State - Logic)
        uint256 indexOfWinner = randomWords[0] % sPlayers.length;
        address payable recentWinner = sPlayers[indexOfWinner];
        sRecentWinner = recentWinner;

        sRaffleState = RaffleState.OPEN;
        sPlayers = new address payable[](0);
        sLastTimeStamp = block.timestamp;
        emit WinnerPicked(recentWinner);

        // Interactions (External Contract Interactions or tranfers of ether)
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /**
     * Getter Functions
     */
    function getEntranceFee() external view returns (uint256) {
        return I_ENTRANCE_FEE;
    }

    function getRaffleState() external view returns (RaffleState) {
        return sRaffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return sPlayers[indexOfPlayer];
    }
}
