// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/contracts-ccip/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {MockERC20} from "./MockERC20.sol";

/**
 * @notice Mock contrat for simulating a swap using chainlink pricefeed
 */
contract FranFranSwap {
    AggregatorV3Interface priceFeed;
    address usdt;
    address supportedAsset;

    constructor(address _priceFeed, address _usdt, address _supportedAsset) {
        usdt = _usdt;
        supportedAsset = _supportedAsset;
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    /**
     * @notice Nothing similar to an amm, just a basic mock of what we expect it to do
     */
    function swapForUSDT(address asset, uint256 assetAmount) public returns (uint256) {
        if (asset != supportedAsset) {
            revert("Unsupported Asset!");
        }
        MockERC20(asset).transferFrom(msg.sender, address(this), assetAmount);

        (, int256 answer,,,) = priceFeed.latestRoundData();
        uint256 answerIn18Decimals = uint256(answer) * 10e10;

        uint256 amountToGiveOut = (assetAmount * answerIn18Decimals) / 10e18;

        MockERC20(usdt).mint(msg.sender, amountToGiveOut);

        return amountToGiveOut;
    }

    function getEstimatedSwapAmount(address asset, uint256 assetAmount) public view returns (uint256) {
        if (asset != supportedAsset) {
            revert("Unsupported Asset!");
        }

        (, int256 answer,,,) = priceFeed.latestRoundData();
        uint256 answerIn18Decimals = uint256(answer) * 10e10;

        uint256 amountToGiveOut = (assetAmount * answerIn18Decimals) / 10e18;

        return amountToGiveOut;
    }
}
