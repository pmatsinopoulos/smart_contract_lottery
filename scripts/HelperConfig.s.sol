// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {CommonBase} from "@forge-std/Base.sol";
import {CodeConstants} from "./CodeConstants.s.sol";
import {FundSubscription} from "./Interactions.s.sol";

contract HelperConfig is Script, CodeConstants {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 gasLimit;
        address linkTokenAddress;
        address account;
    }

    NetworkConfig public localNetworkConfig;

    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        networkConfigs[LOCAL_CHAIN_ID] = getOrCreateAnvilEthConfig();
    }

    function getConfigByChainId(uint256 chainId) public view returns (NetworkConfig memory) {
        return networkConfigs[chainId];
    }

    function getConfig() external view returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30, // seconds
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 18098975258608409425172919228342004887500723173699093824012430847764110519476,
            gasLimit: 500_000, // 500K gas
            linkTokenAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0x324e9E13dd19528D0F390201923d17c4B7E94462
        });
    }

    function getOrCreateAnvilEthConfig() internal returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        // Deploy mocks and such
        vm.startBroadcast();

        VRFCoordinatorV2_5Mock vrfCoordinatorV2 =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);

        LinkToken linkToken = new LinkToken();

        uint256 subscriptionId = vrfCoordinatorV2.createSubscription();

        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30, // seconds
            vrfCoordinator: address(vrfCoordinatorV2),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: subscriptionId,
            gasLimit: 500_000, // 500K gas
            linkTokenAddress: address(linkToken),
            account: CommonBase.DEFAULT_SENDER
        });

        return localNetworkConfig;
    }
}
