// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

import {CollectiveCoreAvalanche} from "../src/CollectiveContracts/CollectiveCoreAvalanche.sol";
import {CollectiveCoreOptimism} from "../src/CollectiveContracts/CollectiveCoreOptimism.sol";
import {CollectiveCorePolygon} from "../src/CollectiveContracts/CollectiveCorePolygon.sol";

import {MockERC20} from "../test/mocks/MockERC20.sol";

contract DeployCollectiveCore is Script {
    uint256 constant ANVIL_CHAIN_ID = 31337;

    uint64 constant AVALANCHE_CHAIN_SELECTOR = 14767482510784806043;
    uint64 constant OPTIMISM_CHAIN_SELECTOR = 2664363617261496610;
    uint64 constant POLYGON_CHAIN_SELECTOR = 12532609583862916517;

    uint256 DEFAULT_PRIVATE_KEY = vm.envUint("DEFAULT_ANVIL_PRIVATE_KEY");
    uint256 PRIVATE_KEY = vm.envUint("PRIVATE_KEY");

    /**
     * @notice deploys the collective core contracts
     * @dev if chain == anvil chain deploys three different contrats at a go, else: deploy single contract to desired active chain set
     */
    function run()
        external
        returns (address aCollectiveCore, address oCollectiveCore, address pCollectiveCore, HelperConfig config)
    {
        HelperConfig helperConfig = new HelperConfig();

        // Anvil
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

        // Avalanche
        if (block.chainid == 43113) {
            // (address[2] memory assets, address router, address link, address usdt) = helperConfig.getActiveNetworkDeploymentParams();

            // vm.startBroadcast();
            // CollectiveCoreAvalanche collectiveCoreAvalanche =
            // new CollectiveCoreAvalanche(assets, router, link, AVALANCHE_CHAIN_SELECTOR, OPTIMISM_CHAIN_SELECTOR, POLYGON_CHAIN_SELECTOR);
            // vm.stopBroadcast();

            // return (address(collectiveCoreAvalanche), address(0), address(0), helperConfig);
        }
    }

    function _deployToAnvil(HelperConfig helperConfig) internal returns (address, address, address) {
        vm.startBroadcast();
        HelperConfig.MockContracts memory mockContracts = helperConfig.getAnvilDeploymentParams();
        (address aPriceFeedMock, address oPriceFeedMock, address pPriceFeedMock) = helperConfig.anvilPriceFeedMocks();

        (address aFranFranSwap, address oFranFranSwap, address pFranFranSwap) = helperConfig.getSwapContracts();

        
        CollectiveCoreAvalanche collectiveCoreAvalanche =
        new CollectiveCoreAvalanche(mockContracts.wAVAX, mockContracts.router, mockContracts.aLink, aPriceFeedMock, oPriceFeedMock, pPriceFeedMock, mockContracts.aUsdt, aFranFranSwap);
        console.log("Deployed collective Core Avalanche: ", address(collectiveCoreAvalanche));

        
        CollectiveCoreOptimism collectiveCoreOptimism =
        new CollectiveCoreOptimism(mockContracts.wOP, mockContracts.router, mockContracts.oLink, aPriceFeedMock, oPriceFeedMock, pPriceFeedMock, mockContracts.oUsdt, oFranFranSwap);
console.log("Deployed collective Core Optimism: ", address(collectiveCoreOptimism));


        CollectiveCorePolygon collectiveCorePolygon =
        new CollectiveCorePolygon(mockContracts.wMATIC, mockContracts.router, mockContracts.pLink, aPriceFeedMock, oPriceFeedMock, pPriceFeedMock, mockContracts.pUsdt, pFranFranSwap);
        console.log("Deployed collective Core Polygon: ", address(collectiveCorePolygon));

        vm.stopBroadcast();

        return (address(collectiveCoreAvalanche), address(collectiveCoreOptimism), address(collectiveCorePolygon));
    }
}
