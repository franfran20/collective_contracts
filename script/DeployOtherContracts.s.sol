//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";

import {MockERC20} from "../test/mocks/MockERC20.sol";
import {FranFranSwap} from "../test/mocks/FranFranSwap.sol";

contract DeployOtherContract is Script {
    address avaxUsdPriceFeed = 0x34C4c526902d88a3Aa98DB8a9b802603EB1E3470;
    address opEthUsdPriceFeed = 0x2e2147bCd571CE816382485E59Cd145A2b7CA451;
    address maticUsdPriceFeed = 0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada;

    function run() external {
       _deployFranFranSwap(maticUsdPriceFeed, 0xC88BDB5Dd8d18f847b85259329663AB6D3A0C367, 0x2eEDEA5e2900D08F3dD58640554DB08411F5d13F);
    }

    function _deployUsdtToken() private {
        console.log("Deploying on chain id: ", block.chainid);

        vm.startBroadcast();
        MockERC20 usdtToken = new MockERC20("USD Tether", "USDT");
        vm.stopBroadcast();

        console.log("USDT Token deployed at: ", address(usdtToken));
    }

    function _deployWrappedAsset(string memory name, string memory symbol) private {
        console.log("Deploying on chain id: ", block.chainid);

        vm.startBroadcast();
        MockERC20 wrappedAsset = new MockERC20(name, symbol);
        vm.stopBroadcast();

        console.log("Wrapped Asset Deployed at: ", address(wrappedAsset));
    }

    function _deployFranFranSwap(address priceFeed, address usdt, address wrappedAsset) private {
        console.log("Deploying on chain id: ", block.chainid);
        vm.startBroadcast();
        FranFranSwap franfranSwap = new FranFranSwap(priceFeed, usdt, wrappedAsset);
        vm.stopBroadcast();
        console.log("FranFranSwap Deployed at: ", address(franfranSwap));
    }
}
