// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {ICollectiveCore} from "../../src/interfaces/ICollectiveCore.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract DispatchGroupFundsScript is Script {
    // chain names
    string AVALANCHE_CHAIN_NAME = "AVALANCHE";
    string OPTIMISM_CHAIN_NAME = "OPTIMISM";
    string POLYGON_CHAIN_NAME = "POLYGON";

    // params
    uint256 GROUP_ID = 2;

    function run() external {
        
        dispatchGroupFundsToRecipient(GROUP_ID, AVALANCHE_CHAIN_NAME);
    }

    function dispatchGroupFundsToRecipient(uint256 groupID, string memory chainName) public {
        address collectiveAddress = getCollectiveAddress(chainName);
        ICollectiveCore collectiveCore = ICollectiveCore(collectiveAddress);

        vm.startBroadcast();
        collectiveCore.dispatchGroupFundsToRecipient(groupID);
        vm.stopBroadcast();
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
