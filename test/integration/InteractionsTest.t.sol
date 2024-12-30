// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {HelperConfig} from "../../scripts/HelperConfig.s.sol";
import {AddConsumer} from "../../scripts/Interactions.s.sol";

import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Test, Vm, console} from "forge-std/Test.sol";

contract AddConsumerTest is Test {
    AddConsumer addConsumer;

    function setUp() public {
        addConsumer = new AddConsumer();
    }

    //----------------------------//
    //                            //
    //       addConsumer()        //
    //                            //
    //----------------------------//

    function test_addConsumer_addsGivenAddressAsSubscriptionConsumer() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

        address account = networkConfig.account;
        address consumerToAdd = makeAddr("Raffle");
        address vrfCoordinator = networkConfig.vrfCoordinator;
        uint256 subscriptionId = networkConfig.subscriptionId;

        // fire
        vm.recordLogs();

        addConsumer.addConsumer(account, consumerToAdd, vrfCoordinator, subscriptionId);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 1);
        assertEq(entries[0].topics[0], keccak256("SubscriptionConsumerAdded(uint256,address)"));
        assertEq(uint256(entries[0].topics[1]), subscriptionId);
        assertEq(address(uint160(uint256(bytes32(entries[0].data)))), consumerToAdd);

        // check that the consumer configuration for this consumer is +active+
        assertTrue(VRFCoordinatorV2_5Mock(vrfCoordinator).consumerIsAdded(subscriptionId, consumerToAdd));
        (uint96 balance, uint96 nativeBalance, uint64 reqCount, address subOwner, address[] memory consumers) =
            VRFCoordinatorV2_5Mock(vrfCoordinator).getSubscription(subscriptionId);

        assertEq(consumers.length, 1);
        assertEq(consumers[0], consumerToAdd);
    }
}
