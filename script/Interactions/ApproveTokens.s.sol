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
    string USDT_NAME = "USDT";

    // params
    uint256 AMOUNT = 100e18;

    function run() external {

        // collective core avalanche: 0x045E96Ab338B4BAC9B6B2F00DB25e1E6c91EC154
        // collective core optimism: 0xf3e30B0891521D595247AEB48F72105A4434B09E
        // collective core polygon: 0x5A067dFAd546993fd2C546c3e989e7f5eDd414F6
            
        approveToken(USDT_NAME, 0x045E96Ab338B4BAC9B6B2F00DB25e1E6c91EC154, AMOUNT, AVALANCHE_CHAIN_NAME);
        // approveToken(USDT_NAME, 0xf3e30B0891521D595247AEB48F72105A4434B09E, AMOUNT, OPTIMISM_CHAIN_NAME);
        // approveToken(USDT_NAME, 0x5A067dFAd546993fd2C546c3e989e7f5eDd414F6, AMOUNT, POLYGON_CHAIN_NAME);
    }

    function approveToken(string memory assetName, address to, uint256 amount, string memory chainName) public {
        address collectiveAddress = getCollectiveAddress(chainName);

        // Link;
        address link;
        // wrapped asset
        address wrappedAsset;
        // usdt
        address usdt;

        if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(AVALANCHE_CHAIN_NAME))) {
            CollectiveCoreAvalanche collectiveCore = CollectiveCoreAvalanche(collectiveAddress);
            wrappedAsset = collectiveCore.s_wAVAX();
            usdt = collectiveCore.s_usdt();

            LinkTokenInterface linkInterface =
                CollectiveCoreAvalanche(collectiveAddress).s_linkToken();
            link = address(linkInterface);
        }
        if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(OPTIMISM_CHAIN_NAME))) {
            CollectiveCoreOptimism collectiveCore = CollectiveCoreOptimism(collectiveAddress);
            wrappedAsset = collectiveCore.s_wOP();
            usdt = collectiveCore.s_usdt();

            LinkTokenInterface linkInterface =
                CollectiveCoreOptimism(collectiveAddress).s_linkToken();
            link = address(linkInterface);
        }
        if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(POLYGON_CHAIN_NAME))) {
            CollectiveCorePolygon collectiveCore = CollectiveCorePolygon(collectiveAddress);
            wrappedAsset = collectiveCore.s_wMATIC();
            usdt = collectiveCore.s_usdt();

            LinkTokenInterface linkInterface =
                CollectiveCorePolygon(collectiveAddress).s_linkToken();
            link = address(linkInterface);
        }

        address asset;
        if (keccak256(abi.encodePacked(assetName)) == keccak256(abi.encodePacked(LINK_NAME))) {
            asset = link;
        }
        if (keccak256(abi.encodePacked(assetName)) == keccak256(abi.encodePacked(WRAPPED_ASSET_NAME))) {
            asset = wrappedAsset;
        }
        if (keccak256(abi.encodePacked(assetName)) == keccak256(abi.encodePacked(USDT_NAME))) {
            asset = usdt;
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
