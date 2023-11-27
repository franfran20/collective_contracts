// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../CollectiveCoreUnitTest.t.sol";

/**
 * @notice Contract For Start Savings Unit Tests
 */
contract StartSavingUnitTest is CollectiveCoreUnitTest {
    //////////////////////////////////////////
    ////// START SAVING FUNCTION TESTS /////
    //////////////////////////////////////////

    uint256[3] TO_BE_SET_TARGET;

    function testStartSavingFunctionRevertsOnUsageOfUnsupportedAssets(address asset) public {
        vm.assume(asset != collectiveCoreAvalanche.s_wAVAX());

        vm.startPrank(USER_ONE);
        vm.expectRevert(ICollectiveCore.CollectiveCore__AssetNotSupported.selector);
        collectiveCoreAvalanche.startSavings(asset, SAVINGS_AMOUNT, SAVING_TIME, SAVING_REASON, SAVINGS_TARGET);
        vm.stopPrank();
    }

    function testStartSavingFunctionFailsWhenAmountIsZero() public {
        vm.startPrank(USER_ONE);
        address wAvax = collectiveCoreAvalanche.s_wAVAX();

        vm.expectRevert(ICollectiveCore.CollectiveCore__AmountMustBeGreaterThanZero.selector);
        collectiveCoreAvalanche.startSavings(wAvax, 0, SAVING_TIME, SAVING_REASON, SAVINGS_TARGET);
        vm.stopPrank();
    }

    function testStartSavingsIndividualSavingsTargetMustBeGreaterThanOrEqualToSavingAmount() public {
        vm.startPrank(USER_ONE);
        address wAvax = collectiveCoreAvalanche.s_wAVAX();

        TO_BE_SET_TARGET = [SAVINGS_AMOUNT + 1e18, 0, SAVINGS_AMOUNT + 5e18];
        uint256 wrongIndex = 1;

        vm.expectRevert(
            abi.encodeWithSelector(ICollectiveCore.CollectiveCore__TargetAmountEqualsZero.selector, wrongIndex)
        );
        collectiveCoreAvalanche.startSavings(wAvax, SAVINGS_AMOUNT, SAVING_TIME, SAVING_REASON, TO_BE_SET_TARGET);
        vm.stopPrank();
    }

    function testStartSavingSavingTimeIsNotZero() public {
        vm.startPrank(USER_ONE);
        address wAvax = collectiveCoreAvalanche.s_wAVAX();
        uint256 wrongSavingTime = 0;

        vm.expectRevert(ICollectiveCore.CollectiveCore__SavingsTimeIssZero.selector);
        collectiveCoreAvalanche.startSavings(wAvax, SAVINGS_AMOUNT, wrongSavingTime, SAVING_REASON, SAVINGS_TARGET);
        vm.stopPrank();
    }

    function testStartSavingsFundsTheContractWithTheAppropriateAssetAmount() public startSavingsWithAvax(USER_ONE) {
        address asset = collectiveCoreAvalanche.s_wAVAX();
        uint256 contractBalance = MockERC20(asset).balanceOf(address(collectiveCoreAvalanche));
        assertEq(contractBalance, SAVINGS_AMOUNT);
    }

    function testStartSavingsRevertIfUserHasExistingSavings() public startSavingsWithAvax(USER_ONE) {
        address wAvax = collectiveCoreAvalanche.s_wAVAX();

        vm.startPrank(USER_ONE);
        _mintAssetToUser(USER_ONE, wAvax, SAVINGS_AMOUNT);
        MockERC20(wAvax).approve(address(collectiveCoreAvalanche), SAVINGS_AMOUNT);
        vm.expectRevert(ICollectiveCore.CollectiveCore__UserHasAnExistingSaving.selector);
        collectiveCoreAvalanche.startSavings(wAvax, SAVINGS_AMOUNT, SAVING_TIME, SAVING_REASON, SAVINGS_TARGET);
        vm.stopPrank();
    }

    function testStartSavingsUpdatesUserSavingsDetails() public startSavingsWithAvax(USER_ONE) {
        (ICollectiveCore.SavingDetails memory savingsDetails) = collectiveCoreAvalanche.getUserSavingsDetails(USER_ONE);
        assertEq(savingsDetails.status, true);
        assertEq(savingsDetails.savingsStartTime, block.timestamp);
        assertEq(savingsDetails.savingsEndTime, block.timestamp + SAVING_TIME);
        assertEq(savingsDetails.reason, SAVING_REASON);

        // savings balance asserts
        assertEq(savingsDetails.savingsBalance.wAVAX, SAVINGS_AMOUNT);

        assertEq(savingsDetails.savingsBalance.wOP, 0);
        assertEq(savingsDetails.savingsBalance.wMATIC, 0);
    }

    function testStartSavingsUpdatesSavingsDetailsOnOptimismFromAvalanche() public startSavingsWithAvax(USER_ONE) {
        (ICollectiveCore.SavingDetails memory savingsDetails) = collectiveCoreOptimism.getUserSavingsDetails(USER_ONE);
        assertEq(savingsDetails.status, true);
        assertEq(savingsDetails.savingsStartTime, block.timestamp);
        assertEq(savingsDetails.savingsEndTime, block.timestamp + SAVING_TIME);
        assertEq(savingsDetails.reason, SAVING_REASON);

        // savings balance asserts
        assertEq(savingsDetails.savingsBalance.wAVAX, SAVINGS_AMOUNT);

        assertEq(savingsDetails.savingsBalance.wOP, 0);
        assertEq(savingsDetails.savingsBalance.wMATIC, 0);
    }

    function testStartSavingsUpdatesSavingsDetailsOnPolygonFromAvalanche() public startSavingsWithAvax(USER_ONE) {
        (ICollectiveCore.SavingDetails memory savingsDetails) = collectiveCorePolygon.getUserSavingsDetails(USER_ONE);
        assertEq(savingsDetails.status, true);
        assertEq(savingsDetails.savingsStartTime, block.timestamp);
        assertEq(savingsDetails.savingsEndTime, block.timestamp + SAVING_TIME);
        assertEq(savingsDetails.reason, SAVING_REASON);

        // savings balance asserts
        assertEq(savingsDetails.savingsBalance.wAVAX, SAVINGS_AMOUNT);

        assertEq(savingsDetails.savingsBalance.wOP, 0);
        assertEq(savingsDetails.savingsBalance.wMATIC, 0);
    }
}
