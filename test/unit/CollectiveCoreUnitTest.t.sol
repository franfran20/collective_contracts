// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";

import {ICollectiveCore} from "../../src/interfaces/ICollectiveCore.sol";
import {CollectiveCoreAvalanche} from "../../src/CollectiveContracts/CollectiveCoreAvalanche.sol";
import {CollectiveCoreOptimism} from "../../src/CollectiveContracts/CollectiveCoreOptimism.sol";
import {CollectiveCorePolygon} from "../../src/CollectiveContracts/CollectiveCorePolygon.sol";

import {DeployCollectiveCore} from "../../script/DeployCollectiveCore.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts-ccip/src/v0.4/interfaces/AggregatorV3Interface.sol";

/**
 * @notice Base Contract For Unit Tests On Collective Core Contracts
 * @dev Most cross chain tests are initiated from avalanche chain for local testing
 * Coverage isnt so high because contracts are basically replicas with minute changes to native asset, detsination chains etc.
 * Tested Mostly From Avalanche and mixed up a few from polygon and optimism locally to be able to reach hackathon deadline.
 */
contract CollectiveCoreUnitTest is Test {
    // collective core contracts
    CollectiveCoreAvalanche collectiveCoreAvalanche;
    CollectiveCoreOptimism collectiveCoreOptimism;
    CollectiveCorePolygon collectiveCorePolygon;

    // users for testing
    address USER_ONE = makeAddr("USER_ONE");
    address USER_TWO = makeAddr("USER_TWO");
    address USER_THREE = makeAddr("USER_THREE");
    address USER_FOUR = makeAddr("USER_FOUR");

    address RANDOM_USER = makeAddr("RANDOM_USER");

    address GROUP_SAVING_RECIPIENT = makeAddr("GROUP_SAVING_RECIPIENT");

    // cosmic provider for testing
    address COSMIC_PROVIDER_ONE = makeAddr("COSMIC_PROVIDER_ONE");

    // saving details for testing

    string constant SAVING_REASON = "To pay for my upcoming rent";
    string constant GROUP_SAVING_REASON = "To help support FranFran Charity Foundation";

    uint256 constant SAVINGS_AMOUNT = 2e18;
    uint256 constant SAVING_TIME = 1 hours;
    uint256 constant GROUP_SAVING_TIME = 2 hours;

    uint256 LINK_AMOUNT_TO_MINT = 10e18;
    uint256 DEPOSIT_USDT_AMOUNT = 200e18;

    uint256 ZERO_AMOUNT = 0;
    uint256 REEDEM_AMOUNT = 100e18;

    uint64 AVALANCHE_CHAIN_SELECTOR = 14767482510784806043;
    uint64 OPTIMISM_CHAIN_SELECTOR = 2664363617261496610;
    uint64 constant POLYGON_CHAIN_SELECTOR = 12532609583862916517;

    uint256[3] SAVINGS_TARGET = [20e18, 2e18, 3e18];
    uint256[3] GROUP_SAVING_TARGET = [5e18, 5e18, 5e18];

    ///setup function
    function setUp() external {
        DeployCollectiveCore deployer = new DeployCollectiveCore();
        (address aCollectiveCore, address oCollectiveCore, address pCollectiveCore, HelperConfig config) =
            deployer.run();

        collectiveCoreAvalanche = CollectiveCoreAvalanche(aCollectiveCore);
        collectiveCoreOptimism = CollectiveCoreOptimism(oCollectiveCore);
        collectiveCorePolygon = CollectiveCorePolygon(pCollectiveCore);

        console.log("Updating destination contract addresses for each contract...");
        collectiveCoreAvalanche.updateCollectiveCoreContractAddressForOtherChains_(oCollectiveCore, pCollectiveCore);
        collectiveCoreOptimism.updateCollectiveCoreContractAddressForOtherChains_(aCollectiveCore, pCollectiveCore);
        collectiveCorePolygon.updateCollectiveCoreContractAddressForOtherChains_(aCollectiveCore, oCollectiveCore);

        console.log("Minting Mock Link Tokens To Contracts...");
        HelperConfig.MockContracts memory mockContracts = config.getAnvilDeploymentParams();
        MockERC20(mockContracts.aLink).mint(address(collectiveCoreAvalanche), LINK_AMOUNT_TO_MINT);
        MockERC20(mockContracts.oLink).mint(address(collectiveCoreOptimism), LINK_AMOUNT_TO_MINT);
        MockERC20(mockContracts.pLink).mint(address(collectiveCorePolygon), LINK_AMOUNT_TO_MINT);
    }

    ///////////////////////////////////////
    ///// HELPER FUNCTIONS FOR TESTING ////
    ///////////////////////////////////////

    /// mints asset to user
    function _mintAssetToUser(address user, address asset, uint256 amount) internal {
        MockERC20(asset).mint(user, amount);
    }

    /// gets the amount to increase the pool by
    function _getAmountToIncreasePoolBy(uint256 usersSavingBalance, uint256 DEFAULT_FEE, address priceFeed)
        public
        view
        returns (uint256)
    {
        uint256 assetAmountTakenFromUser = (usersSavingBalance * DEFAULT_FEE) / 100;
        (, int256 answer,,,) = AggregatorV3Interface(priceFeed).latestRoundData();
        uint256 answerInEighteenDecimals = uint256(answer) * 10e10;
        uint256 usdtTakenFromUser = (answerInEighteenDecimals * assetAmountTakenFromUser) / 10e18;
        return usdtTakenFromUser;
    }

    /// gets the users amount refunded after fee has been collected on breaking savings
    function _getUserAmountRefundedAfterSavingsBreak(uint256 usersSavingBalance, uint256 DEFAULT_FEE)
        public
        pure
        returns (uint256)
    {
        uint256 expectedAmountRefunded = usersSavingBalance * (100 - DEFAULT_FEE) / 100;
        return expectedAmountRefunded;
    }

    /// tops up users saings
    function _topUpUserSavings(address user, uint256 amount, uint64 chainToTopUp) internal {
        vm.startPrank(user);

        address asset;
        if (chainToTopUp == AVALANCHE_CHAIN_SELECTOR) {
            asset = collectiveCoreAvalanche.s_wAVAX();
            _mintAssetToUser(user, asset, amount);
            MockERC20(asset).approve(address(collectiveCoreAvalanche), amount);
            collectiveCoreAvalanche.topUpSavings(asset, amount);
        } else if (chainToTopUp == OPTIMISM_CHAIN_SELECTOR) {
            asset = collectiveCoreOptimism.s_wOP();
            _mintAssetToUser(user, asset, amount);
            MockERC20(asset).approve(address(collectiveCoreOptimism), amount);
            collectiveCoreOptimism.topUpSavings(asset, amount);
        } else if (chainToTopUp == POLYGON_CHAIN_SELECTOR) {
            asset = collectiveCorePolygon.s_wMATIC();
            _mintAssetToUser(user, asset, amount);
            MockERC20(asset).approve(address(collectiveCorePolygon), amount);
            collectiveCorePolygon.topUpSavings(asset, amount);
        } else {
            revert("Unsupported Chain");
        }

        vm.stopPrank();
    }

    // fulfills the users saving target by topping up
    function _fulfillDefaultTargets(address user) internal {
        _topUpUserSavings(user, SAVINGS_TARGET[0] - SAVINGS_AMOUNT, AVALANCHE_CHAIN_SELECTOR);
        _topUpUserSavings(user, SAVINGS_TARGET[1], OPTIMISM_CHAIN_SELECTOR);
        _topUpUserSavings(user, SAVINGS_TARGET[2], POLYGON_CHAIN_SELECTOR);
    }

    // start savings avalanche
    function _startSavingsAvax(address user, uint256 amount, uint256[3] memory savingsTarget, uint256 savingTime)
        internal
    {
        address asset = collectiveCoreAvalanche.s_wAVAX();
        vm.startPrank(user);
        _mintAssetToUser(user, asset, amount);
        MockERC20(asset).approve(address(collectiveCoreAvalanche), amount);
        collectiveCoreAvalanche.startSavings(asset, amount, savingTime, SAVING_REASON, savingsTarget);
        vm.stopPrank();
    }

    // start savings optimsim
    function _startSavingsOptimism(address user, uint256 amount, uint256[3] memory savingsTarget, uint256 savingTime)
        internal
    {
        address asset = collectiveCoreOptimism.s_wOP();
        vm.startPrank(user);
        _mintAssetToUser(user, asset, amount);
        MockERC20(asset).approve(address(collectiveCoreOptimism), amount);
        collectiveCoreOptimism.startSavings(asset, amount, savingTime, SAVING_REASON, savingsTarget);
        vm.stopPrank();
    }

    // start savings polygon
    function _startSavingsPolygon(address user, uint256 amount, uint256[3] memory savingsTarget, uint256 savingTime)
        internal
    {
        address asset = collectiveCorePolygon.s_wMATIC();
        vm.startPrank(user);
        _mintAssetToUser(user, asset, amount);
        MockERC20(asset).approve(address(collectiveCorePolygon), amount);
        collectiveCorePolygon.startSavings(asset, amount, savingTime, SAVING_REASON, savingsTarget);
        vm.stopPrank();
    }

    // break savings avalanche
    function _breakSavingsOnAvax(address user) internal {
        vm.startPrank(user);
        collectiveCoreAvalanche.breakSavings();
        vm.stopPrank();
    }

    // break savings optimsim
    function _breakSavingsOnOptimism(address user) internal {
        vm.startPrank(user);
        collectiveCoreOptimism.breakSavings();
        vm.stopPrank();
    }

    // break savings polygon
    function _breakSavingsOnPolygon(address user) internal {
        vm.startPrank(user);
        collectiveCorePolygon.breakSavings();
        vm.stopPrank();
    }

    // contribute to group savings
    function _contributeToGroupSavingsOnAvalanche(address user, uint256 amount, uint256 groupID) internal {
        vm.startPrank(user);
        address asset = collectiveCoreAvalanche.s_wAVAX();
        _mintAssetToUser(user, asset, amount);
        MockERC20(asset).approve(address(collectiveCoreAvalanche), amount);
        collectiveCoreAvalanche.contributeToGroup(groupID, amount);
        vm.stopPrank();
    }

    function _contributeToGroupSavingsOnOptimism(address user, uint256 amount, uint256 groupID) internal {
        vm.startPrank(user);
        address asset = collectiveCoreOptimism.s_wOP();
        _mintAssetToUser(user, asset, amount);
        MockERC20(asset).approve(address(collectiveCoreOptimism), amount);
        collectiveCoreOptimism.contributeToGroup(groupID, amount);
        vm.stopPrank();
    }

    function _contributeToGroupSavingsOnPolygon(address user, uint256 amount, uint256 groupID) internal {
        vm.startPrank(user);
        address asset = collectiveCorePolygon.s_wMATIC();
        _mintAssetToUser(user, asset, amount);
        MockERC20(asset).approve(address(collectiveCorePolygon), amount);
        collectiveCorePolygon.contributeToGroup(groupID, amount);
        vm.stopPrank();
    }

    ////////////////////////////////////////
    /////// HELPEFUL TEST MODIFIERS ///////
    ///////////////////////////////////////

    /// start svaings with avalanche
    modifier startSavingsWithAvax(address user) {
        address asset = collectiveCoreAvalanche.s_wAVAX();
        vm.startPrank(user);
        _mintAssetToUser(user, asset, SAVINGS_AMOUNT);
        MockERC20(asset).approve(address(collectiveCoreAvalanche), SAVINGS_AMOUNT);
        collectiveCoreAvalanche.startSavings(
            collectiveCoreAvalanche.s_wAVAX(), SAVINGS_AMOUNT, SAVING_TIME, SAVING_REASON, SAVINGS_TARGET
        );
        vm.stopPrank();
        _;
    }

    /// start savings with optimism
    modifier startSavingsWithOptimsim(address user) {
        address asset = collectiveCoreOptimism.s_wOP();
        vm.startPrank(user);
        _mintAssetToUser(user, asset, SAVINGS_AMOUNT);
        MockERC20(asset).approve(address(collectiveCoreOptimism), SAVINGS_AMOUNT);
        collectiveCoreOptimism.startSavings(
            collectiveCoreOptimism.s_wOP(), SAVINGS_AMOUNT, SAVING_TIME, SAVING_REASON, SAVINGS_TARGET
        );
        vm.stopPrank();
        _;
    }

    /// start savings with polygon
    modifier startSavingsWithPolygon(address user) {
        address asset = collectiveCorePolygon.s_wMATIC();
        vm.startPrank(user);
        _mintAssetToUser(user, asset, SAVINGS_AMOUNT);
        MockERC20(asset).approve(address(collectiveCorePolygon), SAVINGS_AMOUNT);
        collectiveCorePolygon.startSavings(
            collectiveCorePolygon.s_wMATIC(), SAVINGS_AMOUNT, SAVING_TIME, SAVING_REASON, SAVINGS_TARGET
        );
        vm.stopPrank();
        _;
    }

    /// deposit usdt as CP to Avalanche
    modifier depositUSDTToAvalanche(address user) {
        address asset = collectiveCoreAvalanche.s_usdt();
        vm.startPrank(user);
        _mintAssetToUser(COSMIC_PROVIDER_ONE, collectiveCoreAvalanche.s_usdt(), DEPOSIT_USDT_AMOUNT);
        MockERC20(asset).approve(address(collectiveCoreAvalanche), DEPOSIT_USDT_AMOUNT);
        collectiveCoreAvalanche.depositUSDT(DEPOSIT_USDT_AMOUNT);
        vm.stopPrank();
        _;
    }

    /// deposit usdt as CP to Optimism
    modifier depositUSDToOptimsim(address user) {
        address asset = collectiveCoreOptimism.s_usdt();
        vm.startPrank(user);
        _mintAssetToUser(COSMIC_PROVIDER_ONE, collectiveCoreOptimism.s_usdt(), DEPOSIT_USDT_AMOUNT);
        MockERC20(asset).approve(address(collectiveCoreOptimism), DEPOSIT_USDT_AMOUNT);
        collectiveCoreOptimism.depositUSDT(DEPOSIT_USDT_AMOUNT);
        vm.stopPrank();
        _;
    }

    /// deposit usdt as CP to Polygon
    modifier depositUSDToPolygon(address user) {
        address asset = collectiveCorePolygon.s_usdt();
        vm.startPrank(user);
        _mintAssetToUser(COSMIC_PROVIDER_ONE, collectiveCorePolygon.s_usdt(), DEPOSIT_USDT_AMOUNT);
        MockERC20(asset).approve(address(collectiveCorePolygon), DEPOSIT_USDT_AMOUNT);
        collectiveCorePolygon.depositUSDT(DEPOSIT_USDT_AMOUNT);
        vm.stopPrank();
        _;
    }

    ///@notice creates group savings
    modifier createGroupSavings(address user, uint256 amount) {
        address asset = collectiveCoreAvalanche.s_wAVAX();
        vm.startPrank(user);
        _mintAssetToUser(user, asset, amount);
        MockERC20(asset).approve(address(collectiveCoreAvalanche), amount);
        collectiveCoreAvalanche.createGroupSavings(
            amount, GROUP_SAVING_REASON, GROUP_SAVING_RECIPIENT, GROUP_SAVING_TIME, GROUP_SAVING_TARGET
        );
        vm.stopPrank();

        _;
    }
}
