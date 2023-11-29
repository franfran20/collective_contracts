//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";

import {MockERC20} from "../test/mocks/MockERC20.sol";
import {FranFranSwap} from "../test/mocks/FranFranSwap.sol";

contract DeployOtherContract is Script {
    uint256 DEFAULT_PRIVATE_KEY = vm.envUint("DEFAULT_ANVIL_PRIVATE_KEY");
    uint256 PRIVATE_KEY = vm.envUint("PRIVATE_KEY");

    function run() external {
        _deployUsdtToken();
    }

    // deploy usdt token
    function _deployUsdtToken() private {
        vm.startBroadcast(DEFAULT_PRIVATE_KEY);

        console.log("Deploying on chain id: ", block.chainid);
        MockERC20 usdtToken = new MockERC20("USD Tether", "USDT");
        console.log("USDT Token deployed at: ", address(usdtToken));

        vm.stopBroadcast();
    }

    // deploy wrapped asset
    function _deployWrappedAsset(string memory name, string memory symbol) private {
        vm.startBroadcast(PRIVATE_KEY);

        console.log("Deploying on chain id: ", block.chainid);
        MockERC20 wrappedAsset = new MockERC20(name, symbol);
        console.log("Wrapped Asset Deployed at: ", address(wrappedAsset));

        vm.stopBroadcast();
    }

    // deploy franfranswap
    function _deployFranFranSwap(address priceFeed, address usdt, address wrappedAsset) private {
        vm.startBroadcast(PRIVATE_KEY);

        console.log("Deploying on chain id: ", block.chainid);
        FranFranSwap franfranSwap = new FranFranSwap(priceFeed, usdt, wrappedAsset);
        console.log("FranFranSwap Deployed at: ", address(franfranSwap));
        vm.stopBroadcast();
    }
}
