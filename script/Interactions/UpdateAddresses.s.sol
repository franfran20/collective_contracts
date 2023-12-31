// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
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

    function run() external {
        // updateCollectiveCoreContractAddressForOtherChains_(AVALANCHE_CHAIN_NAME);
        // updateCollectiveCoreContractAddressForOtherChains_(OPTIMISM_CHAIN_NAME);
        updateCollectiveCoreContractAddressForOtherChains_(POLYGON_CHAIN_NAME);
    }

    // ALWAY RECENT
    // collective core avalanche: 0x045E96Ab338B4BAC9B6B2F00DB25e1E6c91EC154
    // collective core optimism: 0xf3e30B0891521D595247AEB48F72105A4434B09E
    // collective core polygon: 0x5A067dFAd546993fd2C546c3e989e7f5eDd414F6

    function updateCollectiveCoreContractAddressForOtherChains_(string memory chainName) public {
        address collectiveAddress = getCollectiveAddress(chainName);

      
        // address avalancheContractAddress = 0x045E96Ab338B4BAC9B6B2F00DB25e1E6c91EC154;
        // address optimismContractAddress = 0xf3e30B0891521D595247AEB48F72105A4434B09E;
        // address polygonContractAddress = 0x5A067dFAd546993fd2C546c3e989e7f5eDd414F6;

        if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(AVALANCHE_CHAIN_NAME))) {
            CollectiveCoreAvalanche collectiveCore = CollectiveCoreAvalanche(avalancheContractAddress);
            vm.startBroadcast();
            collectiveCore.updateCollectiveCoreContractAddressForOtherChains_(
                optimismContractAddress, polygonContractAddress
            );
            vm.stopBroadcast();
        } else if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(OPTIMISM_CHAIN_NAME))) {
            CollectiveCoreOptimism collectiveCore = CollectiveCoreOptimism(optimismContractAddress);
            vm.startBroadcast();
            collectiveCore.updateCollectiveCoreContractAddressForOtherChains_(
                avalancheContractAddress, polygonContractAddress
            );
            vm.stopBroadcast();
        } else if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(POLYGON_CHAIN_NAME))) {
            CollectiveCorePolygon collectiveCore = CollectiveCorePolygon(polygonContractAddress);
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
