// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    address public player = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;

        vm.deal(player, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializaesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    // ENTER RAFFLE

    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(player);

        // Act - Assert
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecoredsPlayersWhenTheyEnter() public {
        // Arrange
        vm.prank(player);

        // Act
        raffle.enterRaffle{value: entranceFee}();

        // Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == player);
    }

    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        vm.prank(player);
        // Act
        vm.expectEmit(true, false, false, false, address(raffle)); // Expectativa del evento que se va a emitir
        emit RaffleEntered(player); // Tipo de evento a esperar - plantilla
        // Assert
        raffle.enterRaffle{value: entranceFee}(); // Aqui se emite el evento
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act - Assert
        vm.expectRevert();
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
    }
}
