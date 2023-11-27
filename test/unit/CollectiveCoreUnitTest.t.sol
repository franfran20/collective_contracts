// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";

import {CollectiveCoreAvalanche} from "../../src/CollectiveContracts/CollectiveCoreAvalanche.sol";
import {CollectiveCoreOptimism} from "../../src/CollectiveContracts/CollectiveCoreOptimism.sol";
import {CollectiveCorePolygon} from "../../src/CollectiveContracts/CollectiveCorePolygon.sol";
import {DeployCollectiveCore} from "../../script/DeployCollectiveCore.s.sol";

import {ICollectiveCore} from "../../src/interfaces/ICollectiveCore.sol";

import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

/**
 * @notice Unit Tests For Collective Core Contracts
 * @dev Most cross chain tests are initiated from avalanche chain for local testing
 */
contract CollectiveCoreUnitTest is Test {
    /**
     * @notice collective core contrats
     */
    CollectiveCoreAvalanche public collectiveCoreAvalanche;
    CollectiveCoreOptimism public collectiveCoreOptimism;
    CollectiveCorePolygon public collectiveCorePolygon;

    address public USER_ONE = makeAddr("USER_ONE");
    address public COSMIC_PROVIDER_ONE = makeAddr("COSMIC_PROVIDER_ONE");

    string constant SAVING_REASON = "To pay for my upcoming rent";

    uint256 public constant SAVINGS_AMOUNT = 2e18;
    uint256 public constant SAVING_TIME = 1 hours;
    uint256 public LINK_AMOUNT_TO_MINT = 10e18;
    uint256 public constant LINK_MINT_AMOUNT = 5 ether;
    uint256 public constant DEPOSIT_USDT_AMOUNT = 200e18;
    uint256 ZERO_AMOUNT = 0;
    uint256 constant REEDEM_AMOUNT = 100e18;

    uint64 constant AVALANCHE_CHAIN_SELECTOR = 14767482510784806043;
    uint64 constant OPTIMISM_CHAIN_SELECTOR = 2664363617261496610;
    uint64 constant POLYGON_CHAIN_SELECTOR = 12532609583862916517;

    uint256[3] SAVINGS_TARGET = [20e18, 2e18, 3e18];

    /**
     * @notice setUp function for testing
     */
    function setUp() external {
        DeployCollectiveCore deployer = new DeployCollectiveCore();
        (address aCollectiveCore, address oCollectiveCore, address pCollectiveCore, HelperConfig config) =
            deployer.run();

        // initialze contracts with their addresses
        collectiveCoreAvalanche = CollectiveCoreAvalanche(aCollectiveCore);
        collectiveCoreOptimism = CollectiveCoreOptimism(oCollectiveCore);
        collectiveCorePolygon = CollectiveCorePolygon(pCollectiveCore);

        // update the contract addresses on each chain
        console.log("Updating destination contract addresses for each contract...");
        collectiveCoreAvalanche.updateCollectiveCoreContractAddressForOtherChains_(oCollectiveCore, pCollectiveCore);
        collectiveCoreOptimism.updateCollectiveCoreContractAddressForOtherChains_(aCollectiveCore, pCollectiveCore);
        collectiveCorePolygon.updateCollectiveCoreContractAddressForOtherChains_(aCollectiveCore, oCollectiveCore);

        // Mint Link To Contracts
        console.log("Minting Mock Link Tokens To Contracts...");
        HelperConfig.MockContracts memory mockContracts = config.getAnvilDeploymentParams();
        MockERC20(mockContracts.aLink).mint(address(collectiveCoreAvalanche), LINK_AMOUNT_TO_MINT);
        MockERC20(mockContracts.oLink).mint(address(collectiveCoreOptimism), LINK_AMOUNT_TO_MINT);
        MockERC20(mockContracts.pLink).mint(address(collectiveCorePolygon), LINK_AMOUNT_TO_MINT);
    }

    ///////////////////////////
    ///// HELPER FUNCTIONS ////
    ///////////////////////////

    /**
     * @notice mints a specified asset to a particular user with a specified amount for testing
     */
    function _mintAssetToUser(address user, address asset, uint256 amount) internal {
        MockERC20(asset).mint(user, amount);
    }

    /**
     * @notice tops up users savings
     */

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

    // Other func to implement
    // deposit usdt
    // reedem usdt
    // withdraw etc

    /**
     * @notice top up savings
     */

    ////////////////////////
    /////// RE-USERS ///////
    ////////////////////////

    /**
     * @notice Succesfull start saving with wAVAX
     */
    modifier startSavingsWithAvax(address user) {
        address asset = collectiveCoreAvalanche.s_wAVAX();
        vm.startPrank(user);
        _mintAssetToUser(USER_ONE, asset, SAVINGS_AMOUNT);
        MockERC20(asset).approve(address(collectiveCoreAvalanche), SAVINGS_AMOUNT);
        collectiveCoreAvalanche.startSavings(
            collectiveCoreAvalanche.s_wAVAX(), SAVINGS_AMOUNT, SAVING_TIME, SAVING_REASON, SAVINGS_TARGET
        );
        vm.stopPrank();
        _;
    }

    /**
     * @notice Succesfull start saving with wOP eth
     */
    modifier startSavingsWithOptimsim(address user) {
        address asset = collectiveCoreOptimism.s_wOP();
        vm.startPrank(user);
        _mintAssetToUser(USER_ONE, asset, SAVINGS_AMOUNT);
        MockERC20(asset).approve(address(collectiveCoreOptimism), SAVINGS_AMOUNT);
        collectiveCoreOptimism.startSavings(
            collectiveCoreOptimism.s_wOP(), SAVINGS_AMOUNT, SAVING_TIME, SAVING_REASON, SAVINGS_TARGET
        );
        vm.stopPrank();
        _;
    }

    /**
     * @notice Succesfull start saving with wOP eth
     */
    modifier startSavingsWithPolygon(address user) {
        address asset = collectiveCorePolygon.s_wMATIC();
        vm.startPrank(user);
        _mintAssetToUser(USER_ONE, asset, SAVINGS_AMOUNT);
        MockERC20(asset).approve(address(collectiveCorePolygon), SAVINGS_AMOUNT);
        collectiveCorePolygon.startSavings(
            collectiveCorePolygon.s_wMATIC(), SAVINGS_AMOUNT, SAVING_TIME, SAVING_REASON, SAVINGS_TARGET
        );
        vm.stopPrank();
        _;
    }

    /**
     * @notice deposit usdt to avalanche contract
     */
    modifier depositUSDTToAvalanche(address user) {
        address asset = collectiveCoreAvalanche.s_usdt();
        vm.startPrank(user);
        _mintAssetToUser(COSMIC_PROVIDER_ONE, collectiveCoreAvalanche.s_usdt(), DEPOSIT_USDT_AMOUNT);
        MockERC20(asset).approve(address(collectiveCoreAvalanche), DEPOSIT_USDT_AMOUNT);
        collectiveCoreAvalanche.depositUSDT(DEPOSIT_USDT_AMOUNT);
        vm.stopPrank();
        _;
    }

    /*
     * @notice deposit usdt to optimism contract
     */

    modifier depositUSDToOptimsim(address user) {
        address asset = collectiveCoreOptimism.s_usdt();
        vm.startPrank(user);
        _mintAssetToUser(COSMIC_PROVIDER_ONE, collectiveCoreOptimism.s_usdt(), DEPOSIT_USDT_AMOUNT);
        MockERC20(asset).approve(address(collectiveCoreOptimism), DEPOSIT_USDT_AMOUNT);
        collectiveCoreOptimism.depositUSDT(DEPOSIT_USDT_AMOUNT);
        vm.stopPrank();
        _;
    }

    /*
     * @notice deposit usdt to polygon contract
     */

    modifier depositUSDToPolygon(address user) {
        address asset = collectiveCorePolygon.s_usdt();
        vm.startPrank(user);
        _mintAssetToUser(COSMIC_PROVIDER_ONE, collectiveCorePolygon.s_usdt(), DEPOSIT_USDT_AMOUNT);
        MockERC20(asset).approve(address(collectiveCorePolygon), DEPOSIT_USDT_AMOUNT);
        collectiveCorePolygon.depositUSDT(DEPOSIT_USDT_AMOUNT);
        vm.stopPrank();
        _;
    }
}
