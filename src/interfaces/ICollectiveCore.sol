// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title Collective Core Interface
 * @author fRaNFrAn
 * @notice Collective Core Contract Interface For All Collective Core Contracts Across chains
 * @dev Each collective contract are deployed individually to their chains with their names attached to the contract for easy local testing
 */
interface ICollectiveCore {
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
    error CollectiveCore__UserMetSavingTarget();
    error CollectiveCore__SaveCanBeWithdrawnSuccessfully();
    error CollectiveCore__UserDidNotMeetSavingsTarget();
    error CollectiveCore__ContractDoesntHaveSufficientUsdtToFulFillWithdrawal();
    error CollectiveCore__CanotWithdrawOnThisChain();

    event StartedSaving(
        address user,
        uint256 amount,
        uint256 startDate,
        uint256 endDate,
        string reason,
        CrossChainAssets target,
        uint64 chainSelector
    );

    /**
     * @dev savings details relevant to a saver.
     * @param status Indicates the saver's ongoing saving status: Currently saving or not.
     * @param savingsEndTime The user-defined deadline for successful savings withdrawal upon reaching their savings target.
     * @param savingsBalance The saver's cross-chain savings balance following the interface specified chain/asset order.
     * @param savingsTarget Represents the target savings for each individual asset.
     * @param reason The purpose behind the user's savings, such as personal goals, etc.
     */
    struct SavingDetails {
        bool status;
        uint256 savingsStartTime;
        uint256 savingsEndTime;
        CrossChainAssets savingsBalance;
        CrossChainAssets savingsTarget;
        string reason;
        uint64 withdrawalChainSelector;
    }

    struct CrossChainAssets {
        uint256 wAVAX;
        uint256 wOP;
        uint256 wMATIC;
    }

    struct UsdtBalances {
        uint256 Avalanche;
        uint256 Optimism;
        uint256 Polygon;
    }

    struct CosmicProvider {
        uint256 aUSDT;
        uint256 oUSDT;
        uint256 pUSDT;
        uint256 IOU_USDT;
        uint256 totalUSDT;
        uint256 unlockPeriod;
    }

    /**
     * @notice Enables a user to initiate savings.
     * @dev Prior to calling this function, the user must have a 'false' saving status. Upon execution, a cross-chain message is dispatched to update the user's savings details on other chains.
     * @param asset The address of the asset (e.g., wrapped native asset or CLT token) the user intends to deposit for initiating savings.
     * @param amount The quantity of the asset the user wishes to allocate for the savings on initiation.
     * @param time The duration in seconds for which the user intends to save.
     * @param reason The purpose behind the user's savings, such as personal goals, etc.
     * @param target The specified order for all assets the user intends to save. Refer to the chain arrangement immediately after the interface declaration.
     */
    function startSavings(address asset, uint256 amount, uint256 time, string memory reason, uint256[3] memory target)
        external;

    /**
     * @notice Tops up the users savings if they have an existing saving in the contract
     * @param asset The address of the asset the user wishes to top up savings with
     * @param amount The amount of asset the user wishes to top up
     */
    function topUpSavings(address asset, uint256 amount) external;

    /**
     * @notice Allows a comsic prvider to deposit usdt into a collective core contract to aid with interest withdrawal ease
     * @dev mints IOU-USDT in the cosmic providers balance that allows them to withdraw the usdt we owe them thats avaialable across any chain of their choice
     * An example would be if we have more usdt on Avalanche chain than polygon for interest sharing. To ease the interest collection to polygon a CP can deposit
     * USDT to the contract on Polygon and get minted IOU USDT token balances that they can use to claim the available usdt tokens on Avalanche
     * @param amount The usdt deposit amount
     */
    function depositUSDT(uint256 amount) external;

    /**
     * @notice Allows a CP to reedem their IOU-USDT for available usdt.
     * @param amount The amount of IOU USDT that the CP wishes to reedem for usdt
     */
    function reedemUSDT(uint256 amount, uint64 selectedChainSelector) external;

    /**
     * @notice Permits a saver to break their save earlier than planned and attracts a percentage fee by the protocol
     * @dev When savings are broken a cross chain fee is taken and swapped immediately to a stable asset and added to the interest pool
     */
    function breakSavings() external;

    //
    function withdrawSavings() external;

    function contribute() external;

    function dispatchAll() external;

    function claimContribution() external;

    //
    function createGroupSavings() external;

    //
    function joinGroupSavings() external;

    function updateCollectiveCoreContractAddressForOtherChains_(
        address optimismContractAddress,
        address polygonContractAddress
    ) external;
}
