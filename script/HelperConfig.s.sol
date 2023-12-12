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
            wrappedAsset: 0x127e5F7dce0999f19c8eba6fc154e6c404FC7D95,
            router: 0xF694E193200268f9a4868e4Aa017A0118C9a8177,
            link: 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846,
            avaxUsdPriceFeed: 0x34C4c526902d88a3Aa98DB8a9b802603EB1E3470, //link/usd
            opEthUsdPriceFeed: 0x7898AcCC83587C3C55116c5230C17a6Cd9C71bad, //usdt/usd
            maticUsdPriceFeed: 0xB0924e98CAFC880ed81F6A4cA63FD61006D1f8A0, //matic/usd
            usdt: 0x9F6e36A08315c6890FE402799176cd7748FcB695,
            franfranSwap: 0x08B895f719c1F13754453CA1E47A017D12CD9B44
        });

        return avalancheNetworkConfig;
    }

    /// optimism config
    function getOptimismEthConfig() public pure returns (LiveNetworkConfig memory) {
        LiveNetworkConfig memory optimismNetworkConfig = LiveNetworkConfig({
            wrappedAsset: 0xf816839642Fb1c652fD36f9881D242B54A3A9535,
            router: 0xcc5a0B910D9E9504A7561934bed294c51285a78D,
            link: 0xdc2CC710e42857672E7907CF474a69B63B93089f,
            avaxUsdPriceFeed: 0x69C5297001f38cCBE30a81359da06E5256bd28B9, //link/usd
            opEthUsdPriceFeed: 0x2e2147bCd571CE816382485E59Cd145A2b7CA451, //usdt/usd
            maticUsdPriceFeed: 0x11C944427B9ebeb1417Dd44645Ad04edBF33b95e, //matic/usd
            usdt: 0xEF53020fEb7b71E4B700531894991Cc7Ca553fb4,
            franfranSwap: 0x63Ec16553806549374ca88E1D6FA3aaC57414eA6
        });

        return optimismNetworkConfig;
    }

    /// Polygon config
    function getPolygonEthConfig() public pure returns (LiveNetworkConfig memory) {
        LiveNetworkConfig memory polygonNetworkConfig = LiveNetworkConfig({
            wrappedAsset: 0x2eEDEA5e2900D08F3dD58640554DB08411F5d13F,
            router: 0x1035CabC275068e0F4b745A29CEDf38E13aF41b1,
            link: 0x326C977E6efc84E512bB9C30f76E30c160eD06FB,
            avaxUsdPriceFeed: 0x1C2252aeeD50e0c9B64bDfF2735Ee3C932F5C408, //link/usd
            opEthUsdPriceFeed: 0x92C09849638959196E976289418e5973CC96d645, //usdt/usd
            maticUsdPriceFeed: 0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada, //matic/usd
            usdt: 0xC88BDB5Dd8d18f847b85259329663AB6D3A0C367,
            franfranSwap: 0x9f6b7BCF9D9ddc16EDdCb3Da2aAFBab01B9564E1
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
