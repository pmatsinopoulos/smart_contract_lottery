// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Script, console} from "forge-std/Script.sol";
import {CodeConstants} from "./CodeConstants.s.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    HelperConfig helperConfig;

    constructor() {
        helperConfig = new HelperConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

        address vrfCoordinator = networkConfig.vrfCoordinator;
        return createSubscription(networkConfig.account, vrfCoordinator);
    }

    function createSubscription(address account, address vrfCoordinator) public returns (uint256, address) {
        console.log("Creating subscription on chain Id: ", block.chainid);

        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        return (subId, vrfCoordinator);
    }

    function run() external {}
}

contract FundSubscription is Script {
    uint256 public constant FUND_AMOUNT = 1_000_000_000 ether;

    HelperConfig helperConfig;

    constructor() {
        helperConfig = new HelperConfig();
    }

    function fundSubscriptionUsingConfig() public {
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().linkTokenAddress;

        fundSubscription(helperConfig.getConfig().account, vrfCoordinator, subscriptionId, linkToken);
    }

    function fundSubscription(address account, address vrfCoordinator, uint256 subscriptionId, address linkToken)
        public
    {
        console.log("Funding subscription", subscriptionId);

        if (block.chainid == helperConfig.LOCAL_CHAIN_ID()) {
            vm.startBroadcast(account);
            console.log("Funding subscription with FUND_AMOUNT", FUND_AMOUNT);

            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, 10 ether, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentlyDeployed) internal {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        addConsumer(helperConfig.getConfig().account, mostRecentlyDeployed, vrfCoordinator, subId);
    }

    function addConsumer(address account, address contractToAddToVrf, address vrfCoordinator, uint256 subId) public {
        console.log("Adding consumer to vrfCoordinator: ", vrfCoordinator);
        console.log("To vrfCoordinator: ", vrfCoordinator);
        console.log("On Chain ID: ", block.chainid);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
