// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {ICollectiveCore} from "../../src/interfaces/ICollectiveCore.sol";
import {CollectiveCoreAvalanche} from "../../src/CollectiveContracts/CollectiveCoreAvalanche.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateGroupSavingsScript is Script {
    // chain names
    string AVALANCHE_CHAIN_NAME = "AVALANCHE";
    string OPTIMISM_CHAIN_NAME = "OPTIMISM";
    string POLYGON_CHAIN_NAME = "POLYGON";

    // params
    uint256 AMOUNT = 1e18;
    uint256 TIME = 7200;
    address RECIPIENT = makeAddr("Recipient");
    string REASON = "To save the cupcakes";
    uint256[3] TARGET = [2e18, 2e18, 2e18];

    function run() external {
        //
        createGroupSavings(AMOUNT, REASON, RECIPIENT, TIME, TARGET, AVALANCHE_CHAIN_NAME);
    }

    function createGroupSavings(
        uint256 amount,
        string memory reason,
        address recipient,
        uint256 time,
        uint256[3] memory target,
        string memory chainName
    ) public {
        address collectiveAddress = getCollectiveAddress(chainName);
        CollectiveCoreAvalanche collectiveCore = CollectiveCoreAvalanche(collectiveAddress);

        address asset;
        if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(AVALANCHE_CHAIN_NAME))) {
            asset = collectiveCore.s_wAVAX();
        }

        vm.startBroadcast();
        collectiveCore.createGroupSavings(amount, reason, recipient, time, target);
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
