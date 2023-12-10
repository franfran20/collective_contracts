// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {ICollectiveCore} from "../../src/interfaces/ICollectiveCore.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

import {CollectiveCoreAvalanche} from "../../src/CollectiveContracts/CollectiveCoreAvalanche.sol";
import {CollectiveCoreOptimism} from "../../src/CollectiveContracts/CollectiveCoreOptimism.sol";
import {CollectiveCorePolygon} from "../../src/CollectiveContracts/CollectiveCorePolygon.sol";

contract UserSavingsInfoScript is Script {
    // anvil accounts
    uint256 ANVIL_DEFAULT_KEY = 122;

    // chain names
    string AVALANCHE_CHAIN_NAME = "AVALANCHE";
    string OPTIMISM_CHAIN_NAME = "OPTIMISM";
    string POLYGON_CHAIN_NAME = "POLYGON";

    // users
    address ANVIL_USER_ONE = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address ANVIL_USER_TWO = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address ANVIL_USER_THREE = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address ANVIL_USER_FOUR = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    function run() external {
        getUserSavingsInfo(ANVIL_USER_ONE, AVALANCHE_CHAIN_NAME);
    }

    function getUserSavingsInfo(address user, string memory chainName) public view {
        address collectiveAddress = getCollectiveAddress(chainName);

        if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(AVALANCHE_CHAIN_NAME))) {
            CollectiveCoreAvalanche collectiveCore = CollectiveCoreAvalanche(collectiveAddress);

            console.log("AVAX: User Saving Time Left", collectiveCore.getUserTimeLeftForSavingInSeconds(user));
        }
        //
        else if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(OPTIMISM_CHAIN_NAME))) {
            CollectiveCoreOptimism collectiveCore = CollectiveCoreOptimism(collectiveAddress);

            console.log("OPTIMISM: User Saving Time Left", collectiveCore.getUserTimeLeftForSavingInSeconds(user));
        }
        //
        else if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(POLYGON_CHAIN_NAME))) {
            CollectiveCorePolygon collectiveCore = CollectiveCorePolygon(collectiveAddress);

            console.log("POLYGON: User Saving Time Left", collectiveCore.getUserTimeLeftForSavingInSeconds(user));
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
