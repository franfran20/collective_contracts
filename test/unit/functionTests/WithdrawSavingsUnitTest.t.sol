// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../CollectiveCoreUnitTest.t.sol";

/**
 * @notice Unit Tests For Withdrawing Savings
 */
contract WithdrawSavingsUnitTest is CollectiveCoreUnitTest {
    uint256[3] private savingsTarget = [2e18, 2e18, 2e18];

    function testWithdrawSavingsRevertsIfUserSavingStatusIsFalse() public {
        vm.startPrank(USER_ONE);
        vm.expectRevert(ICollectiveCore.CollectiveCore__CanOnlyWithdrawAnExistingSaving.selector);
        collectiveCoreAvalanche.withdrawSavings();
        vm.stopPrank();
    }

    function testWithdrawSavingsRevertsIfWithdrawalTimeHasntArrived() public startSavingsWithAvax(USER_ONE) {
        vm.startPrank(USER_ONE);
        vm.expectRevert(ICollectiveCore.CollectiveCore__WithdrawalTimeHasntArrived.selector);
        collectiveCoreAvalanche.withdrawSavings();
        vm.stopPrank();
    }

    function testWithdrawSavingsRevertsIfUserDoesntMeetSavingsTarget() public startSavingsWithAvax(USER_ONE) {
        vm.warp(block.timestamp + SAVING_TIME + 1);
        vm.startPrank(USER_ONE);
        vm.expectRevert(ICollectiveCore.CollectiveCore__UserDidNotMeetSavingsTarget.selector);
        collectiveCoreAvalanche.withdrawSavings();
        vm.stopPrank();
    }

    function testWithdrawSavingsRevertsIfUserTriesToWithdrawOnChainThatIsntSourceChainForWithdrawal()
        public
        startSavingsWithAvax(USER_ONE)
    {
        _fulfillDefaultTargets(USER_ONE);

        vm.warp(block.timestamp + SAVING_TIME + 1);
        vm.startPrank(USER_ONE);
        vm.expectRevert(ICollectiveCore.CollectiveCore__CannotWithdrawOnThisChain.selector);
        collectiveCoreOptimism.withdrawSavings();
        vm.stopPrank();
    }

    function testWithdrawSavingsRevertsIfUsdtOnContractIsntSufficient() public startSavingsWithAvax(USER_ONE) {
        _fulfillDefaultTargets(USER_ONE);
        vm.warp(block.timestamp + SAVING_TIME + 1);

        _generateInterestInPool(0.1 ether, 1 ether, 2 ether);

        console.log("user one share in interest pool:", collectiveCoreAvalanche.getUsersShareInInterestPool(USER_ONE));

        vm.startPrank(USER_ONE);
        vm.expectRevert(ICollectiveCore.CollectiveCore__ContractDoesntHaveSufficientUsdtToFulFillWithdrawal.selector);
        collectiveCoreAvalanche.withdrawSavings();
        vm.stopPrank();
    }

    function testWithdrawSavingsGivesUserHisInterestInUsdt() public startSavingsWithAvax(USER_ONE) {
        _fulfillDefaultTargets(USER_ONE);
        _depositUSTDToContractsAsCosmicProvider();
        vm.warp(block.timestamp + SAVING_TIME + 1);

        address aUsdt = collectiveCoreAvalanche.s_usdt();

        uint256 interestPoolBalance = _generateInterestInPool(1 ether, 1.5 ether, 0.9 ether);
        uint256 userSavingTime = collectiveCoreAvalanche.getUserSavingTime(USER_ONE);
        uint256 totalSaveTime = collectiveCoreAvalanche.getTotalExpectedSaveTime();
        uint256 expectedUserInterest = (userSavingTime * interestPoolBalance) / totalSaveTime;

        uint256 userUsdtBalanceBeforeWithdrawal = MockERC20(aUsdt).balanceOf(USER_ONE);

        vm.startPrank(USER_ONE);
        collectiveCoreAvalanche.withdrawSavings();
        vm.stopPrank();

        uint256 userUsdtBalanceAfterWithdrawal = MockERC20(aUsdt).balanceOf(USER_ONE);

        assertEq(userUsdtBalanceAfterWithdrawal, userUsdtBalanceBeforeWithdrawal + expectedUserInterest);
    }

    function testWithdrawSavingsGivesUserHisInitialBalanceAccrossChain() public startSavingsWithAvax(USER_ONE) {
        _fulfillDefaultTargets(USER_ONE);
        _depositUSTDToContractsAsCosmicProvider();
        vm.warp(block.timestamp + SAVING_TIME + 1);

        address wAvax = collectiveCoreAvalanche.s_wAVAX();
        address wOp = collectiveCoreOptimism.s_wOP();
        address wMatic = collectiveCorePolygon.s_wMATIC();

        uint256 avaxBalanceBeforeWithdrawal = MockERC20(wAvax).balanceOf(USER_ONE);
        uint256 opEthBalanceBeforeWithdrawal = MockERC20(wOp).balanceOf(USER_ONE);
        uint256 maticBalanceBeforeWithdrawal = MockERC20(wMatic).balanceOf(USER_ONE);

        vm.startPrank(USER_ONE);
        collectiveCoreAvalanche.withdrawSavings();
        vm.stopPrank();

        uint256 avaxBalanceAfterWithdrawal = MockERC20(wAvax).balanceOf(USER_ONE);
        uint256 opEthBalanceAfterWithdrawal = MockERC20(wOp).balanceOf(USER_ONE);
        uint256 maticBalanceAfterWithdrawal = MockERC20(wMatic).balanceOf(USER_ONE);

        assertEq(avaxBalanceAfterWithdrawal, avaxBalanceBeforeWithdrawal + SAVINGS_TARGET[0]);
        assertEq(opEthBalanceAfterWithdrawal, opEthBalanceBeforeWithdrawal + SAVINGS_TARGET[1]);
        assertEq(maticBalanceAfterWithdrawal, maticBalanceBeforeWithdrawal + SAVINGS_TARGET[2]);
    }

    function testWithdrawSavingsUpdatesUsdtBalancesInterestPoolAndAmountSavedInformation()
        public
        startSavingsWithAvax(USER_ONE)
    {
        _fulfillDefaultTargets(USER_ONE);
        _depositUSTDToContractsAsCosmicProvider();
        vm.warp(block.timestamp + SAVING_TIME + 1);

        _generateInterestInPool(1 ether, 1.5 ether, 0.9 ether);

        uint256 interestPoolBalanceBeforeWithdrawal = collectiveCoreAvalanche.getInterestPoolBalance();
        uint256 userInterestShare = collectiveCoreAvalanche.getUsersShareInInterestPool(USER_ONE);

        uint256 avalancheUsdtBalance = collectiveCoreAvalanche.getUsdtBalances().Avalanche;
        ICollectiveCore.CrossChainAssets memory totalChainSavingsBeforeWithdrawal =
            collectiveCoreAvalanche.getTotalChainSavings();

        vm.startPrank(USER_ONE);
        collectiveCoreAvalanche.withdrawSavings();
        vm.stopPrank();

        uint256 intrestPoolBalAfterWithdrawal = collectiveCoreAvalanche.getInterestPoolBalance();
        uint256 avalancheUsdtBalanceAfterWithdrawal = collectiveCoreOptimism.getUsdtBalances().Avalanche;

        ICollectiveCore.CrossChainAssets memory totalChainSavingsAfterWithdrawal =
            collectiveCoreOptimism.getTotalChainSavings();

        assertEq(intrestPoolBalAfterWithdrawal, interestPoolBalanceBeforeWithdrawal - userInterestShare);
        assertEq(avalancheUsdtBalanceAfterWithdrawal, avalancheUsdtBalance - userInterestShare);

        assertEq(totalChainSavingsAfterWithdrawal.wAVAX, totalChainSavingsBeforeWithdrawal.wAVAX - SAVINGS_TARGET[0]);
        assertEq(totalChainSavingsAfterWithdrawal.wOP, totalChainSavingsBeforeWithdrawal.wOP - SAVINGS_TARGET[1]);
        assertEq(totalChainSavingsAfterWithdrawal.wMATIC, totalChainSavingsBeforeWithdrawal.wMATIC - SAVINGS_TARGET[2]);
    }

    function testWithdrawSavingsResetsUsersSavingDetails() public startSavingsWithAvax(USER_ONE) {
        _fulfillDefaultTargets(USER_ONE);
        _depositUSTDToContractsAsCosmicProvider();
        vm.warp(block.timestamp + SAVING_TIME + 1);

        _generateInterestInPool(1 ether, 1.5 ether, 0.9 ether);

        vm.startPrank(USER_ONE);
        collectiveCoreAvalanche.withdrawSavings();
        vm.stopPrank();

        ICollectiveCore.SavingDetails memory userSavingDetails = collectiveCorePolygon.getUserSavingsDetails(USER_ONE);

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

    ////////////////////////////////////////
    ////////// HELPER FUNCTIONS //////////
    ////////////////////////////////////////

    function _generateInterestInPool(uint256 avaxSaveAmount, uint256 opEthSaveAmount, uint256 maticSaveAmount)
        internal
        returns (uint256)
    {
        uint256 savingsTime = 7200;

        _startSavingsAvax(USER_TWO, avaxSaveAmount, savingsTarget, savingsTime);
        _startSavingsOptimism(USER_THREE, opEthSaveAmount, savingsTarget, savingsTime);
        _startSavingsPolygon(USER_FOUR, maticSaveAmount, savingsTarget, savingsTime);

        _breakSavingsOnAvax(USER_TWO);
        _breakSavingsOnOptimism(USER_THREE);

        uint256 intrestPoolBal = collectiveCoreAvalanche.getInterestPoolBalance();

        return intrestPoolBal;
    }

    function _depositUSTDToContractsAsCosmicProvider() internal {
        vm.startPrank(COSMIC_PROVIDER_ONE);

        address aUsdt = collectiveCoreAvalanche.s_usdt();
        _mintAssetToUser(COSMIC_PROVIDER_ONE, aUsdt, DEPOSIT_USDT_AMOUNT);
        MockERC20(aUsdt).approve(address(collectiveCoreAvalanche), DEPOSIT_USDT_AMOUNT);
        collectiveCoreAvalanche.depositUSDT(DEPOSIT_USDT_AMOUNT);

        address oUsdt = collectiveCoreOptimism.s_usdt();
        _mintAssetToUser(COSMIC_PROVIDER_ONE, oUsdt, DEPOSIT_USDT_AMOUNT);
        MockERC20(oUsdt).approve(address(collectiveCoreOptimism), DEPOSIT_USDT_AMOUNT);
        collectiveCoreOptimism.depositUSDT(DEPOSIT_USDT_AMOUNT);

        address pUsdt = collectiveCorePolygon.s_usdt();
        _mintAssetToUser(COSMIC_PROVIDER_ONE, pUsdt, DEPOSIT_USDT_AMOUNT);
        MockERC20(pUsdt).approve(address(collectiveCorePolygon), DEPOSIT_USDT_AMOUNT);
        collectiveCorePolygon.depositUSDT(DEPOSIT_USDT_AMOUNT);

        vm.stopPrank();
    }
}
