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

contract MintFundsToAddress is Script {
    // chain names
    string AVALANCHE_CHAIN_NAME = "AVALANCHE";
    string OPTIMISM_CHAIN_NAME = "OPTIMISM";
    string POLYGON_CHAIN_NAME = "POLYGON";

    // asset name
    string LINK_NAME = "Link";
    string WRAPPED_ASSET_NAME = "Wrapped Asset";
    string USDT_NAME = "USDT";

    // users
    address ANVIL_USER_ONE = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address ANVIL_USER_TWO = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address ANVIL_USER_THREE = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address ANVIL_USER_FOUR = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    // params
    uint256 AMOUNT = 100e18;

    function run() external {
        address collectiveAddressAvalanche =
            DevOpsTools.get_most_recent_deployment("CollectiveCoreAvalanche", block.chainid);
        address collectiveAddressOptimism =
            DevOpsTools.get_most_recent_deployment("CollectiveCoreOptimism", block.chainid);
        address collectiveAddressPolygon =
            DevOpsTools.get_most_recent_deployment("CollectiveCorePolygon", block.chainid);

        mintFundsToUser(WRAPPED_ASSET_NAME, ANVIL_USER_TWO, AMOUNT, AVALANCHE_CHAIN_NAME);
        mintFundsToUser(WRAPPED_ASSET_NAME, ANVIL_USER_TWO, AMOUNT, OPTIMISM_CHAIN_NAME);
        mintFundsToUser(WRAPPED_ASSET_NAME, ANVIL_USER_TWO, AMOUNT, POLYGON_CHAIN_NAME);

        mintFundsToUser(WRAPPED_ASSET_NAME, ANVIL_USER_ONE, AMOUNT, AVALANCHE_CHAIN_NAME);
        mintFundsToUser(WRAPPED_ASSET_NAME, ANVIL_USER_ONE, AMOUNT, OPTIMISM_CHAIN_NAME);
        mintFundsToUser(WRAPPED_ASSET_NAME, ANVIL_USER_ONE, AMOUNT, POLYGON_CHAIN_NAME);

        mintFundsToUser(LINK_NAME, collectiveAddressAvalanche, AMOUNT, AVALANCHE_CHAIN_NAME);
        mintFundsToUser(LINK_NAME, collectiveAddressOptimism, AMOUNT, OPTIMISM_CHAIN_NAME);
        mintFundsToUser(LINK_NAME, collectiveAddressPolygon, AMOUNT, POLYGON_CHAIN_NAME);

        mintFundsToUser(USDT_NAME, 0x5F7FbE4bf8987FA77Ec6C22FD3f3d558B3b68D4e, AMOUNT, AVALANCHE_CHAIN_NAME);
        mintFundsToUser(USDT_NAME, 0x5F7FbE4bf8987FA77Ec6C22FD3f3d558B3b68D4e, AMOUNT, OPTIMISM_CHAIN_NAME);
        mintFundsToUser(USDT_NAME, 0x5F7FbE4bf8987FA77Ec6C22FD3f3d558B3b68D4e, AMOUNT, POLYGON_CHAIN_NAME);
    }

    function mintFundsToUser(string memory assetName, address to, uint256 amount, string memory chainName) public {
        address collectiveAddress = getCollectiveAddress(chainName);

        // Link
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

            LinkTokenInterface linkInterface = CollectiveCoreOptimism(collectiveAddress).s_linkToken();
            link = address(linkInterface);
            usdt = collectiveCore.s_usdt();
        }
        if (keccak256(abi.encodePacked(chainName)) == keccak256(abi.encodePacked(POLYGON_CHAIN_NAME))) {
            CollectiveCorePolygon collectiveCore = CollectiveCorePolygon(collectiveAddress);
            wrappedAsset = collectiveCore.s_wMATIC();

            LinkTokenInterface linkInterface = CollectiveCorePolygon(collectiveAddress).s_linkToken();
            link = address(linkInterface);
            usdt = collectiveCore.s_usdt();
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
        MockERC20(asset).mint(to, amount);
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
