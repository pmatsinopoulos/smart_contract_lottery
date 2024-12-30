// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {DeployRaffle} from "../../scripts/DeployRaffle.s.sol";

import {HelperConfig} from "../../scripts/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, Vm, console} from "forge-std/Test.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    address raffleOwner;
    HelperConfig public helperConfig;
    HelperConfig.NetworkConfig public networkConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    modifier skipFork() {
        if (block.chainid != helperConfig.LOCAL_CHAIN_ID()) {
            return;
        }
        _;
    }

    function setUp() external {
        console.log("setup: msg.sender", msg.sender);
        console.log("setup: address(this)", address(this));

        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        raffleOwner = raffle.owner();

        assert(raffleOwner == helperConfig.getConfig().account);
        networkConfig = helperConfig.getConfig();
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    //----------------------------//
    //                            //
    //       enterRaffle()        //
    //                            //
    //----------------------------//

    function test_enterRaffle_ifValueIsLessThanEntranceFee_itReverts() public {
        uint256 value = networkConfig.entranceFee - 1;

        // fire
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle{value: value}();
    }

    function test_enterRaffle_ifRaffleIsNotOpen_itReverts() public {
        uint256 value = networkConfig.entranceFee;
        vm.prank(raffleOwner);
        raffle.setRaffleState(Raffle.RaffleState.CALCULATING);

        // fire/assert
        vm.expectRevert(Raffle.Raffle__RaffleIsNotOpen.selector);

        raffle.enterRaffle{value: value}();
    }

    function test_enterRaffle_callerIsAddedToThePlayers() public {
        uint256 value = networkConfig.entranceFee;

        // fire
        hoax(PLAYER, value);
        raffle.enterRaffle{value: value}();

        assertEq(raffle.getPlayerByAddress(PLAYER), true);
    }

    function test_enterRaffle_isEmittingEvent_RaffleEntered() public {
        uint256 value = networkConfig.entranceFee;

        // fire
        hoax(PLAYER, value);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle.RaffleEntered(PLAYER);

        raffle.enterRaffle{value: value}();
    }

    //----------------------------//
    //                            //
    //       checkUpKeep()        //
    //                            //
    //----------------------------//

    function test_checkUpkeep_whenTimeHasNotPassed_itReturnsFalse() public {
        vm.warp(raffle.getLastTimeStamp() + networkConfig.interval - 1);
        uint256 value = networkConfig.entranceFee;
        hoax(PLAYER, value);
        raffle.enterRaffle{value: value}();

        // fire
        (bool result,) = raffle.checkUpkeep("");

        assertEq(result, false);
    }

    function test_checkUpkeep_returnsFalseIfItHasNotBalance() public {
        // we need to make sure that +timeHasPassed+ is true
        vm.warp(raffle.getLastTimeStamp() + networkConfig.interval + 1);
        // we need to make sure that the Raffle +isOpen+
        vm.prank(raffleOwner);
        raffle.setRaffleState(Raffle.RaffleState.OPEN);
        // we need to make sure that it has players
        uint256 value = networkConfig.entranceFee;
        hoax(PLAYER, value);
        raffle.enterRaffle{value: value}();
        // withdraw funds to make sure the contract has zero balance
        vm.prank(raffleOwner);
        raffle.withdrawAll();

        // Check that we have set up the condition of the test as appropriate
        assert(address(raffle).balance == 0); // Raffle should not have balance for this test to run
        assert(raffle.numberOfPlayers() > 0); // Raffle should have players for this test to run
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN); // Raffle should be open for this test to run
        assert(block.timestamp - raffle.getLastTimeStamp() >= networkConfig.interval); // We should have pasted the interval for this test to run

        // fire
        (bool result,) = raffle.checkUpkeep("");

        assertEq(result, false);
    }

    function test_checkUpkeep_returnsFalseIfRaffleIsNotOpen() public {
        // we need to make sure that +timeHasPassed+ is true
        vm.warp(raffle.getLastTimeStamp() + networkConfig.interval + 1);
        // we need to make sure that it has players
        vm.prank(raffleOwner);
        raffle.setRaffleState(Raffle.RaffleState.OPEN);
        uint256 value = networkConfig.entranceFee;
        hoax(PLAYER, value);
        raffle.enterRaffle{value: value}();
        // we need to make sure that the Raffle is not open
        vm.prank(raffleOwner);
        raffle.setRaffleState(Raffle.RaffleState.CALCULATING);
        // withdraw funds to make sure the contract has balance

        // Check that we have set up the condition of the test as appropriate
        assert(address(raffle).balance > 0); // Raffle should not have balance for this test to run
        assert(raffle.numberOfPlayers() > 0); // Raffle should have players for this test to run
        assert(raffle.getRaffleState() != Raffle.RaffleState.OPEN); // Raffle should be open for this test to run
        assert(block.timestamp - raffle.getLastTimeStamp() >= networkConfig.interval); // We should have pasted the interval for this test to run

        // fire
        (bool result,) = raffle.checkUpkeep("");

        assertEq(result, false);
    }

    //----------------------------//
    //                            //
    //      performUpkeep()       //
    //                            //
    //----------------------------//

    function test_performUpkeep_whenUpkeepIsNotNeeded_itReverts() public {
        // setup
        // we need to make sure that the +this.checkUpkeep("");+ will return +false+.
        // This can happen if the balance of the +raffle+ contract is 0, for example.

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);

        uint256 balance = address(raffle).balance;

        // fire
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, balance, 0, Raffle.RaffleState.OPEN)
        );
        raffle.performUpkeep("");
    }

    function test_performUpkeep_whenUpkeepIsNeeded_itWorks() public {
        vm.prank(raffleOwner);
        raffle.setRaffleState(Raffle.RaffleState.OPEN);

        uint256 value = networkConfig.entranceFee;
        hoax(PLAYER, value);
        raffle.enterRaffle{value: value}();

        vm.warp(raffle.getLastTimeStamp() + networkConfig.interval + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(upkeepNeeded);

        // fire
        // vm.expectEmit(false, false, false, false, address(raffle));
        // emit Raffle.RequestedRaffleWinner({requestId: 1});

        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 2);
        assertEq(entries[1].topics[0], keccak256("RequestedRaffleWinner(uint256)"));
        assert(entries[1].topics[1] != 0); // request id
        assertEq(entries[1].emitter, address(raffle));
    }

    //----------------------------//
    //                            //
    //  rawFulfillRandomWords()   //
    //                            //
    //----------------------------//

    function test_fulfillRandomWords_ifNotCalledByTheVrfCoordinator_itReverts() public {
        uint256[] memory randomWords = new uint256[](2);
        randomWords[0] = 1;
        randomWords[1] = 2;

        // fire
        vm.expectRevert(
            abi.encodeWithSelector(
                VRFConsumerBaseV2Plus.OnlyCoordinatorCanFulfill.selector,
                address(this),
                address(networkConfig.vrfCoordinator)
            )
        );
        // the +msg.sender+ is the contract RaffleTest address inside the
        // call.
        raffle.rawFulfillRandomWords(1, randomWords);
    }

    function test_fulfillRandomWords_ifNotCalculating_itReverts() public {
        uint256[] memory randomWords = new uint256[](2);
        randomWords[0] = 1;
        randomWords[1] = 2;

        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);

        // fire
        vm.prank(networkConfig.vrfCoordinator);
        vm.expectRevert(Raffle.Raffle__RaffleNotInCalculatingState.selector);
        raffle.rawFulfillRandomWords(1, randomWords);
    }

    function test_fulfillRandomWords_whenCalledBeforePerformUpkeep_itReverts(uint256 randomRequestId) public skipFork {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(networkConfig.vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function test_fulfillRandomWords_PicksAWinnerResetsAndSendsMoney() public skipFork {
        hoax(PLAYER, 1 ether);
        raffle.enterRaffle{value: networkConfig.entranceFee}();

        uint256 additionalEntrants = 3; // for people total entering this raffle
        uint256 startingIndex = 1;
        address[4] memory players;
        uint256[4] memory playersBalances;
        players[0] = PLAYER;
        playersBalances[0] = PLAYER.balance;
        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i));
            players[i] = newPlayer;
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: networkConfig.entranceFee}();
            playersBalances[i] = newPlayer.balance;
        }

        uint256 startingTimestamp = raffle.getLastTimeStamp();

        vm.warp(startingTimestamp + networkConfig.interval + 1);
        vm.roll(block.number + 1);

        uint256 raffleBalanceBefore = address(raffle).balance;

        console.log("Balance before: ", raffleBalanceBefore);

        // fire
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(networkConfig.vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        entries = vm.getRecordedLogs();
        address winnerAddress = address(uint160(uint256(entries[0].topics[1])));

        assertEq(address(raffle).balance, 0);
        uint256 winnerAddressBalanceBefore = 0;
        for (uint256 i = 0; i < 4; i++) {
            if (winnerAddress == players[i]) {
                winnerAddressBalanceBefore = playersBalances[i];
                break;
            }
        }
        assertEq(
            winnerAddress.balance, winnerAddressBalanceBefore + (additionalEntrants + 1) * networkConfig.entranceFee
        );
        assertEq(winnerAddress.balance, winnerAddressBalanceBefore + raffleBalanceBefore);
        assertEq(raffle.getRecentWinner(), winnerAddress);
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assertEq(raffle.numberOfPlayers(), 0);
        assertEq(raffle.getLastTimeStamp(), block.timestamp);
    }
}
