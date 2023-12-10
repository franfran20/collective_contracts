// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {ICollectiveCore} from "../../src/interfaces/ICollectiveCore.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {CollectiveCoreAvalanche} from "../../src/CollectiveContracts/CollectiveCoreAvalanche.sol";
import {CollectiveCoreOptimism} from "../../src/CollectiveContracts/CollectiveCoreOptimism.sol";
import {CollectiveCorePolygon} from "../../src/CollectiveContracts/CollectiveCorePolygon.sol";

contract UpdateAddressesScript is Script {
    // chain names
    string AVALANCHE_CHAIN_NAME = "AVALANCHE";
    string OPTIMISM_CHAIN_NAME = "OPTIMISM";
    string POLYGON_CHAIN_NAME = "POLYGON";

    // params
    uint256 AMOUNT = 1e18;
    uint256 TIME = 3600;
    string REASON = "To save the cupcakes";
    uint256[3] TARGET = [3e18, 3e18, 3e18];

    function run() external {
        updateCollectiveCoreContractAddressForOtherChains_(AVALANCHE_CHAIN_NAME);
        updateCollectiveCoreContractAddressForOtherChains_(OPTIMISM_CHAIN_NAME);
        updateCollectiveCoreContractAddressForOtherChains_(POLYGON_CHAIN_NAME);
    }

    function updateCollectiveCoreContractAddressForOtherChains_(string memory chainName) public {
        address collectiveAddress = getCollectiveAddress(chainName);

        address optimismContractAddress =
            DevOpsTools.get_most_recent_deployment("CollectiveCoreOptimism", block.chainid);
        address polygonContractAddress = DevOpsTools.get_most_recent_deployment("CollectiveCorePolygon", block.chainid);
        address avalancheContractAddress =
            DevOpsTools.get_most_recent_deployment("CollectiveCoreAvalanche", block.chainid);

        if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(AVALANCHE_CHAIN_NAME))) {
            CollectiveCoreAvalanche collectiveCore = CollectiveCoreAvalanche(collectiveAddress);
            vm.startBroadcast();
            collectiveCore.updateCollectiveCoreContractAddressForOtherChains_(
                optimismContractAddress, polygonContractAddress
            );
            vm.stopBroadcast();
        } else if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(OPTIMISM_CHAIN_NAME))) {
            CollectiveCoreOptimism collectiveCore = CollectiveCoreOptimism(collectiveAddress);
            vm.startBroadcast();
            collectiveCore.updateCollectiveCoreContractAddressForOtherChains_(
                avalancheContractAddress, polygonContractAddress
            );
            vm.stopBroadcast();
        } else if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(POLYGON_CHAIN_NAME))) {
            CollectiveCorePolygon collectiveCore = CollectiveCorePolygon(collectiveAddress);
            vm.startBroadcast();
            collectiveCore.updateCollectiveCoreContractAddressForOtherChains_(
                avalancheContractAddress, optimismContractAddress
            );
            vm.stopBroadcast();
        }
    }

    function getCollectiveAddress(string memory chainName) public view returns (address) {
        address collectiveAddress;
        if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(AVALANCHE_CHAIN_NAME))) {
            collectiveAddress = DevOpsTools.get_most_recent_deployment("CollectiveCoreAvalanche", block.chainid);
        } else if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(OPTIMISM_CHAIN_NAME))) {
            collectiveAddress = DevOpsTools.get_most_recent_deployment("CollectiveCoreOptimism", block.chainid);
        } else if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(POLYGON_CHAIN_NAME))) {
            collectiveAddress = DevOpsTools.get_most_recent_deployment("CollectiveCorePolygon", block.chainid);
        } else {
            revert("Unsupported Chain ID");
        }

        return collectiveAddress;
    }
}
