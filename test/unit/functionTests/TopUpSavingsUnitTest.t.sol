// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../CollectiveCoreUnitTest.t.sol";

/**
 * @notice Unit Tests For Topping Up Savings
 */
contract TopUpSavingsUnitTest is CollectiveCoreUnitTest {
    uint256 wAVAX_AMOUNT_TO_TOP_UP = 15e18;

    function testTopUpSavingFunctionRevertsOnUsageOfUnsupportedAssets(address asset)
        public
        startSavingsWithAvax(USER_ONE)
    {
        vm.assume(asset != collectiveCoreAvalanche.s_wAVAX());

        vm.startPrank(USER_ONE);
        vm.expectRevert(ICollectiveCore.CollectiveCore__AssetNotSupported.selector);
        collectiveCoreAvalanche.topUpSavings(asset, SAVINGS_AMOUNT);
        vm.stopPrank();
    }

    function testTopUpSavingsSavingFunctionFailsWhenAmountIsZero() public startSavingsWithAvax(USER_ONE) {
        vm.startPrank(USER_ONE);
        address wAvax = collectiveCoreAvalanche.s_wAVAX();

        vm.expectRevert(ICollectiveCore.CollectiveCore__AmountMustBeGreaterThanZero.selector);
        collectiveCoreAvalanche.topUpSavings(wAvax, 0);
        vm.stopPrank();
    }

    function testTopUpSavingsRevertsIfUserSavingTimeHaexpired() public startSavingsWithAvax(USER_ONE) {
        vm.startPrank(USER_ONE);
        address wAVAX = collectiveCoreAvalanche.s_wAVAX();

        vm.warp(block.timestamp + SAVING_TIME + 10);

        vm.expectRevert(ICollectiveCore.CollectiveCore__SavingsTimeHasPassed.selector);
        collectiveCoreAvalanche.topUpSavings(wAVAX, wAVAX_AMOUNT_TO_TOP_UP);

        vm.stopPrank();
    }

    function testTopUpSavingsRevertsIfUserHasNoActiveSaving() public {
        vm.startPrank(USER_ONE);
        address wAVAX = collectiveCoreAvalanche.s_wAVAX();

        _mintAssetToUser(USER_ONE, wAVAX, wAVAX_AMOUNT_TO_TOP_UP);

        vm.expectRevert(ICollectiveCore.CollectiveCore__UserDoesntHaveAnActiveSaving.selector);
        collectiveCoreAvalanche.topUpSavings(wAVAX, wAVAX_AMOUNT_TO_TOP_UP);

        vm.stopPrank();
    }

    function testTopUpSavingsFundsTheContractWithTheAppropriateAssetAmount() public startSavingsWithAvax(USER_ONE) {
        address asset = collectiveCoreAvalanche.s_wAVAX();
        _mintAssetToUser(USER_ONE, asset, wAVAX_AMOUNT_TO_TOP_UP);

        vm.startPrank(USER_ONE);
        MockERC20(asset).approve(address(collectiveCoreAvalanche), wAVAX_AMOUNT_TO_TOP_UP);
        collectiveCoreAvalanche.topUpSavings(asset, wAVAX_AMOUNT_TO_TOP_UP);

        uint256 contractBalance = MockERC20(asset).balanceOf(address(collectiveCoreAvalanche));
        vm.stopPrank();

        assertEq(contractBalance, wAVAX_AMOUNT_TO_TOP_UP + SAVINGS_AMOUNT);
    }

    function testTopUpSavingsUpdatesUserSavingsDetails() public startSavingsWithAvax(USER_ONE) {
        address asset = collectiveCoreAvalanche.s_wAVAX();
        _mintAssetToUser(USER_ONE, asset, wAVAX_AMOUNT_TO_TOP_UP);
        vm.startPrank(USER_ONE);
        MockERC20(asset).approve(address(collectiveCoreAvalanche), wAVAX_AMOUNT_TO_TOP_UP);
        collectiveCoreAvalanche.topUpSavings(asset, wAVAX_AMOUNT_TO_TOP_UP);

        (ICollectiveCore.SavingDetails memory savingsDetails) = collectiveCoreAvalanche.getUserSavingsDetails(USER_ONE);

        assertEq(savingsDetails.status, true);
        assertEq(savingsDetails.savingsStartTime, block.timestamp);
        assertEq(savingsDetails.savingsEndTime, block.timestamp + SAVING_TIME);
        assertEq(savingsDetails.reason, SAVING_REASON);

        assertEq(savingsDetails.savingsBalance.wAVAX, SAVINGS_AMOUNT + wAVAX_AMOUNT_TO_TOP_UP);
        assertEq(savingsDetails.savingsBalance.wOP, 0);
        assertEq(savingsDetails.savingsBalance.wMATIC, 0);
    }

    function testTopUpSavingsUpdatesSavingsDetailsOnOptimismFromAvalanche() public startSavingsWithAvax(USER_ONE) {
        address asset = collectiveCoreAvalanche.s_wAVAX();
        _mintAssetToUser(USER_ONE, asset, wAVAX_AMOUNT_TO_TOP_UP);
        vm.startPrank(USER_ONE);
        MockERC20(asset).approve(address(collectiveCoreAvalanche), wAVAX_AMOUNT_TO_TOP_UP);
        collectiveCoreAvalanche.topUpSavings(asset, wAVAX_AMOUNT_TO_TOP_UP);

        (ICollectiveCore.SavingDetails memory savingsDetails) = collectiveCoreOptimism.getUserSavingsDetails(USER_ONE);

        assertEq(savingsDetails.status, true);
        assertEq(savingsDetails.savingsStartTime, block.timestamp);
        assertEq(savingsDetails.savingsEndTime, block.timestamp + SAVING_TIME);
        assertEq(savingsDetails.reason, SAVING_REASON);

        assertEq(savingsDetails.savingsBalance.wAVAX, SAVINGS_AMOUNT + wAVAX_AMOUNT_TO_TOP_UP);
        assertEq(savingsDetails.savingsBalance.wOP, 0);
        assertEq(savingsDetails.savingsBalance.wMATIC, 0);
    }

    function testTopUpSavingsUpdatesSavingsDetailsOnPolygonFromAvalanche() public startSavingsWithAvax(USER_ONE) {
        address asset = collectiveCoreAvalanche.s_wAVAX();
        _mintAssetToUser(USER_ONE, asset, wAVAX_AMOUNT_TO_TOP_UP);
        vm.startPrank(USER_ONE);
        MockERC20(asset).approve(address(collectiveCoreAvalanche), wAVAX_AMOUNT_TO_TOP_UP);
        collectiveCoreAvalanche.topUpSavings(asset, wAVAX_AMOUNT_TO_TOP_UP);

        (ICollectiveCore.SavingDetails memory savingsDetails) = collectiveCorePolygon.getUserSavingsDetails(USER_ONE);

        assertEq(savingsDetails.status, true);
        assertEq(savingsDetails.savingsStartTime, block.timestamp);
        assertEq(savingsDetails.savingsEndTime, block.timestamp + SAVING_TIME);
        assertEq(savingsDetails.reason, SAVING_REASON);

        assertEq(savingsDetails.savingsBalance.wAVAX, SAVINGS_AMOUNT + wAVAX_AMOUNT_TO_TOP_UP);
        assertEq(savingsDetails.savingsBalance.wOP, 0);
        assertEq(savingsDetails.savingsBalance.wMATIC, 0);
    }
}
