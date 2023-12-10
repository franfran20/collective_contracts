// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../CollectiveCoreUnitTest.t.sol";

/**
 * @notice Contract For Withdrawing Savings Unit Test
 */
contract GroupSavingsUnitTest is CollectiveCoreUnitTest {
    //

    ////////////////////////////////////
    ////// CREATE GROUP SAVINGS ////////
    ////////////////////////////////////

    //
    uint256 GROUP_SAVING_START_AMOUNT = 1e18;
    uint256[3] LOWER_TARGET = [1, 2e18, 2e18];
    uint256 CONTRIBUTION_AMOUNT = 2e18;
    uint256 GROUP_ID_ONE = 1;

    function testCreateGroupSavingRevertsIfAmountIsZero() public {
        vm.startPrank(USER_ONE);
        vm.expectRevert(ICollectiveCore.CollectiveCore__AmountMustBeGreaterThanZero.selector);
        collectiveCoreAvalanche.createGroupSavings(
            0, GROUP_SAVING_REASON, GROUP_SAVING_RECIPIENT, GROUP_SAVING_TIME, GROUP_SAVING_TARGET
        );
        vm.stopPrank();
    }

    function testCreateGroupSavingRevertsIfTargetIsLessThanTheDepositAmount() public {
        vm.startPrank(USER_ONE);
        address wAVAX = collectiveCoreAvalanche.s_wAVAX();
        _mintAssetToUser(USER_ONE, wAVAX, GROUP_SAVING_START_AMOUNT);
        MockERC20(wAVAX).approve(address(collectiveCoreAvalanche), GROUP_SAVING_START_AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(ICollectiveCore.CollectiveCore__TargetAmountEqualsZero.selector, 0));
        collectiveCoreAvalanche.createGroupSavings(
            GROUP_SAVING_START_AMOUNT, GROUP_SAVING_REASON, GROUP_SAVING_RECIPIENT, GROUP_SAVING_TIME, LOWER_TARGET
        );
        vm.stopPrank();
    }

    function testCreateGroupSavingRevertsIfSavingTimeIsZero() public {
        vm.startPrank(USER_ONE);
        address wAVAX = collectiveCoreAvalanche.s_wAVAX();
        _mintAssetToUser(USER_ONE, wAVAX, GROUP_SAVING_START_AMOUNT);
        MockERC20(wAVAX).approve(address(collectiveCoreAvalanche), GROUP_SAVING_START_AMOUNT);

        vm.expectRevert(ICollectiveCore.CollectiveCore__SavingsTimeIssZero.selector);
        collectiveCoreAvalanche.createGroupSavings(
            GROUP_SAVING_START_AMOUNT, GROUP_SAVING_REASON, GROUP_SAVING_RECIPIENT, 0, GROUP_SAVING_TARGET
        );
        vm.stopPrank();
    }

    function testCreateGroupSavingsTransfersERC20AmountToContract() public {
        vm.startPrank(USER_ONE);

        address wAVAX = collectiveCoreAvalanche.s_wAVAX();
        uint256 contractBalanceBeforeCreatingGroup = MockERC20(wAVAX).balanceOf(address(collectiveCoreAvalanche));

        _mintAssetToUser(USER_ONE, wAVAX, GROUP_SAVING_START_AMOUNT);
        MockERC20(wAVAX).approve(address(collectiveCoreAvalanche), GROUP_SAVING_START_AMOUNT);

        collectiveCoreAvalanche.createGroupSavings(
            GROUP_SAVING_START_AMOUNT,
            GROUP_SAVING_REASON,
            GROUP_SAVING_RECIPIENT,
            GROUP_SAVING_TIME,
            GROUP_SAVING_TARGET
        );

        uint256 contractBalanceAfterCreatingGroup = MockERC20(wAVAX).balanceOf(address(collectiveCoreAvalanche));

        vm.stopPrank();

        assertEq(contractBalanceAfterCreatingGroup, contractBalanceBeforeCreatingGroup + GROUP_SAVING_START_AMOUNT);
    }

    function testCreateGroupSavingsUpdatesTheArrayOfGroupSavings()
        public
        createGroupSavings(USER_ONE, GROUP_SAVING_START_AMOUNT)
    {
        ICollectiveCore.GroupSavingDetails memory groupSavingDetails =
            collectiveCoreAvalanche.getGroupSavingDetailByID(GROUP_ID_ONE);

        assertEq(groupSavingDetails.groupID, 1);
        assertEq(groupSavingDetails.purpose, GROUP_SAVING_REASON);
        assertEq(groupSavingDetails.creator, USER_ONE);
        assertEq(groupSavingDetails.recipient, GROUP_SAVING_RECIPIENT);
        assertEq(groupSavingDetails.savingStartTime, block.timestamp);
        assertEq(groupSavingDetails.savingStopTime, block.timestamp + GROUP_SAVING_TIME);
        assertEq(groupSavingDetails.members, 1);

        assertEq(groupSavingDetails.target.wAVAX, GROUP_SAVING_TARGET[0]);
        assertEq(groupSavingDetails.target.wOP, GROUP_SAVING_TARGET[1]);
        assertEq(groupSavingDetails.target.wMATIC, GROUP_SAVING_TARGET[2]);

        assertEq(groupSavingDetails.amountRaised.wAVAX, GROUP_SAVING_START_AMOUNT);
        assertEq(groupSavingDetails.amountRaised.wOP, 0);
        assertEq(groupSavingDetails.amountRaised.wMATIC, 0);
    }

    function testCreateGroupSavingUpdatesCreatorsMemberStatusAndContribution()
        public
        createGroupSavings(USER_ONE, GROUP_SAVING_START_AMOUNT)
    {
        uint256 groupID = 1;
        bool status = collectiveCoreAvalanche.getUserMemebrshipStatus(groupID, USER_ONE);
        uint256 userOneContribution = collectiveCoreAvalanche.getUserGroupContribution(GROUP_ID_ONE, USER_ONE).wAVAX;

        assertEq(status, true);
        assertEq(userOneContribution, GROUP_SAVING_START_AMOUNT);
    }

    function testCreateGroupSavingUpdatesGroupSavingDetailsAndMembershipStatusOtherChains()
        public
        createGroupSavings(USER_ONE, GROUP_SAVING_START_AMOUNT)
    {
        uint256 groupID = 1;
        ICollectiveCore.GroupSavingDetails memory groupSavingDetails =
            collectiveCorePolygon.getGroupSavingDetailByID(GROUP_ID_ONE);
        bool status = collectiveCoreAvalanche.getUserMemebrshipStatus(groupID, USER_ONE);

        uint256 userOneContribution = collectiveCorePolygon.getUserGroupContribution(GROUP_ID_ONE, USER_ONE).wAVAX;

        assertEq(groupSavingDetails.groupID, groupID);
        assertEq(groupSavingDetails.purpose, GROUP_SAVING_REASON);
        assertEq(groupSavingDetails.creator, USER_ONE);
        assertEq(groupSavingDetails.recipient, GROUP_SAVING_RECIPIENT);
        assertEq(groupSavingDetails.savingStartTime, block.timestamp);
        assertEq(groupSavingDetails.savingStopTime, block.timestamp + GROUP_SAVING_TIME);
        assertEq(groupSavingDetails.members, 1);

        assertEq(groupSavingDetails.target.wAVAX, GROUP_SAVING_TARGET[0]);
        assertEq(groupSavingDetails.target.wOP, GROUP_SAVING_TARGET[1]);
        assertEq(groupSavingDetails.target.wMATIC, GROUP_SAVING_TARGET[2]);

        assertEq(groupSavingDetails.amountRaised.wAVAX, GROUP_SAVING_START_AMOUNT);
        assertEq(groupSavingDetails.amountRaised.wOP, 0);
        assertEq(groupSavingDetails.amountRaised.wMATIC, 0);

        assertEq(status, true);
        assertEq(userOneContribution, GROUP_SAVING_START_AMOUNT);
    }

    //

    ////////////////////////////////////////////
    ////// CONTRIBUTE TO GROUP SAVINGS ////////
    ////////////////////////////////////////////

    //
    function testContributeToGroupSavingRevertsIfGroupDoesNotExist() public {
        vm.startPrank(USER_ONE);
        address asset = collectiveCoreAvalanche.s_wAVAX();
        _mintAssetToUser(USER_ONE, asset, CONTRIBUTION_AMOUNT);
        MockERC20(asset).approve(address(collectiveCoreAvalanche), CONTRIBUTION_AMOUNT);

        vm.expectRevert(ICollectiveCore.CollectiveCore__SavingsGroupDoesNotExist.selector);
        collectiveCoreAvalanche.contributeToGroup(GROUP_ID_ONE, CONTRIBUTION_AMOUNT);
        vm.stopPrank();
    }

    function testContributeToGroupRevertsIfGroupSavingTimeHasEllapsed()
        public
        createGroupSavings(USER_ONE, GROUP_SAVING_START_AMOUNT)
    {
        vm.warp(block.timestamp + GROUP_SAVING_TIME + 1);

        vm.startPrank(USER_ONE);
        address asset = collectiveCoreAvalanche.s_wAVAX();
        _mintAssetToUser(USER_ONE, asset, CONTRIBUTION_AMOUNT);
        MockERC20(asset).approve(address(collectiveCoreAvalanche), CONTRIBUTION_AMOUNT);

        vm.expectRevert(ICollectiveCore.CollectiveCore__CannotJoinGroupSavingsAnymore.selector);
        collectiveCoreAvalanche.contributeToGroup(GROUP_ID_ONE, CONTRIBUTION_AMOUNT);
        vm.stopPrank();
    }

    function testContribuetToGroupSavingsUpdatesTheContractBalancesAndOtherDetails()
        public
        createGroupSavings(USER_ONE, GROUP_SAVING_START_AMOUNT)
    {
        address asset = collectiveCoreAvalanche.s_wAVAX();
        uint256 contractBalanceBeforeContribution = MockERC20(asset).balanceOf(address(collectiveCoreAvalanche));
        bool userMembershipBeforeContribution = collectiveCoreAvalanche.getUserMemebrshipStatus(GROUP_ID_ONE, USER_TWO);

        _contributeToGroupSavingsOnAvalanche(USER_TWO, CONTRIBUTION_AMOUNT, GROUP_ID_ONE);

        uint256 contractBalanceAfterContribution = MockERC20(asset).balanceOf(address(collectiveCoreAvalanche));
        bool userMembershipAfterContribution = collectiveCoreAvalanche.getUserMemebrshipStatus(GROUP_ID_ONE, USER_TWO);

        ICollectiveCore.GroupSavingDetails memory groupSavingDetails =
            collectiveCorePolygon.getGroupSavingDetailByID(GROUP_ID_ONE);

        uint256 userTwoContribution = collectiveCoreAvalanche.getUserGroupContribution(GROUP_ID_ONE, USER_TWO).wAVAX;

        assertEq(contractBalanceAfterContribution, contractBalanceBeforeContribution + CONTRIBUTION_AMOUNT);
        assertEq(userMembershipAfterContribution, !userMembershipBeforeContribution);

        assertEq(groupSavingDetails.members, 2);
        assertEq(groupSavingDetails.amountRaised.wAVAX, CONTRIBUTION_AMOUNT + GROUP_SAVING_START_AMOUNT);

        assertEq(userTwoContribution, CONTRIBUTION_AMOUNT);
    }

    function testContributeTpGroupSavingUpdatesNeccessarInformationOnOtherChains()
        public
        createGroupSavings(USER_ONE, GROUP_SAVING_START_AMOUNT)
    {
        _contributeToGroupSavingsOnPolygon(USER_TWO, CONTRIBUTION_AMOUNT, GROUP_ID_ONE);

        bool userMembershipOnAnotherChain = collectiveCoreOptimism.getUserMemebrshipStatus(GROUP_ID_ONE, USER_TWO);

        ICollectiveCore.GroupSavingDetails memory groupSavingDetails =
            collectiveCorePolygon.getGroupSavingDetailByID(GROUP_ID_ONE);

        uint256 userAvaxContribution = collectiveCoreOptimism.getUserGroupContribution(GROUP_ID_ONE, USER_ONE).wAVAX;
        uint256 userMaticContribution = collectiveCoreAvalanche.getUserGroupContribution(GROUP_ID_ONE, USER_TWO).wMATIC;

        assertEq(userMembershipOnAnotherChain, true);
        assertEq(groupSavingDetails.members, 2);

        assertEq(groupSavingDetails.amountRaised.wAVAX, GROUP_SAVING_START_AMOUNT);
        assertEq(groupSavingDetails.amountRaised.wMATIC, CONTRIBUTION_AMOUNT);
        assertEq(groupSavingDetails.amountRaised.wOP, 0);

        assertEq(userAvaxContribution, GROUP_SAVING_START_AMOUNT);
        assertEq(userMaticContribution, CONTRIBUTION_AMOUNT);
    }

    //

    ////////////////////////////////////////////
    ///////// DISPATCH GROUP FUNDS /////////////
    ////////////////////////////////////////////

    function testDispatchGroupFundsRevertsIfGroupActiveStatusIsFalse()
        public
        createGroupSavings(USER_ONE, GROUP_SAVING_TARGET[0])
    {
        _contributeToGroupSavingsOnOptimism(USER_TWO, GROUP_SAVING_TARGET[1] - 1e18, GROUP_ID_ONE);
        _contributeToGroupSavingsOnPolygon(USER_THREE, GROUP_SAVING_TARGET[2] - 1e18, GROUP_ID_ONE);

        vm.expectRevert(ICollectiveCore.CollectiveCore__GroupSavingsTimeHasntArrived.selector);
        collectiveCoreAvalanche.dispatchGroupFundsToRecipient(GROUP_ID_ONE);
    }

    function testDispatchGroupFundsRevertIfSavingTargetIsNotMet()
        public
        createGroupSavings(USER_ONE, GROUP_SAVING_TARGET[0])
    {
        _contributeToGroupSavingsOnOptimism(USER_TWO, GROUP_SAVING_TARGET[1] - 1e18, GROUP_ID_ONE);
        _contributeToGroupSavingsOnPolygon(USER_THREE, GROUP_SAVING_TARGET[2] - 1e18, GROUP_ID_ONE);

        vm.warp(block.timestamp + GROUP_SAVING_TIME + 1);

        vm.expectRevert(ICollectiveCore.CollectiveCore__GroupDidNotMeetSavingsTarget.selector);
        collectiveCoreAvalanche.dispatchGroupFundsToRecipient(GROUP_ID_ONE);
    }

    function testDispatchGroupFundsRevertsIfMsgSenderIsNotAContributorToTheGroup()
        public
        createGroupSavings(USER_ONE, GROUP_SAVING_TARGET[0])
    {
        _contributeToGroupSavingsOnOptimism(USER_TWO, GROUP_SAVING_TARGET[1], GROUP_ID_ONE);
        _contributeToGroupSavingsOnPolygon(USER_THREE, GROUP_SAVING_TARGET[2], GROUP_ID_ONE);

        vm.warp(block.timestamp + GROUP_SAVING_TIME + 1);

        vm.startPrank(RANDOM_USER);

        vm.expectRevert(ICollectiveCore.CollectiveCore__OnlyContributorsCanDispatchFunds.selector);
        collectiveCoreAvalanche.dispatchGroupFundsToRecipient(GROUP_ID_ONE);

        vm.stopPrank();
    }

    function testDispatchGroupFundsFundsTheRecipientWithTheAmountRaisedByGroup()
        public
        createGroupSavings(USER_ONE, GROUP_SAVING_TARGET[0])
    {
        _contributeToGroupSavingsOnOptimism(USER_TWO, GROUP_SAVING_TARGET[1], GROUP_ID_ONE);
        _contributeToGroupSavingsOnPolygon(USER_THREE, GROUP_SAVING_TARGET[2], GROUP_ID_ONE);

        vm.warp(block.timestamp + GROUP_SAVING_TIME + 1);

        address wAVAX = collectiveCoreAvalanche.s_wAVAX();
        address wOP = collectiveCoreOptimism.s_wOP();
        address wMATIC = collectiveCorePolygon.s_wMATIC();

        uint256 recipientAvaxPrevBalance = MockERC20(wAVAX).balanceOf(GROUP_SAVING_RECIPIENT);
        uint256 recipientopEthPrevBalance = MockERC20(wOP).balanceOf(GROUP_SAVING_RECIPIENT);
        uint256 recipientMaticPrevBalance = MockERC20(wMATIC).balanceOf(GROUP_SAVING_RECIPIENT);

        vm.startPrank(USER_TWO);
        collectiveCorePolygon.dispatchGroupFundsToRecipient(GROUP_ID_ONE);
        vm.stopPrank();

        uint256 recipientAvaxCurrentBalance = MockERC20(wAVAX).balanceOf(GROUP_SAVING_RECIPIENT);
        uint256 recipientopEthCurrentBalance = MockERC20(wOP).balanceOf(GROUP_SAVING_RECIPIENT);
        uint256 recipientMaticCurrentBalance = MockERC20(wMATIC).balanceOf(GROUP_SAVING_RECIPIENT);

        assertEq(recipientAvaxCurrentBalance, recipientAvaxPrevBalance + GROUP_SAVING_TARGET[0]);
        assertEq(recipientopEthCurrentBalance, recipientopEthPrevBalance + GROUP_SAVING_TARGET[1]);
        assertEq(recipientMaticCurrentBalance, recipientMaticPrevBalance + GROUP_SAVING_TARGET[2]);
    }

    function testDispatchGroupFundsRevertsIfTheFundsHaveAlreadyBeenDispatched()
        public
        createGroupSavings(USER_ONE, GROUP_SAVING_TARGET[0])
    {
        _contributeToGroupSavingsOnOptimism(USER_TWO, GROUP_SAVING_TARGET[1], GROUP_ID_ONE);
        _contributeToGroupSavingsOnPolygon(USER_THREE, GROUP_SAVING_TARGET[2], GROUP_ID_ONE);

        vm.warp(block.timestamp + GROUP_SAVING_TIME + 1);

        vm.startPrank(USER_TWO);
        collectiveCorePolygon.dispatchGroupFundsToRecipient(GROUP_ID_ONE);

        vm.expectRevert(ICollectiveCore.CollectiveCore__GroupSavingsAlreadyDispatched.selector);
        collectiveCorePolygon.dispatchGroupFundsToRecipient(GROUP_ID_ONE);
        vm.stopPrank();
    }

    //

    ////////////////////////////////////////////
    ///////// CLAIM GROUP CONTRIBUTION /////////////
    ////////////////////////////////////////////

    function testClaimGroupContributionRevertsIfGroupDoesNotExist() public {
        vm.startPrank(USER_TWO);
        vm.expectRevert(ICollectiveCore.CollectiveCore__SavingsGroupDoesNotExist.selector);
        collectiveCorePolygon.claimGroupContribution(GROUP_ID_ONE);
        vm.stopPrank();
    }

    function testClaimGroupContributionRevertsIfTheSavingTimeHasEllapsedAndTheTargetHasBeenMet()
        public
        createGroupSavings(USER_ONE, GROUP_SAVING_TARGET[0])
    {
        _contributeToGroupSavingsOnOptimism(USER_TWO, GROUP_SAVING_TARGET[1], GROUP_ID_ONE);
        _contributeToGroupSavingsOnPolygon(USER_THREE, GROUP_SAVING_TARGET[2], GROUP_ID_ONE);

        vm.warp(block.timestamp + GROUP_SAVING_TIME + 1);

        vm.startPrank(USER_TWO);
        vm.expectRevert(ICollectiveCore.CollectiveCore__CannotClaimContribution.selector);
        collectiveCorePolygon.claimGroupContribution(GROUP_ID_ONE);

        vm.stopPrank();
    }

    function testClaimGroupContributionRevertsIfSavingTimeHasntEllapsed()
        public
        createGroupSavings(USER_ONE, GROUP_SAVING_TARGET[0])
    {
        _contributeToGroupSavingsOnOptimism(USER_TWO, GROUP_SAVING_TARGET[1], GROUP_ID_ONE);
        _contributeToGroupSavingsOnPolygon(USER_THREE, GROUP_SAVING_TARGET[2], GROUP_ID_ONE);

        vm.startPrank(USER_TWO);
        vm.expectRevert(ICollectiveCore.CollectiveCore__CannotClaimContribution.selector);
        collectiveCorePolygon.claimGroupContribution(GROUP_ID_ONE);

        vm.stopPrank();
    }

    function testClaimGroupContributionRevertsIfMsgSenderIsNotAContributor()
        public
        createGroupSavings(USER_ONE, GROUP_SAVING_TARGET[0])
    {
        _contributeToGroupSavingsOnOptimism(USER_TWO, GROUP_SAVING_TARGET[1], GROUP_ID_ONE);
        _contributeToGroupSavingsOnPolygon(USER_THREE, GROUP_SAVING_TARGET[2], GROUP_ID_ONE);

        vm.warp(block.timestamp + GROUP_SAVING_TIME + 1);

        vm.startPrank(RANDOM_USER);

        vm.expectRevert(ICollectiveCore.CollectiveCore__CannotClaimContribution.selector);
        collectiveCorePolygon.claimGroupContribution(GROUP_ID_ONE);

        vm.stopPrank();
    }

    function testClaimGroupContributionRevertsIfUserHasAlreadyClaimedContribution()
        public
        createGroupSavings(USER_ONE, GROUP_SAVING_TARGET[0])
    {
        uint256 LOWERED_AMOUNT = 4e18;
        _contributeToGroupSavingsOnOptimism(USER_TWO, LOWERED_AMOUNT, GROUP_ID_ONE);
        _contributeToGroupSavingsOnPolygon(USER_THREE, LOWERED_AMOUNT, GROUP_ID_ONE);

        vm.warp(block.timestamp + GROUP_SAVING_TIME + 1);

        vm.startPrank(USER_ONE);

        collectiveCorePolygon.claimGroupContribution(GROUP_ID_ONE);

        vm.expectRevert(ICollectiveCore.CollectiveCore__ContributionAlreadyClaimed.selector);
        collectiveCorePolygon.claimGroupContribution(GROUP_ID_ONE);

        vm.stopPrank();
    }

    function testClaimGroupContributionReturnsUserFundsAfterTakingFee()
        public
        createGroupSavings(USER_ONE, GROUP_SAVING_TARGET[0])
    {
        uint256 LOWERED_AMOUNT = 4e18;
        address wAvax = collectiveCoreAvalanche.s_wAVAX();
        address wOpEth = collectiveCoreOptimism.s_wOP();

        _contributeToGroupSavingsOnOptimism(USER_ONE, LOWERED_AMOUNT, GROUP_ID_ONE);
        _contributeToGroupSavingsOnOptimism(USER_TWO, LOWERED_AMOUNT, GROUP_ID_ONE);
        _contributeToGroupSavingsOnPolygon(USER_THREE, LOWERED_AMOUNT, GROUP_ID_ONE);

        vm.warp(block.timestamp + GROUP_SAVING_TIME + 1);

        uint256 userAvaxBalanceBeforeClaimingContribution = MockERC20(wAvax).balanceOf(USER_ONE);
        uint256 userOpEthBalanceBeforeClaimingContribution = MockERC20(wOpEth).balanceOf(USER_ONE);

        vm.startPrank(USER_ONE);
        collectiveCorePolygon.claimGroupContribution(GROUP_ID_ONE);
        vm.stopPrank();

        uint256 userAvaxBalanceAfterClaimingContribution = MockERC20(wAvax).balanceOf(USER_ONE);
        uint256 userOpEthBalanceAfterClaimingContribution = MockERC20(wOpEth).balanceOf(USER_ONE);

        uint256 userAvaxBalanceMinusFee =
            (GROUP_SAVING_TARGET[0] * (100 - collectiveCoreAvalanche.AVALANCHE_DEFAULT_FEE())) / 100;
        uint256 userOpEthBalanceMinusFee =
            (LOWERED_AMOUNT * (100 - collectiveCoreOptimism.OPTIMISM_DEFAULT_FEE())) / 100;

        console.log("User Avax Balance Minus Fee", userAvaxBalanceMinusFee);
        console.log("User Op Eth Balance Minus Fee", userOpEthBalanceMinusFee);

        assertEq(
            userAvaxBalanceAfterClaimingContribution,
            userAvaxBalanceBeforeClaimingContribution + userAvaxBalanceMinusFee
        );
        assertEq(
            userOpEthBalanceAfterClaimingContribution,
            userOpEthBalanceBeforeClaimingContribution + userOpEthBalanceMinusFee
        );
    }

    function testClaimGroupContributionUpdatesTheProtocolFeeBalance()
        public
        createGroupSavings(USER_ONE, GROUP_SAVING_TARGET[0])
    {
        _contributeToGroupSavingsOnOptimism(USER_ONE, GROUP_SAVING_TARGET[1], GROUP_ID_ONE);

        uint256 avaxFeeCollected = (GROUP_SAVING_TARGET[0] * collectiveCoreAvalanche.AVALANCHE_DEFAULT_FEE()) / 100;
        uint256 opEthFeeCollected = (GROUP_SAVING_TARGET[1] * collectiveCoreOptimism.OPTIMISM_DEFAULT_FEE()) / 100;

        vm.warp(block.timestamp + GROUP_SAVING_TIME + 1);

        vm.startPrank(USER_ONE);
        collectiveCorePolygon.claimGroupContribution(GROUP_ID_ONE);
        vm.stopPrank();

        uint256 avalancheProtocolProfit = collectiveCoreAvalanche.getProtocolProfit();
        uint256 optimsimProtocolProfit = collectiveCoreOptimism.getProtocolProfit();

        assertEq(avalancheProtocolProfit, avaxFeeCollected);
        assertEq(optimsimProtocolProfit, opEthFeeCollected);
    }
}
