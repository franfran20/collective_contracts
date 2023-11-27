// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../CollectiveCoreUnitTest.t.sol";

/**
 * @notice Contract For Depositing USDT Unit Tests
 */
contract BreakSavingsUnitTest is CollectiveCoreUnitTest {
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

    //  uint256[3] SAVINGS_TARGET = [20e18, 2e18, 3e18];
    // uint256 public constant SAVINGS_AMOUNT = 2e18;

    function testBreakSavingsUpdatesTheNecessaryDetailsAndTranfersFundsCorrectly()
        public
        startSavingsWithAvax(USER_ONE)
    {
        _topUpUserSavings(USER_ONE, SAVINGS_TARGET[2], POLYGON_CHAIN_SELECTOR);

        vm.startPrank(USER_ONE);
        collectiveCoreAvalanche.breakSavings();
        vm.stopPrank();

        // asserteq();
    }

    // function testBreakSavingsRevertsIfUserSavingStatusIsFalse() public startSavingsWithAvax(USER_ONE) {
    //     // starts by saving 2 avax with our modifier
    //     vm.startPrank(USER_ONE);
    //     uint256 amountToTopUpSavingsWith = 3e18;
    //     // tops up our savings with 3 op eth
    //     _topUpUserSavings(USER_ONE, amountToTopUpSavingsWith, OPTIMISM_CHAIN_SELECTOR);

    //     vm.stopPrank();
    // }

    // ICollectiveCore.SavingDetails memory userSavingDetails = collectiveCoreAvalanche.getUserSavingsDetails(USER_ONE);

    // console.log("Savings target avax: ", userSavingDetails.savingsTarget.wAVAX);
    // console.log("Savings target op eth: ", userSavingDetails.savingsTarget.wOP);
    // console.log("Savings target matic: ", userSavingDetails.savingsTarget.wMATIC);

    // console.log("Savings balance avax: ", userSavingDetails.savingsBalance.wAVAX);
    // console.log("Savings balance op eth: ", userSavingDetails.savingsBalance.wOP);
    // console.log("Savings balance matic: ", userSavingDetails.savingsBalance.wMATIC);
}
