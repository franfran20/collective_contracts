// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {ICollectiveCore} from "../../src/interfaces/ICollectiveCore.sol";
import {CollectiveCoreAvalanche} from "../../src/CollectiveContracts/CollectiveCoreAvalanche.sol";
import {CollectiveCoreOptimism} from "../../src/CollectiveContracts/CollectiveCoreOptimism.sol";
import {CollectiveCorePolygon} from "../../src/CollectiveContracts/CollectiveCorePolygon.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {LinkTokenInterface} from "@chainlink/contracts-ccip/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

contract GetAllRecentlyDeployed is Script {
    function run() external {
        address collectiveCoreAvalancheAddress =
            DevOpsTools.get_most_recent_deployment("CollectiveCoreAvalanche", block.chainid);
        console.log("Chain: AVALANCHE");

        getRecentlyDeployedAddresses();
    }

    function getRecentlyDeployedAddresses() public view returns (address, address, address) {
        // contract addresses
        address collectiveCoreAvalanche =
            DevOpsTools.get_most_recent_deployment("CollectiveCoreAvalanche", block.chainid);
        address collectiveCoreOptimism = DevOpsTools.get_most_recent_deployment("CollectiveCoreOptimism", block.chainid);

        address collectiveCorePolygon = DevOpsTools.get_most_recent_deployment("CollectiveCorePolygon", block.chainid);

        console.log("==== Core Contract Addresses =====");
        console.log("Avalanche Collective Core: ", collectiveCoreAvalanche);
        console.log("Optimism Collective Core: ", collectiveCoreOptimism);
        console.log("Polygon Collective Core: ", collectiveCorePolygon);
        console.log("===============================");

        // wrapped asset addresses
        address wAVAX = CollectiveCoreAvalanche(collectiveCoreAvalanche).s_wAVAX();
        address wOP = CollectiveCoreOptimism(collectiveCoreOptimism).s_wOP();
        address wMATIC = CollectiveCorePolygon(collectiveCorePolygon).s_wMATIC();
        console.log("==== Wrapped Asset Addresses =====");
        console.log("Wrapped Avax: ", wAVAX);
        console.log("Wrapped OP ETH: ", wOP);
        console.log("Wrapped MATIC: ", wMATIC);
        console.log("===============================");

        // usdt addresses
        address aUsdt = CollectiveCoreAvalanche(collectiveCoreAvalanche).s_usdt();
        address oUsdt = CollectiveCoreOptimism(collectiveCoreOptimism).s_usdt();
        address pUsdt = CollectiveCorePolygon(collectiveCorePolygon).s_usdt();
        console.log("==== Usdt Addresses =====");
        console.log("Avax USDT: ", aUsdt);
        console.log("Optimism USDT: ", oUsdt);
        console.log("Polygon USDT: ", pUsdt);
        console.log("===============================");

        // link addresses
        LinkTokenInterface aLink = CollectiveCoreAvalanche(collectiveCoreAvalanche).s_linkToken();
        LinkTokenInterface oLink = CollectiveCoreOptimism(collectiveCoreOptimism).s_linkToken();
        LinkTokenInterface pLink = CollectiveCorePolygon(collectiveCorePolygon).s_linkToken();
        console.log("==== Link Token Addresses =====");
        console.log("Avalanche LINK: ", address(aLink));
        console.log("Optimism LINK: ", address(oLink));
        console.log("Polygon LINK: ", address(pLink));
        console.log("===============================");

        return (collectiveCoreAvalanche, collectiveCoreOptimism, collectiveCorePolygon);
    }
}
