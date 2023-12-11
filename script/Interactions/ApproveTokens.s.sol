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
        address collectiveAddressAvalanche =
            DevOpsTools.get_most_recent_deployment("CollectiveCoreAvalanche", block.chainid);
        address collectiveAddressOptimism =
            DevOpsTools.get_most_recent_deployment("CollectiveCoreOptimism", block.chainid);
        address collectiveAddressPolygon =
            DevOpsTools.get_most_recent_deployment("CollectiveCorePolygon", block.chainid);

        // collective core avalanche: 0xf301F2785c97Eaf119bf1F6C6c33DC8E073e97ce
        // collective core optimism: 0x5cAb396eE29F70634EAad2C742A5cDAcE4E75A37
        // collective core polygon:0x4DaCd28de77660D2d0426b5aEC2c5cBfb8e73831

        //
        approveToken(USDT_NAME, 0x4DaCd28de77660D2d0426b5aEC2c5cBfb8e73831, AMOUNT, AVALANCHE_CHAIN_NAME);
        approveToken(USDT_NAME, collectiveAddressPolygon, AMOUNT, POLYGON_CHAIN_NAME);
        approveToken(USDT_NAME, collectiveAddressOptimism, AMOUNT, OPTIMISM_CHAIN_NAME);
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

            LinkTokenInterface linkInterface = CollectiveCoreAvalanche(collectiveAddress).s_linkToken();
            link = address(linkInterface);
        }
        if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(OPTIMISM_CHAIN_NAME))) {
            CollectiveCoreOptimism collectiveCore = CollectiveCoreOptimism(collectiveAddress);
            wrappedAsset = collectiveCore.s_wOP();
            usdt = collectiveCore.s_usdt();

            LinkTokenInterface linkInterface = CollectiveCoreOptimism(collectiveAddress).s_linkToken();
            link = address(linkInterface);
        }
        if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(POLYGON_CHAIN_NAME))) {
            CollectiveCorePolygon collectiveCore = CollectiveCorePolygon(collectiveAddress);
            wrappedAsset = collectiveCore.s_wMATIC();
            usdt = collectiveCore.s_usdt();

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
        if (keccak256(abi.encodePacked(assetName)) == keccak256(abi.encodePacked(USDT_NAME))) {
            asset = usdt;
        }

        // deploy usdt token
        // avalanche: 0x9F6e36A08315c6890FE402799176cd7748FcB695
        // optimism: 0xEF53020fEb7b71E4B700531894991Cc7Ca553fb4
        // polygon: 0xC88BDB5Dd8d18f847b85259329663AB6D3A0C367

        vm.startBroadcast();
        MockERC20(0xC88BDB5Dd8d18f847b85259329663AB6D3A0C367).approve(to, amount);
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
