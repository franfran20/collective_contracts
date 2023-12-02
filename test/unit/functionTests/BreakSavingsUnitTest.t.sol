// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../CollectiveCoreUnitTest.t.sol";
import {FranFranSwap} from "../../mocks/FranFranSwap.sol";
import {AggregatorV3Interface} from "@chainlink/contracts-ccip/src/v0.4/interfaces/AggregatorV3Interface.sol";

/**
 * @notice Unit Test For Breaking Savings
 */
contract BreakSavingsUnitTest is CollectiveCoreUnitTest {
    uint256 BUFFER_AMOUNT = 95;

    function testBreakSavingsRevertsIfUserSavingStatusIsFalse() public {
        vm.startPrank(USER_ONE);

        vm.expectRevert(ICollectiveCore.CollectiveCore__CanOnlyBreakAnExistingSaving.selector);
        collectiveCoreAvalanche.breakSavings();
        vm.stopPrank();
    }

    function testBreakSavingsRevertsIfSavingTimeHasArrivedAndTargetHasBeenMet() public startSavingsWithAvax(USER_ONE) {
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[0], AVALANCHE_CHAIN_SELECTOR);
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[1], OPTIMISM_CHAIN_SELECTOR);
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[2], POLYGON_CHAIN_SELECTOR);

        vm.warp(block.timestamp + SAVING_TIME + 1);

        vm.startPrank(USER_ONE);
        vm.expectRevert(ICollectiveCore.CollectiveCore__SaveCanBeWithdrawnSuccessfully.selector);
        collectiveCoreAvalanche.breakSavings();
        vm.stopPrank();
    }

    function testBreakSavingReturnsTheUsersSavedAmountMinusFeeOnThatChain() public startSavingsWithAvax(USER_ONE) {
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[0] - SAVINGS_AMOUNT, AVALANCHE_CHAIN_SELECTOR);
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[1], OPTIMISM_CHAIN_SELECTOR);
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[2], POLYGON_CHAIN_SELECTOR);

        address s_wAVAX = collectiveCoreAvalanche.s_wAVAX();
        uint256 usersPrevBalanceBeforBreak = MockERC20(s_wAVAX).balanceOf(USER_ONE);

        ICollectiveCore.CrossChainAssets memory userSavingBalance =
            collectiveCoreAvalanche.getUserSavingBalance(USER_ONE);

        vm.startPrank(USER_ONE);
        collectiveCoreAvalanche.breakSavings();
        vm.stopPrank();

        uint256 expectedIncrease =
            (userSavingBalance.wAVAX * (100 - collectiveCoreAvalanche.AVALANCHE_DEFAULT_FEE())) / 100;

        console.log("Expected Increase:", expectedIncrease / 1e18);

        uint256 userBalanceAfterBreak = MockERC20(s_wAVAX).balanceOf(USER_ONE);

        assertEq(userBalanceAfterBreak, usersPrevBalanceBeforBreak + expectedIncrease);
    }

    function testBreakSavingUpdatesTheInterestPoolBalanceAcordingly() public startSavingsWithAvax(USER_ONE) {
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[0] - SAVINGS_AMOUNT, AVALANCHE_CHAIN_SELECTOR);
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[1], OPTIMISM_CHAIN_SELECTOR);
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[2], POLYGON_CHAIN_SELECTOR);

        ICollectiveCore.CrossChainAssets memory userSavingBalance =
            collectiveCoreAvalanche.getUserSavingBalance(USER_ONE);

        vm.startPrank(USER_ONE);
        collectiveCoreAvalanche.breakSavings();
        vm.stopPrank();

        uint256 interestPoolBalanceAfterBreak = collectiveCoreAvalanche.getInterestPoolBalance();

        uint256 avaxUsdtIncrease = _getAmountToIncreasePoolBy(
            userSavingBalance.wAVAX,
            collectiveCoreAvalanche.AVALANCHE_DEFAULT_FEE(),
            collectiveCoreAvalanche.s_avaxPriceFeed()
        );

        uint256 opUsdtIncrease = _getAmountToIncreasePoolBy(
            userSavingBalance.wOP,
            collectiveCoreAvalanche.OPTIMISM_DEFAULT_FEE(),
            collectiveCoreAvalanche.s_opEthPriceFeed()
        );
        uint256 opBufferAmount = (BUFFER_AMOUNT * opUsdtIncrease) / 100;

        uint256 maticUsdtIncrease = _getAmountToIncreasePoolBy(
            userSavingBalance.wMATIC,
            collectiveCoreAvalanche.POLYGON_DEFAULT_FEE(),
            collectiveCoreAvalanche.s_maticPriceFeed()
        );
        uint256 maticBufferAmount = (BUFFER_AMOUNT * maticUsdtIncrease) / 100;

        assertEq(interestPoolBalanceAfterBreak, avaxUsdtIncrease + opBufferAmount + maticBufferAmount);
    }

    function testBreakSavingsDepositsUSDTTokensGottenFromFeeIntoContract() public startSavingsWithAvax(USER_ONE) {
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[0] - SAVINGS_AMOUNT, AVALANCHE_CHAIN_SELECTOR);
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[1], OPTIMISM_CHAIN_SELECTOR);
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[2], POLYGON_CHAIN_SELECTOR);

        address s_wAVAX = collectiveCoreAvalanche.s_wAVAX();

        ICollectiveCore.CrossChainAssets memory userSavingBalance =
            collectiveCoreAvalanche.getUserSavingBalance(USER_ONE);

        uint256 contractUsdtBalanceBeforeBreak =
            MockERC20(collectiveCoreAvalanche.s_usdt()).balanceOf(address(collectiveCoreAvalanche));

        vm.startPrank(USER_ONE);
        collectiveCoreAvalanche.breakSavings();
        vm.stopPrank();

        uint256 amountToSwapToUsdt = collectiveCoreAvalanche.AVALANCHE_DEFAULT_FEE() * userSavingBalance.wAVAX / 100;
        uint256 amountToIncreasePoolBy =
            FranFranSwap(collectiveCoreAvalanche.s_franfranSwap()).getEstimatedSwapAmount(s_wAVAX, amountToSwapToUsdt);

        uint256 contractUsdtBalanceAfterBreak =
            MockERC20(collectiveCoreAvalanche.s_usdt()).balanceOf(address(collectiveCoreAvalanche));

        assertEq(contractUsdtBalanceAfterBreak, contractUsdtBalanceBeforeBreak + amountToIncreasePoolBy);
    }

    function testBreakSavingsDoesNotTransferTheChainAssetIfTheUsersSavingsBalanceOnThatChainWasZero()
        public
        startSavingsWithOptimsim(USER_ONE)
    {
        address s_wAVAX = collectiveCoreAvalanche.s_wAVAX();
        uint256 usersPrevBalanceBeforBreak = MockERC20(s_wAVAX).balanceOf(USER_ONE);
        uint256 interestPoolBalanceBeforeBreak = collectiveCoreAvalanche.getInterestPoolBalance();
        console.log("Interest Pool Before Break:", interestPoolBalanceBeforeBreak);

        ICollectiveCore.CrossChainAssets memory userSavingBalance =
            collectiveCoreAvalanche.getUserSavingBalance(USER_ONE);

        vm.startPrank(USER_ONE);
        collectiveCoreAvalanche.breakSavings();
        vm.stopPrank();

        uint256 opUsdtIncrease = _getAmountToIncreasePoolBy(
            userSavingBalance.wOP,
            collectiveCoreAvalanche.OPTIMISM_DEFAULT_FEE(),
            collectiveCoreAvalanche.s_opEthPriceFeed()
        );
        uint256 opBufferAmount = (BUFFER_AMOUNT * opUsdtIncrease) / 100;

        uint256 userBalanceAfterBreak = MockERC20(s_wAVAX).balanceOf(USER_ONE);
        uint256 interestPoolBalanceAfterBreak = collectiveCoreAvalanche.getInterestPoolBalance();

        assertEq(interestPoolBalanceAfterBreak, interestPoolBalanceBeforeBreak + opBufferAmount);
        assertEq(userBalanceAfterBreak, usersPrevBalanceBeforBreak);
    }

    function testBreakSavingsResetsUsersSavingDetails() public startSavingsWithAvax(USER_ONE) {
        vm.startPrank(USER_ONE);
        collectiveCoreAvalanche.breakSavings();
        vm.stopPrank();

        ICollectiveCore.SavingDetails memory userSavingDetails = collectiveCoreAvalanche.getUserSavingsDetails(USER_ONE);

        assertEq(userSavingDetails.status, false);

        assertEq(userSavingDetails.savingsStartTime, 0);
        assertEq(userSavingDetails.savingsEndTime, 0);

        assertEq(userSavingDetails.savingsBalance.wAVAX, 0);
        assertEq(userSavingDetails.savingsBalance.wOP, 0);
        assertEq(userSavingDetails.savingsBalance.wMATIC, 0);

        assertEq(userSavingDetails.savingsTarget.wAVAX, 0);
        assertEq(userSavingDetails.savingsTarget.wOP, 0);
        assertEq(userSavingDetails.savingsTarget.wMATIC, 0);

        assertEq(userSavingDetails.reason, "");
        assertEq(userSavingDetails.withdrawalChainSelector, 0);
    }

    function testBreakSavingsMakesSureTheInternalUsdtBalancesRecordAreUpdatedAccordingly()
        public
        startSavingsWithAvax(USER_ONE)
    {
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[0] - SAVINGS_AMOUNT, AVALANCHE_CHAIN_SELECTOR);
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[1], OPTIMISM_CHAIN_SELECTOR);
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[2], POLYGON_CHAIN_SELECTOR);

        address s_wAVAX = collectiveCoreAvalanche.s_wAVAX();

        ICollectiveCore.CrossChainAssets memory userSavingBalance =
            collectiveCoreAvalanche.getUserSavingBalance(USER_ONE);

        uint256 avalancheRecordedUsdBalanceBeforeBreak = collectiveCoreAvalanche.getUsdtBalances().Avalanche;

        vm.startPrank(USER_ONE);
        collectiveCoreAvalanche.breakSavings();
        vm.stopPrank();

        uint256 amountToSwapToUsdt = collectiveCoreAvalanche.AVALANCHE_DEFAULT_FEE() * userSavingBalance.wAVAX / 100;
        uint256 amountToIncreaseBalancesBy =
            FranFranSwap(collectiveCoreAvalanche.s_franfranSwap()).getEstimatedSwapAmount(s_wAVAX, amountToSwapToUsdt);

        uint256 avalancheRecordedUsdBalanceAfterBreak = collectiveCoreAvalanche.getUsdtBalances().Avalanche;

        assertEq(
            avalancheRecordedUsdBalanceAfterBreak, avalancheRecordedUsdBalanceBeforeBreak + amountToIncreaseBalancesBy
        );
    }

    /**
     * lazy test. Me trying to beat the hackathon deadline cuz i still have a frontend to build
     */
    function testBreakSavingsUpdatesAllUsdtAndInterstPoolBalancesAccordinglyOnOptimism()
        public
        startSavingsWithAvax(USER_ONE)
    {
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[0] - SAVINGS_AMOUNT, AVALANCHE_CHAIN_SELECTOR);
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[1], OPTIMISM_CHAIN_SELECTOR);
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[2], POLYGON_CHAIN_SELECTOR);

        ICollectiveCore.CrossChainAssets memory userSavingBalance =
            collectiveCoreAvalanche.getUserSavingBalance(USER_ONE);

        vm.startPrank(USER_ONE);
        collectiveCoreAvalanche.breakSavings();
        vm.stopPrank();

        ICollectiveCore.UsdtBalances memory usdtBalances = collectiveCoreOptimism.getUsdtBalances();

        uint256 interestPoolBalance = collectiveCorePolygon.getInterestPoolBalance();

        uint256 avaxUsdtIncrease = _getAmountToIncreasePoolBy(
            userSavingBalance.wAVAX,
            collectiveCoreAvalanche.AVALANCHE_DEFAULT_FEE(),
            collectiveCoreAvalanche.s_avaxPriceFeed()
        );
        uint256 opUsdtIncrease = _getAmountToIncreasePoolBy(
            userSavingBalance.wOP,
            collectiveCoreAvalanche.OPTIMISM_DEFAULT_FEE(),
            collectiveCoreAvalanche.s_opEthPriceFeed()
        );
        uint256 opBufferAmount = (BUFFER_AMOUNT * opUsdtIncrease) / 100;

        uint256 maticUsdtIncrease = _getAmountToIncreasePoolBy(
            userSavingBalance.wMATIC,
            collectiveCoreAvalanche.POLYGON_DEFAULT_FEE(),
            collectiveCoreAvalanche.s_maticPriceFeed()
        );
        uint256 maticBufferAmount = (BUFFER_AMOUNT * maticUsdtIncrease) / 100;

        assertEq(usdtBalances.Avalanche, avaxUsdtIncrease);
        assertEq(usdtBalances.Optimism, opBufferAmount);
        assertEq(usdtBalances.Polygon, maticBufferAmount);

        assertEq(interestPoolBalance, avaxUsdtIncrease + opBufferAmount + maticBufferAmount);
    }

    function testBreakSavingsGivesTheuserTheirSavedFundsMinusFeeAcrossChains() public startSavingsWithAvax(USER_ONE) {
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[0] - SAVINGS_AMOUNT, AVALANCHE_CHAIN_SELECTOR);
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[1], OPTIMISM_CHAIN_SELECTOR);
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[2], POLYGON_CHAIN_SELECTOR);

        ICollectiveCore.CrossChainAssets memory userSavingBalance =
            collectiveCoreAvalanche.getUserSavingBalance(USER_ONE);

        address matic = collectiveCorePolygon.s_wMATIC();
        address opEth = collectiveCoreOptimism.s_wOP();

        uint256 userBalBeforeBreakPolygon = MockERC20(matic).balanceOf(USER_ONE);
        uint256 userBalBeforeBreakOptimism = MockERC20(opEth).balanceOf(USER_ONE);

        vm.startPrank(USER_ONE);
        collectiveCoreAvalanche.breakSavings();
        vm.stopPrank();

        uint256 userBalAfterBreakPolygon = MockERC20(matic).balanceOf(USER_ONE);
        uint256 userBalAfterBreakOptimism = MockERC20(opEth).balanceOf(USER_ONE);

        uint256 expectedAmountRefudedOnPolygon = _getUserAmountRefundedAfterSavingsBreak(
            userSavingBalance.wMATIC, collectiveCoreAvalanche.POLYGON_DEFAULT_FEE()
        );
        uint256 expectedAmountRefudedOnOptimism = _getUserAmountRefundedAfterSavingsBreak(
            userSavingBalance.wOP, collectiveCoreAvalanche.OPTIMISM_DEFAULT_FEE()
        );

        console.log("Amount Refunded On Polygon: ", expectedAmountRefudedOnPolygon);
        console.log("Amount Refunded On Optimism: ", expectedAmountRefudedOnOptimism);

        assertEq(userBalAfterBreakPolygon, userBalBeforeBreakPolygon + expectedAmountRefudedOnPolygon);
        assertEq(userBalAfterBreakOptimism, userBalBeforeBreakOptimism + expectedAmountRefudedOnOptimism);
    }

    function testBreakSavingsSwapsAndFundsTheContractWithAppropriateUsdtOnEachChain()
        public
        startSavingsWithAvax(USER_ONE)
    {
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[0] - SAVINGS_AMOUNT, AVALANCHE_CHAIN_SELECTOR);
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[1], OPTIMISM_CHAIN_SELECTOR);
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[2], POLYGON_CHAIN_SELECTOR);

        ICollectiveCore.CrossChainAssets memory userSavingBalance =
            collectiveCoreAvalanche.getUserSavingBalance(USER_ONE);

        address opUsdt = collectiveCoreOptimism.s_usdt();
        address polygonUsdt = collectiveCorePolygon.s_usdt();

        uint256 contractOpUsdtBalBefore = MockERC20(opUsdt).balanceOf(address(collectiveCoreOptimism));
        uint256 contractPolygonUsdtBalBefore = MockERC20(polygonUsdt).balanceOf(address(collectiveCorePolygon));

        uint256 opUsdtIncrease = _getAmountToIncreasePoolBy(
            userSavingBalance.wOP,
            collectiveCoreAvalanche.OPTIMISM_DEFAULT_FEE(),
            collectiveCoreAvalanche.s_opEthPriceFeed()
        );

        uint256 maticUsdtIncrease = _getAmountToIncreasePoolBy(
            userSavingBalance.wMATIC,
            collectiveCoreAvalanche.POLYGON_DEFAULT_FEE(),
            collectiveCoreAvalanche.s_maticPriceFeed()
        );

        vm.startPrank(USER_ONE);
        collectiveCoreAvalanche.breakSavings();
        vm.stopPrank();

        uint256 contractOpUsdtAfterBal = MockERC20(opUsdt).balanceOf(address(collectiveCoreOptimism));
        uint256 contractPolygonUsdtAfterBal = MockERC20(polygonUsdt).balanceOf(address(collectiveCorePolygon));

        assertEq(contractOpUsdtAfterBal, contractOpUsdtBalBefore + opUsdtIncrease);
        assertEq(contractPolygonUsdtAfterBal, contractPolygonUsdtBalBefore + maticUsdtIncrease);
    }

    function testBreakSavingsResetsUserSavingDetailsOnDestinationChain() public startSavingsWithAvax(USER_ONE) {
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[0] - SAVINGS_AMOUNT, AVALANCHE_CHAIN_SELECTOR);
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[1], OPTIMISM_CHAIN_SELECTOR);
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[2], POLYGON_CHAIN_SELECTOR);

        vm.startPrank(USER_ONE);
        collectiveCoreAvalanche.breakSavings();
        vm.stopPrank();

        ICollectiveCore.SavingDetails memory userSavingDetails = collectiveCoreOptimism.getUserSavingsDetails(USER_ONE);

        assertEq(userSavingDetails.status, false);

        assertEq(userSavingDetails.savingsStartTime, 0);
        assertEq(userSavingDetails.savingsEndTime, 0);

        assertEq(userSavingDetails.savingsBalance.wAVAX, 0);
        assertEq(userSavingDetails.savingsBalance.wOP, 0);
        assertEq(userSavingDetails.savingsBalance.wMATIC, 0);

        assertEq(userSavingDetails.savingsTarget.wAVAX, 0);
        assertEq(userSavingDetails.savingsTarget.wOP, 0);
        assertEq(userSavingDetails.savingsTarget.wMATIC, 0);

        assertEq(userSavingDetails.reason, "");
        assertEq(userSavingDetails.withdrawalChainSelector, 0);
    }

    function testBreakSavingsUpdatesTheTotalExpectedSaveTime() public startSavingsWithAvax(USER_ONE) {
        //
        uint256 prevExpectedTotalSaveTime = collectiveCoreAvalanche.getTotalExpectedSaveTime();
        uint256 userSavingTime = collectiveCoreAvalanche.getUserSavingTime(USER_ONE);

        console.log("Total Saving Time Before Breaking Save: ", prevExpectedTotalSaveTime);
        console.log("User Saving Time Before Breaking Save: ", userSavingTime);

        vm.startPrank(USER_ONE);
        collectiveCoreAvalanche.breakSavings();
        vm.stopPrank();

        uint256 newExpectedSaveTimeOnAvax = collectiveCoreAvalanche.getTotalExpectedSaveTime();
        uint256 newExpectedSaveTimeOnOptimism = collectiveCoreOptimism.getTotalExpectedSaveTime();
        uint256 newExpectedSaveTimeOnPolygon = collectiveCorePolygon.getTotalExpectedSaveTime();

        assertEq(newExpectedSaveTimeOnAvax, prevExpectedTotalSaveTime - userSavingTime);
        assertEq(newExpectedSaveTimeOnOptimism, prevExpectedTotalSaveTime - userSavingTime);
        assertEq(newExpectedSaveTimeOnPolygon, prevExpectedTotalSaveTime - userSavingTime);
    }
}
