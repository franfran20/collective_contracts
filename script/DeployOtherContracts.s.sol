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
        _deployFranFranSwap(
            maticUsdPriceFeed, 0xC88BDB5Dd8d18f847b85259329663AB6D3A0C367, 0x087fbaE066b76Ca42d48950D53c2F01A3daB0444
        );
    }

    // deploy usdt token
    // avalanche: 0x9F6e36A08315c6890FE402799176cd7748FcB695
    // optimism: 0xEF53020fEb7b71E4B700531894991Cc7Ca553fb4
    // polygon: 0xC88BDB5Dd8d18f847b85259329663AB6D3A0C367
    function _deployUsdtToken() private {
        console.log("Deploying on chain id: ", block.chainid);

        vm.startBroadcast();
        MockERC20 usdtToken = new MockERC20("USD Tether", "USDT");
        vm.stopBroadcast();

        console.log("USDT Token deployed at: ", address(usdtToken));
    }

    // deploy wrapped asset
    // avalanche: 0xF142710c99dEB5a8b829Cea2dcE9e74dECA0ff8f
    // optimism: 0x9e7c5e367D41e44b4fEd1e6Ee683f7FefAe58E05
    // polygon: 0x087fbaE066b76Ca42d48950D53c2F01A3daB0444
    function _deployWrappedAsset(string memory name, string memory symbol) private {
        console.log("Deploying on chain id: ", block.chainid);

        vm.startBroadcast();
        MockERC20 wrappedAsset = new MockERC20(name, symbol);
        vm.stopBroadcast();

        console.log("Wrapped Asset Deployed at: ", address(wrappedAsset));
    }

    // deploy franfranswap
    // avalanche: 0x9BC69c6Ba84d0e118763cf999093be9e743947dD
    // optimism: 0x9BC69c6Ba84d0e118763cf999093be9e743947dD
    // polygon: 0x102f7733F9A4f8Bc884FC9DA55AC5C1d091b11F6
    function _deployFranFranSwap(address priceFeed, address usdt, address wrappedAsset) private {
        console.log("Deploying on chain id: ", block.chainid);
        vm.startBroadcast();
        FranFranSwap franfranSwap = new FranFranSwap(priceFeed, usdt, wrappedAsset);
        vm.stopBroadcast();
        console.log("FranFranSwap Deployed at: ", address(franfranSwap));
    }
}
