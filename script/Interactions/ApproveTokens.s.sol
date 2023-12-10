// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {ICollectiveCore} from "../../src/interfaces/ICollectiveCore.sol";
import {CollectiveCoreAvalanche} from "../../src/CollectiveContracts/CollectiveCoreAvalanche.sol";
import {CollectiveCoreOptimism} from "../../src/CollectiveContracts/CollectiveCoreOptimism.sol";
import {CollectiveCorePolygon} from "../../src/CollectiveContracts/CollectiveCorePolygon.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {LinkTokenInterface} from "@chainlink/contracts-ccip/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {MockERC20} from "../../test/mocks/MockERC20.sol";

contract ApproveTokensScript is Script {
    // chain names
    string AVALANCHE_CHAIN_NAME = "AVALANCHE";
    string OPTIMISM_CHAIN_NAME = "OPTIMISM";
    string POLYGON_CHAIN_NAME = "POLYGON";

    // asset name
    string LINK_NAME = "Link";
    string WRAPPED_ASSET_NAME = "Wrapped Asset";

    // params
    uint256 AMOUNT = 5e18;

    function run() external {
        address collectiveAddressAvalanche =
            DevOpsTools.get_most_recent_deployment("CollectiveCoreAvalanche", block.chainid);
        address collectiveAddressOptimism =
            DevOpsTools.get_most_recent_deployment("CollectiveCoreOptimism", block.chainid);
        address collectiveAddressPolygon =
            DevOpsTools.get_most_recent_deployment("CollectiveCorePolygon", block.chainid);

        //
        approveToken(WRAPPED_ASSET_NAME, collectiveAddressAvalanche, AMOUNT, AVALANCHE_CHAIN_NAME);
    }

    function approveToken(string memory assetName, address to, uint256 amount, string memory chainName) public {
        address collectiveAddress = getCollectiveAddress(chainName);

        // Link;
        address link;
        // wrapped asset
        address wrappedAsset;

        if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(AVALANCHE_CHAIN_NAME))) {
            CollectiveCoreAvalanche collectiveCore = CollectiveCoreAvalanche(collectiveAddress);
            wrappedAsset = collectiveCore.s_wAVAX();

            LinkTokenInterface linkInterface = CollectiveCoreAvalanche(collectiveAddress).s_linkToken();
            link = address(linkInterface);
        }
        if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(OPTIMISM_CHAIN_NAME))) {
            CollectiveCoreOptimism collectiveCore = CollectiveCoreOptimism(collectiveAddress);
            wrappedAsset = collectiveCore.s_wOP();

            LinkTokenInterface linkInterface = CollectiveCoreOptimism(collectiveAddress).s_linkToken();
            link = address(linkInterface);
        }
        if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(POLYGON_CHAIN_NAME))) {
            CollectiveCorePolygon collectiveCore = CollectiveCorePolygon(collectiveAddress);
            wrappedAsset = collectiveCore.s_wMATIC();

            LinkTokenInterface linkInterface = CollectiveCorePolygon(collectiveAddress).s_linkToken();
            link = address(linkInterface);
        }

        address asset;
        if (keccak256(abi.encodePacked(assetName)) == keccak256(abi.encodePacked(LINK_NAME))) {
            asset = link;
        }
        if (keccak256(abi.encodePacked(assetName)) == keccak256(abi.encodePacked(WRAPPED_ASSET_NAME))) {
            asset = wrappedAsset;
        }

        vm.startBroadcast();
        MockERC20(asset).approve(to, amount);
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
