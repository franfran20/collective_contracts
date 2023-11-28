// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";

import {MockRouterClient} from "../test/mocks/MockRouterClient.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {MockLinkToken} from "@chainlink/contracts-ccip/src/v0.8/mocks/MockLinkToken.sol";
import {FranFranSwap} from "../test/mocks/FranFranSwap.sol";
import {MockV3Aggregator} from "@chainlink/contracts-ccip/src/v0.8/tests/MockV3Aggregator.sol";

contract HelperConfig is Script {
    uint8 constant DECIMALS = 8;
    int256 constant AVAX_INITIAL_ANSWER = 10e8;
    int256 constant OP_INITIAL_ANSWER = 15e8;
    int256 constant MATIC_INITIAL_ANSWER = 5e8;

    /**
     * @notice network config for chains other than anvil
     */

    struct NetworkConfig {
        address asset;
        address router;
        address link;
        address usdt;
        address franfranSwap;
    }

    /**
     * @notice network config for anvil chain for cross chain testing
     */
    struct AnvilNetworkConfig {
        NetworkConfig avalancheNetworkConfig;
        NetworkConfig optimismNetworkConfig;
        NetworkConfig polygonNetworkConfig;
    }

    /**
     * @notice all mock contracts required for cross chgain testiing
     */
    struct MockContracts {
        address wAVAX;
        address wOP;
        address wMATIC;
        address router;
        address aLink;
        address oLink;
        address pLink;
        address aUsdt;
        address oUsdt;
        address pUsdt;
    }

    /**
     * @notice all the mock swap contract addresses
     */
    struct SwapContracts {
        address aFranFranSwap;
        address oFranFranSwap;
        address pFranFranSwap;
    }

    /**
     * @notice Aggregator V3 Mocks
     */
    struct PriceFeedMocks {
        address aPriceFeedMock;
        address oPriceFeedMock;
        address pPriceFeedMock;
    }

    /**
     * @notice active network config and anvil network config set on deployment
     */
    NetworkConfig public activeNetworkConfig;
    AnvilNetworkConfig public activeAnvilNetworkConfig;
    PriceFeedMocks public anvilPriceFeedMocks;

    constructor() {
        if (block.chainid == 31337) {
            activeAnvilNetworkConfig = getOrCreateAnvilEthConfig();
        }
        if (block.chainid == 43113) {
            activeNetworkConfig = getAvalancheEthConfig();
        }
    }

    /**
     * @notice a different struct config when testing contracts locally
     */
    function getOrCreateAnvilEthConfig() public returns (AnvilNetworkConfig memory) {
        MockContracts memory mockContracts = _deployMocks();
        SwapContracts memory swapContracts = _deploySwapContractsAndPriceFeedMocks(mockContracts);

        AnvilNetworkConfig memory anvilNetworkConfig = AnvilNetworkConfig(
            NetworkConfig(
                mockContracts.wAVAX,
                mockContracts.router,
                mockContracts.aLink,
                mockContracts.aUsdt,
                swapContracts.aFranFranSwap
            ),
            NetworkConfig(
                mockContracts.wOP,
                mockContracts.router,
                mockContracts.oLink,
                mockContracts.oUsdt,
                swapContracts.oFranFranSwap
            ),
            NetworkConfig(
                mockContracts.wMATIC,
                mockContracts.router,
                mockContracts.pLink,
                mockContracts.pUsdt,
                swapContracts.pFranFranSwap
            )
        );

        return anvilNetworkConfig;
    }

    /////// GETTER FUNCTIONS //////
    /**
     * @notice avalanche testnet config
     */
    function getAvalancheEthConfig() public returns (NetworkConfig memory) {
        vm.startBroadcast();
        MockERC20 wAvax = new MockERC20("wrapped AVAX", "wAVAX");

        NetworkConfig memory avalancheNetworkConfig = NetworkConfig({
            asset: address(wAvax),
            router: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            link: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            usdt: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            franfranSwap: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416
        });
        vm.stopBroadcast();
        return avalancheNetworkConfig;
    }

    /**
     * @notice get active network deployment params for chains aside anvil
     */
    function getActiveNetworkDeploymentParams() public view returns (address, address, address) {
        return (activeNetworkConfig.asset, activeNetworkConfig.router, activeNetworkConfig.link);
    }

    function getSwapContracts() public view returns (address, address, address) {
        return (
            activeAnvilNetworkConfig.avalancheNetworkConfig.franfranSwap,
            activeAnvilNetworkConfig.optimismNetworkConfig.franfranSwap,
            activeAnvilNetworkConfig.polygonNetworkConfig.franfranSwap
        );
    }

    /**
     * @notice get deployment params for anvil chain
     */
    function getAnvilDeploymentParams() public view returns (MockContracts memory) {
        address avalancheAsset = activeAnvilNetworkConfig.avalancheNetworkConfig.asset;
        address optimismAsset = activeAnvilNetworkConfig.optimismNetworkConfig.asset;
        address polygonAsset = activeAnvilNetworkConfig.polygonNetworkConfig.asset;

        address router = activeAnvilNetworkConfig.avalancheNetworkConfig.router;

        address aLink = activeAnvilNetworkConfig.avalancheNetworkConfig.link;
        address oLink = activeAnvilNetworkConfig.optimismNetworkConfig.link;
        address pLink = activeAnvilNetworkConfig.polygonNetworkConfig.link;

        address aUsdt = activeAnvilNetworkConfig.avalancheNetworkConfig.usdt;
        address oUsdt = activeAnvilNetworkConfig.optimismNetworkConfig.usdt;
        address pUsdt = activeAnvilNetworkConfig.polygonNetworkConfig.usdt;

        return
            MockContracts(avalancheAsset, optimismAsset, polygonAsset, router, aLink, oLink, pLink, aUsdt, oUsdt, pUsdt);
    }

    ///// INTERNAL FUNCTIONS ////

    /**
     * @notice deploys the mock swap contracts
     */
    function _deploySwapContractsAndPriceFeedMocks(MockContracts memory mockContracts)
        internal
        returns (SwapContracts memory)
    {
        vm.startBroadcast();

        console.log("Deploying Aggregator V3 Mocks...");
        MockV3Aggregator aPricFeedMock = new MockV3Aggregator(DECIMALS, AVAX_INITIAL_ANSWER);
        MockV3Aggregator oPricFeedMock = new MockV3Aggregator(DECIMALS, OP_INITIAL_ANSWER);
        MockV3Aggregator pPricFeedMock = new MockV3Aggregator(DECIMALS, MATIC_INITIAL_ANSWER);

        anvilPriceFeedMocks = PriceFeedMocks(address(aPricFeedMock), address(oPricFeedMock), address(pPricFeedMock));

        console.log("Deploying franfran swap contracts...");
        FranFranSwap aFranFranSwap = new FranFranSwap(address(aPricFeedMock), mockContracts.aUsdt, mockContracts.wAVAX);
        FranFranSwap oFranFranSwap = new FranFranSwap(address(oPricFeedMock), mockContracts.oUsdt, mockContracts.wOP);
        FranFranSwap pFranFranSwap = new FranFranSwap(address(pPricFeedMock), mockContracts.pUsdt, mockContracts.wMATIC);

        vm.stopBroadcast();

        return (SwapContracts(address(aFranFranSwap), address(oFranFranSwap), address(pFranFranSwap)));
    }

    /**
     * @notice deploy mocks for each contract when testing on anvil
     * @dev we have a single router contract that is used for all the contrcats locally thats because while testing our cross chian functionality locally we act like the diffrenet contracts deployed are on differetn chains.
     * This allows me to be able to test on a local enviroment and debug things faster rather than assuming or waiting for a 5-10 min cross chain transaction to approve my guesses.
     */
    function _deployMocks() internal returns (MockContracts memory) {
        vm.startBroadcast();

        // deploy assets for each contract chain
        console.log("Deploying mock wrapped asset and clt tokens for mock chains....");
        MockERC20 wAvax = new MockERC20("wrapped AVAX", "wAVAX");

        MockERC20 wOP = new MockERC20("wrapped OPTIMISM ETH", "wOP");

        MockERC20 wMATIC = new MockERC20("wrapped MATIC", "wMATIC");

        // deploy mock router => they'll all share the same router contract
        console.log("Deploying Mock CCIP Router Contract..");
        MockRouterClient mockRouterClient = new MockRouterClient();

        // deploy link tokens
        console.log("Deploying Link Tokens For Mock Chains....");
        MockERC20 aLinkToken = new MockERC20("Link Token Avalanche", "LINK");
        MockERC20 oLinkToken = new MockERC20("Link Token OPTIMISM", "LINK");
        MockERC20 pLinkToken = new MockERC20("Link Token POLYGON", "LINK");

        // deploy link tokens
        console.log("Deploying Usdt Tokens For Mock Chains....");
        MockERC20 aUsdt = new MockERC20("Link Token Avalanche", "LINK");
        MockERC20 oUsdt = new MockERC20("Link Token OPTIMISM", "LINK");
        MockERC20 pUsdt = new MockERC20("Link Token POLYGON", "LINK");

        MockContracts memory mockContracts = MockContracts(
            address(wAvax),
            address(wOP),
            address(wMATIC),
            address(mockRouterClient),
            address(aLinkToken),
            address(oLinkToken),
            address(pLinkToken),
            address(aUsdt),
            address(oUsdt),
            address(pUsdt)
        );

        vm.stopBroadcast();

        return mockContracts;
    }
}
