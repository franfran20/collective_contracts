// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

import {CollectiveCoreAvalanche} from "../src/CollectiveContracts/CollectiveCoreAvalanche.sol";
import {CollectiveCoreOptimism} from "../src/CollectiveContracts/CollectiveCoreOptimism.sol";
import {CollectiveCorePolygon} from "../src/CollectiveContracts/CollectiveCorePolygon.sol";

contract DeployCollectiveCore is Script {
    uint256 constant ANVIL_CHAIN_ID = 31337;
    uint256 constant AVALANCHE_TESTNET_CHAIN_ID = 43113;
    uint256 constant OPTIMSIM_TESTNET_CHAIN_ID = 420;
    uint256 constant POLYGON_POS_TESTNET_CHAIN_ID = 80001;

    uint256 DEFAULT_PRIVATE_KEY = vm.envUint("DEFAULT_ANVIL_PRIVATE_KEY");
    uint256 PRIVATE_KEY = vm.envUint("PRIVATE_KEY");

    function run()
        external
        returns (address aCollectiveCore, address oCollectiveCore, address pCollectiveCore, HelperConfig config)
    {
        HelperConfig helperConfig = new HelperConfig();
        (
            address wrappedAsset,
            address router,
            address link,
            address avaxUsdPriceFeed,
            address opEthUsdPriceFeed,
            address maticUsdPriceFeed,
            address usdt,
            address franfranSwap
        ) = helperConfig.liveNetworkConfig();

        if (block.chainid == ANVIL_CHAIN_ID) {
            (address collectiveCoreAvalanche, address collectiveCoreOptimism, address collectiveCorePolygon) =
                _deployToAnvil(helperConfig);

            return (
                address(collectiveCoreAvalanche),
                address(collectiveCoreOptimism),
                address(collectiveCorePolygon),
                helperConfig
            );
        }

        if (block.chainid == AVALANCHE_TESTNET_CHAIN_ID) {
            vm.startBroadcast(PRIVATE_KEY);
            CollectiveCoreAvalanche collectiveCoreAvalanche =
            new CollectiveCoreAvalanche(wrappedAsset, router, link, avaxUsdPriceFeed, opEthUsdPriceFeed, maticUsdPriceFeed, usdt, franfranSwap);
            vm.stopBroadcast();

            return (address(collectiveCoreAvalanche), address(0), address(0), helperConfig);
        }

        if (block.chainid == OPTIMSIM_TESTNET_CHAIN_ID) {
            vm.startBroadcast(PRIVATE_KEY);
            CollectiveCoreOptimism collectiveCoreOptimism =
            new CollectiveCoreOptimism(wrappedAsset, router, link, avaxUsdPriceFeed, opEthUsdPriceFeed, maticUsdPriceFeed, usdt, franfranSwap);
            vm.stopBroadcast();

            return (address(collectiveCoreOptimism), address(0), address(0), helperConfig);
        }

        if (block.chainid == POLYGON_POS_TESTNET_CHAIN_ID) {
            vm.startBroadcast(PRIVATE_KEY);
            CollectiveCorePolygon collectiveCorePolygon =
            new CollectiveCorePolygon(wrappedAsset, router, link, avaxUsdPriceFeed, opEthUsdPriceFeed, maticUsdPriceFeed, usdt, franfranSwap);
            vm.stopBroadcast();

            return (address(collectiveCorePolygon), address(0), address(0), helperConfig);
        }
    }

    // deploy to anvil
    function _deployToAnvil(HelperConfig helperConfig) internal returns (address, address, address) {
        vm.startBroadcast(DEFAULT_PRIVATE_KEY);

        HelperConfig.MockContracts memory mockContracts = helperConfig.getAnvilDeploymentParams();

        (address aPriceFeedMock, address oPriceFeedMock, address pPriceFeedMock) = helperConfig.anvilPriceFeedMocks();
        (address aFranFranSwap, address oFranFranSwap, address pFranFranSwap) = helperConfig.getSwapContracts();

        CollectiveCoreAvalanche collectiveCoreAvalanche =
        new CollectiveCoreAvalanche(mockContracts.wAVAX, mockContracts.router, mockContracts.aLink, aPriceFeedMock, oPriceFeedMock, pPriceFeedMock, mockContracts.aUsdt, aFranFranSwap);
        console.log("Deployed Collective Core Avalanche: ", address(collectiveCoreAvalanche));

        CollectiveCoreOptimism collectiveCoreOptimism =
        new CollectiveCoreOptimism(mockContracts.wOP, mockContracts.router, mockContracts.oLink, aPriceFeedMock, oPriceFeedMock, pPriceFeedMock, mockContracts.oUsdt, oFranFranSwap);
        console.log("Deployed Collective Core Optimism: ", address(collectiveCoreOptimism));

        CollectiveCorePolygon collectiveCorePolygon =
        new CollectiveCorePolygon(mockContracts.wMATIC, mockContracts.router, mockContracts.pLink, aPriceFeedMock, oPriceFeedMock, pPriceFeedMock, mockContracts.pUsdt, pFranFranSwap);
        console.log("Deployed Collective Core Polygon: ", address(collectiveCorePolygon));

        vm.stopBroadcast();

        return (address(collectiveCoreAvalanche), address(collectiveCoreOptimism), address(collectiveCorePolygon));
    }
}
