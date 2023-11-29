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

    // LIVE NETWORK CONFIG
    struct LiveNetworkConfig {
        address wrappedAsset;
        address router;
        address link;
        address avaxUsdPriceFeed;
        address opEthUsdPriceFeed;
        address maticUsdPriceFeed;
        address usdt;
        address franfranSwap;
    }

    // ANVIL STRUCTS
    struct NetworkConfig {
        address asset;
        address router;
        address link;
        address usdt;
        address franfranSwap;
    }

    struct AnvilNetworkConfig {
        NetworkConfig avalancheNetworkConfig;
        NetworkConfig optimismNetworkConfig;
        NetworkConfig polygonNetworkConfig;
    }

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

    struct SwapContracts {
        address aFranFranSwap;
        address oFranFranSwap;
        address pFranFranSwap;
    }

    struct PriceFeedMocks {
        address aPriceFeedMock;
        address oPriceFeedMock;
        address pPriceFeedMock;
    }

    // active anvil config
    AnvilNetworkConfig public activeAnvilNetworkConfig;
    // anvil price feed mocks
    PriceFeedMocks public anvilPriceFeedMocks;

    /// The active live network config
    LiveNetworkConfig public liveNetworkConfig;

    constructor() {
        if (block.chainid == 31337) {
            activeAnvilNetworkConfig = getOrCreateAnvilEthConfig();
        }
        if (block.chainid == 43113) {
            liveNetworkConfig = getAvalancheEthConfig();
        }
        if (block.chainid == 420) {
            liveNetworkConfig = getOptimismEthConfig();
        }
        if (block.chainid == 80001) {
            liveNetworkConfig = getPolygonEthConfig();
        }
    }

    //////////////////////////////////////
    /////// LIVE NETWORK CONFIGS /////////
    /////////////////////////////////////

    /// avalanche config
    function getAvalancheEthConfig() public pure returns (LiveNetworkConfig memory) {
        LiveNetworkConfig memory avalancheNetworkConfig = LiveNetworkConfig({
            wrappedAsset: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            router: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            link: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            avaxUsdPriceFeed: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            opEthUsdPriceFeed: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            maticUsdPriceFeed: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            usdt: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            franfranSwap: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416
        });

        return avalancheNetworkConfig;
    }

    /// optimism config
    function getOptimismEthConfig() public pure returns (LiveNetworkConfig memory) {
        LiveNetworkConfig memory optimismNetworkConfig = LiveNetworkConfig({
            wrappedAsset: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            router: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            link: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            avaxUsdPriceFeed: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            opEthUsdPriceFeed: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            maticUsdPriceFeed: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            usdt: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            franfranSwap: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416
        });

        return optimismNetworkConfig;
    }

    /// Polygon config
    function getPolygonEthConfig() public pure returns (LiveNetworkConfig memory) {
        LiveNetworkConfig memory polygonNetworkConfig = LiveNetworkConfig({
            wrappedAsset: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            router: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            link: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            avaxUsdPriceFeed: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            opEthUsdPriceFeed: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            maticUsdPriceFeed: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            usdt: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416,
            franfranSwap: 0x29ab7f54e024CB43fe2B2CA792691791c71b3416
        });

        return polygonNetworkConfig;
    }

    /////////////////////////////////
    //// ANVIL RELATED FUNCTIONS ////
    /////////////////////////////////

    /// used to get the deployment parameters for anvil
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

    /// used to set the deployment parameters for anvil
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

    /// returns the swap mock contracts
    function getSwapContracts() public view returns (address, address, address) {
        return (
            activeAnvilNetworkConfig.avalancheNetworkConfig.franfranSwap,
            activeAnvilNetworkConfig.optimismNetworkConfig.franfranSwap,
            activeAnvilNetworkConfig.polygonNetworkConfig.franfranSwap
        );
    }

    /////////////////////////////////////
    //////// PRIVATE DEPLOY MOCKS ////////
    /////////////////////////////////////

    /// deploys neccessary mocks
    function _deployMocks() private returns (MockContracts memory) {
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

    /// deploys the mock swap contracts
    function _deploySwapContractsAndPriceFeedMocks(MockContracts memory mockContracts)
        private
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
}
