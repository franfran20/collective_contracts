// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title Collective Core Interface
 * @author fRaNFrAn
 * @notice Collective Core Contract Interface For All Collective Core Contracts Across chains
 * @dev Each collective contract are deployed individually to their chains with their names attached to the contract for easy local testing
 */
interface ICollectiveCore {
    ////////////////////////////
    ///////// ERRORS ///////////
    ////////////////////////////

    error CollectiveCore__UserHasAnExistingSaving();
    error CollectiveCore__AssetNotSupported();
    error CollectiveCore__AmountMustBeGreaterThanZero();
    error CollectiveCore__TargetAmountEqualsZero(uint256 targetIndex);
    error CollectiveCore__NotEnoughBalanceForCrossChainTransfer();
    error CollectiveCore__SavingsTimeIssZero();
    error CollectiveCore__UserDoesntHaveAnActiveSaving();
    error CollectiveCore__SavingsTimeHasPassed();
    error CollectiveCore__ERC20TransferFromFailed();
    error CollectiveCore__WithdrawalTimeHasntArrived();
    error CollectiveCore__InsufficientUsdtBalance();
    error CollectiveCore__InsufficientIouUsdtBalance();
    error CollectiveCore__UnlockPeriodHasntArrived();
    error CollectiveCore__InsufficientIouUsdtBalanceForSelectedChain();
    error CollectiveCore__ContractDoesntHaveSufficientUsdtToReedemOnThisChain();
    error CollectiveCore__CanOnlyBreakAnExistingSaving();
    error CollectiveCore__SaveCanBeWithdrawnSuccessfully();
    error CollectiveCore__UserDidNotMeetSavingsTarget();
    error CollectiveCore__ContractDoesntHaveSufficientUsdtToFulFillWithdrawal();
    error CollectiveCore__CannotWithdrawOnThisChain();
    error CollectiveCore__CanOnlyWithdrawAnExistingSaving();
    error CollectiveCore__CannotUpdateDestinationChainContractAddress();
    error CollectiveCore__CannotCreateGroupSavingsOnThisChain();
    error CollectiveCore__CannotJoinGroupSavingsAnymore();
    error CollectiveCore__SavingsGroupDoesNotExist();
    error CollectiveCore__GroupSavingsTimeHasntArrived();
    error CollectiveCore__OnlyContributorsCanDispatchFunds();
    error CollectiveCore__GroupDidNotMeetSavingsTarget();
    error CollectiveCore__GroupSavingsActiveStatusIsFalse();
    error CollectiveCore__CannotClaimContribution();
    error CollectiveCore__NotAMemberOfThisGroup();
    error CollectiveCore__GroupSavingsAlreadyDispatched();
    error CollectiveCore__ContributionAlreadyClaimed();

    event StartedSaving(
        address user,
        uint256 amount,
        uint256 startDate,
        uint256 endDate,
        string reason,
        CrossChainAssets target,
        uint64 chainSelector
    );

    /// User Saving Details
    struct SavingDetails {
        bool status;
        uint256 savingsStartTime;
        uint256 savingsEndTime;
        CrossChainAssets savingsBalance;
        CrossChainAssets savingsTarget;
        string reason;
        uint64 withdrawalChainSelector;
    }

    /// Cross Chain Assets
    struct CrossChainAssets {
        uint256 wAVAX;
        uint256 wOP;
        uint256 wMATIC;
    }

    // Usdt Balances
    struct UsdtBalances {
        uint256 Avalanche;
        uint256 Optimism;
        uint256 Polygon;
    }

    /// Cosmic Provider Details
    struct CosmicProvider {
        uint256 aUSDT;
        uint256 oUSDT;
        uint256 pUSDT;
        uint256 IOU_USDT;
        uint256 totalUSDT;
        uint256 unlockPeriod;
    }

    // Group Savings Details
    struct GroupSavingDetails {
        uint256 groupID;
        string purpose;
        address creator;
        address recipient;
        uint256 savingStartTime;
        uint256 savingStopTime;
        uint256 members;
        CrossChainAssets target;
        CrossChainAssets amountRaised;
    }

    /**
     * @notice Enables a user to initiate savings.
     * @dev Prior to calling this function, the user must have a 'false' saving status. Upon execution, a cross-chain message is dispatched to update the user's savings details on other chains.
     * @param asset The address of the asset, which is the wrapped version of the native asset
     * @param amount The amount of the asset the user wishes to allocate for the savings on initiation.
     * @param time The duration in seconds for which the user intends to save.
     * @param reason The purpose behind the user's savings, such as personal goals, etc.
     * @param target The savings target for the user across chain. AVALANCHE, OPTIMISM & POLYGON respectively
     */
    function startSavings(address asset, uint256 amount, uint256 time, string memory reason, uint256[3] memory target)
        external;

    /**
     * @notice Tops up the users savings if they have an existing savings
     * @param asset The address of the asset the user wishes to top up savings
     * @param amount The amount of asset the user wishes to top up
     */
    function topUpSavings(address asset, uint256 amount) external;

    /**
     * @notice Allows a comsic prvider to deposit usdt into a collective core contract to aid with interest withdrawal ease
     * @dev mints IOU-USDT in the cosmic providers balance that allows them to withdraw the usdt we owe them thats avaialable across any chain of their choice
     * An example would be if we have more usdt on Avalanche chain than polygon for interest sharing. To ease the interest collection to polygon a CP can deposit
     * USDT to the contract on Polygon and get minted IOU USDT token balances that they can use to claim the available usdt tokens on another chain like Avalanche
     * @param amount The usdt deposit amount
     */
    function depositUSDT(uint256 amount) external;

    /**
     * @notice Allows a CP to reedem their IOU-USDT for available usdt.
     * @param amount The amount of IOU USDT that the CP wishes to reedem for usdt
     */
    function reedemUSDT(uint256 amount, uint64 selectedChainSelector) external;

    /**
     * @notice Permits a saver to break their save earlier than planned and attracts a percentage on breaking
     * @dev When savings are broken a cross chain fee is taken and swapped immediately to a stable asset and added to the interest pool
     */
    function breakSavings() external;

    /**
     * @notice Allows a user to withdraw savings upon meeting withdrawal requirements
     * @dev withdrawal requirements include having a saving status of true, fulfillment of saving time and meeting savings target
     */
    function withdrawSavings() external;

    ////////////////////////////////////////
    //////// GROUP REALTED FUNCTIONS ////////
    ////////////////////////////////////////

    /**
     * @notice creates a group saving across chain for users to join from any supported chain of their choice
     * @dev should revert if called from any chain that isnt avalanche.
     * @param amount The amount deposited for saving on initiation of group
     * @param purpose The purpose for creating the group savings
     * @param recipient The recipient of the funds at the end of the group savings
     * @param time The time set to meet the savings target
     * @param targets The saving target for the group accross chain
     */
    function createGroupSavings(
        uint256 amount,
        string memory purpose,
        address recipient,
        uint256 time,
        uint256[3] memory targets
    ) external;

    /**
     * @notice Allows a user to contribute to an existing group savings
     * @param groupID The gorup ID
     * @param amount The contribution amount
     *
     */
    function contributeToGroup(uint256 groupID, uint256 amount) external;

    /**
     * @notice Allows a user to dispatch all the savings in a particular group to the groups sepcified recipient
     * @param groupID The group ID.
     */
    function dispatchGroupFundsToRecipient(uint256 groupID) external;

    /**
     * @notice Allows a user to claim their contribution with the fee taken when a group fails to meet its saving requirement in the specified time
     *  @param groupID The group ID
     */
    function claimGroupContribution(uint256 groupID) external;
}
