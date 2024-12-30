// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    HelperConfig helperConfig;

    constructor() {
        helperConfig = new HelperConfig();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        if (networkConfig.subscriptionId == 0) {
            // create subscription
            CreateSubscription createSubscription = new CreateSubscription();
            (networkConfig.subscriptionId, networkConfig.vrfCoordinator) =
                createSubscription.createSubscription(networkConfig.account, networkConfig.vrfCoordinator);
        }
        // fund it!
        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(
            networkConfig.account,
            networkConfig.vrfCoordinator,
            networkConfig.subscriptionId,
            networkConfig.linkTokenAddress
        );

        vm.startBroadcast(networkConfig.account);

        Raffle raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.gasLane,
            networkConfig.subscriptionId,
            networkConfig.gasLimit
        );

        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        // don't need to broadcast ...
        addConsumer.addConsumer(
            networkConfig.account, address(raffle), networkConfig.vrfCoordinator, networkConfig.subscriptionId
        );

        return (raffle, helperConfig);
    }

    function run(uint256 subscriptionId) external returns (Raffle, HelperConfig) {
        return deployContract();
    }
}
