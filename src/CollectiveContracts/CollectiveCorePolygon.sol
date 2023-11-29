// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

// Local Imports
import {ICollectiveCore} from "../interfaces/ICollectiveCore.sol";
import {FranFranSwap} from "../../test/mocks/FranFranSwap.sol";

// Chainlink Imports
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {LinkTokenInterface} from "@chainlink/contracts-ccip/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {AggregatorV3Interface} from "@chainlink/contracts-ccip/src/v0.4/interfaces/AggregatorV3Interface.sol";

// OpenZeppelin Imports
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @title Collective Core Contract
 * @author fRaNFrAn
 * @notice Collective Core Contract For POLYGON
 */

contract CollectiveCorePolygon is ICollectiveCore, CCIPReceiver {
    IRouterClient private s_router;
    LinkTokenInterface private s_linkToken;
    FranFranSwap public s_franfranSwap;

    /// @notice contracts actual usdt balances accross chains
    UsdtBalances private s_UsdtBalances;

    /// @notice contract total saving amount accross chains
    CrossChainAssets private s_totalChainSavings;

    mapping(address asset => bool supported) private s_supportedAsset;
    mapping(address user => SavingDetails) private s_savingsDetails;
    mapping(address cosmicProvider => CosmicProvider) private s_cosmicProvider;

    /// @notice wrapped matic token and usdt
    address public s_wMATIC;
    address public s_usdt;

    ///@notice chainlink price feed addresses
    address public s_avaxPriceFeed;
    address public s_opEthPriceFeed;
    address public s_maticPriceFeed;

    /// @notice avalanche and optimism contract addresses on destination chains
    address private s_avalancheContractAddress;
    address private s_optimismContractAddress;

    /// @notice cross chain interest pool balance in usdt
    uint256 s_interestPoolBalance;
    /// @notice total expected save time by all users across chain
    uint256 public s_totalExpectedSaveTime;
    /// @notice total savers on all chains
    uint256 s_totalSavers;

    /**
     * @dev The chain selectors specified by chainlink for the following chains.
     * see https://docs.chain.link/ccip/supported-networks#overview for more details
     */
    uint64 constant s_avalancheChainSelector = 14767482510784806043;
    uint64 constant s_optimismChainSelector = 2664363617261496610;
    uint64 constant s_polygonChainSelector = 12532609583862916517;

    /**
     * @notice the default fees charged on each chain on save break by a user
     */
    uint256 public constant AVALANCHE_DEFAULT_FEE = 25;
    uint256 public constant OPTIMISM_DEFAULT_FEE = 20;
    uint256 public constant POLYGON_DEFAULT_FEE = 30;

    /// @notice The buffer amount for price of assets when making usd calculations accross chains
    uint256 public constant BUFFER_AMOUNT = 95;

    ///@notice the unlock time a cosmic provider has to wait before being able to withdraw his deposited usdt.
    uint256 constant UNLOCK_PERIOD = 3 hours;

    /**
     * @notice Function path ID's for knowing how to handle cross chain messages
     * @dev This allows the chainlink `_ccipReceive` function to know the execution direction of the cross chain message
     * e.g startSavings was called on source chain so start svaing on this(destination) chain.
     * Its basically the hash of the function name that was called on the source Contract.
     */
    bytes32 constant s_startavingsPath = keccak256("startSavings");
    bytes32 constant s_topUpSavingsPath = keccak256("topUpSavings");
    bytes32 constant s_depositUsdtPath = keccak256("depositUSDT");
    bytes32 constant s_reedemUsdtPath = keccak256("reedemUSDT");
    bytes32 constant s_breakSavingsPath = keccak256("breakSavings");
    bytes32 constant s_withdrawSavingsPath = keccak256("withdrawSavings");

    /// @notice update destination address locked status
    bool locked;

    /**
     * @notice constructor
     * @param asset Wrapped matic token address
     * @param router The address of the ccip router for polygon
     * @param link The address of the link token
     * @param avaxPriceFeed The address of the avax/usd price feed
     * @param opEthPriceFeed The address of the opEth/usd price feed
     * @param maticPriceFeed The address of the matic/usd price feed
     * @param usdt The address of the usdt token
     * @param franfranSwap The address of franfran swap contract
     */
    constructor(
        address asset,
        address router,
        address link,
        address avaxPriceFeed,
        address opEthPriceFeed,
        address maticPriceFeed,
        address usdt,
        address franfranSwap
    ) CCIPReceiver(router) {
        s_supportedAsset[asset] = true;

        s_wMATIC = asset;
        s_linkToken = LinkTokenInterface(link);
        s_usdt = usdt;

        s_avaxPriceFeed = avaxPriceFeed;
        s_opEthPriceFeed = opEthPriceFeed;
        s_maticPriceFeed = maticPriceFeed;

        s_franfranSwap = FranFranSwap(franfranSwap);
        s_router = IRouterClient(router);
    }

    //////////////////////////////////
    /////// EXTERNAL FUNCTIONS ///////
    //////////////////////////////////

    /**
     * @inheritdoc ICollectiveCore
     * @notice Included modifier checks for:
     * Asset support, Zero Amount, Savings Target Safety, Zero Saving Amount
     */
    function startSavings(address asset, uint256 amount, uint256 time, string memory reason, uint256[3] memory target)
        external
        checkAssetSupport(asset)
        checkAmountIsntZero(amount)
        IndividualSavingsTargetGreaterThanOrEqualToSavingAmount(target, amount)
    {
        bool success = IERC20(asset).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert CollectiveCore__ERC20TransferFromFailed();
        }

        _startSaving(
            msg.sender, amount, block.timestamp, block.timestamp + time, reason, target, s_polygonChainSelector
        );

        s_totalExpectedSaveTime += time;
        s_totalSavers += 1;

        bytes memory encodedPathPayload = abi.encode(
            amount, block.timestamp, block.timestamp + time, reason, target, s_totalExpectedSaveTime, s_totalSavers
        );
        bytes memory encodedPayload =
            abi.encode(s_startavingsPath, encodedPathPayload, s_polygonChainSelector, msg.sender);

        _sendCrossChainMessage(s_avalancheContractAddress, encodedPayload, s_avalancheChainSelector);
        _sendCrossChainMessage(s_optimismContractAddress, encodedPayload, s_optimismChainSelector);
    }

    /**
     * @inheritdoc ICollectiveCore
     * @notice Includes modifier checks for:
     * Asset support, Zero Amount, Saving Time
     */
    function topUpSavings(address asset, uint256 amount)
        external
        checkAssetSupport(asset)
        checkAmountIsntZero(amount)
        checkIfUserSavingTimeHasExpired(msg.sender)
    {
        if (!getUserSavingStatus(msg.sender)) {
            revert CollectiveCore__UserDoesntHaveAnActiveSaving();
        }

        bool success = IERC20(asset).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert CollectiveCore__ERC20TransferFromFailed();
        }

        _topUpSavings(msg.sender, amount, s_polygonChainSelector);

        bytes memory innerPayload = abi.encode(amount);
        bytes memory encodedPayload = abi.encode(s_topUpSavingsPath, innerPayload, s_polygonChainSelector, msg.sender);

        _sendCrossChainMessage(s_avalancheContractAddress, encodedPayload, s_avalancheChainSelector);
        _sendCrossChainMessage(s_optimismContractAddress, encodedPayload, s_optimismChainSelector);
    }

    /**
     * @inheritdoc ICollectiveCore
     * @notice Includes modifier checks for:
     * Zero Amount
     */
    function depositUSDT(uint256 amount) external checkAmountIsntZero(amount) {
        if (IERC20(s_usdt).balanceOf(msg.sender) < amount) {
            revert CollectiveCore__InsufficientUsdtBalance();
        }

        (bool success) = IERC20(s_usdt).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert CollectiveCore__ERC20TransferFromFailed();
        }

        s_cosmicProvider[msg.sender].pUSDT += amount;
        s_cosmicProvider[msg.sender].totalUSDT += amount;
        s_cosmicProvider[msg.sender].IOU_USDT += amount;
        s_cosmicProvider[msg.sender].unlockPeriod = block.timestamp + UNLOCK_PERIOD;

        s_UsdtBalances.Polygon += amount;

        bytes memory innerPayload = abi.encode(amount, block.timestamp + UNLOCK_PERIOD);
        bytes memory encodedPayload = abi.encode(s_depositUsdtPath, innerPayload, s_polygonChainSelector, msg.sender);

        _sendCrossChainMessage(s_avalancheContractAddress, encodedPayload, s_avalancheChainSelector);
        _sendCrossChainMessage(s_optimismContractAddress, encodedPayload, s_optimismChainSelector);
    }

    /**
     * @inheritdoc ICollectiveCore
     * @notice Includes modifier checks for:
     * Zero Amount
     */
    function reedemUSDT(uint256 amount, uint64 selectedChainSelector) external checkAmountIsntZero(amount) {
        if (amount > s_cosmicProvider[msg.sender].totalUSDT) {
            revert CollectiveCore__InsufficientIouUsdtBalance();
        }
        if (block.timestamp < s_cosmicProvider[msg.sender].unlockPeriod) {
            revert CollectiveCore__UnlockPeriodHasntArrived();
        }
        if (s_UsdtBalances.Polygon < amount) {
            revert CollectiveCore__ContractDoesntHaveSufficientUsdtToReedemOnThisChain();
        }

        IERC20(s_usdt).transfer(msg.sender, amount);
        s_UsdtBalances.Polygon -= amount;

        _reedemUsdt(msg.sender, amount, selectedChainSelector);

        bytes memory innerPayload = abi.encode(amount, selectedChainSelector);
        bytes memory encodedPayload = abi.encode(s_reedemUsdtPath, innerPayload, s_polygonChainSelector, msg.sender);

        _sendCrossChainMessage(s_avalancheContractAddress, encodedPayload, s_avalancheChainSelector);
        _sendCrossChainMessage(s_optimismContractAddress, encodedPayload, s_optimismChainSelector);
    }

    /**
     * @inheritdoc ICollectiveCore
     * @notice Includes modifier checks for:
     * Zero Amount
     */
    function breakSavings() external checkUserCanBreakSave(msg.sender) {
        uint256 userSavingTime =
            s_savingsDetails[msg.sender].savingsEndTime - s_savingsDetails[msg.sender].savingsStartTime;
        s_totalExpectedSaveTime -= userSavingTime;

        (uint256 interestToAddToPool, uint256 avaxBufferAmount, uint256 opBufferAmount) = _breakSavings(msg.sender);
        uint256 maticBufferAmountNotInUse = 0;

        bytes memory innerPayload =
            abi.encode(interestToAddToPool, avaxBufferAmount, opBufferAmount, maticBufferAmountNotInUse);
        bytes memory encodedPayload = abi.encode(s_breakSavingsPath, innerPayload, s_avalancheChainSelector, msg.sender);

        _sendCrossChainMessage(s_avalancheContractAddress, encodedPayload, s_avalancheChainSelector);
        _sendCrossChainMessage(s_optimismContractAddress, encodedPayload, s_optimismChainSelector);
    }

    /**
     * @inheritdoc ICollectiveCore
     * @notice Includes modifier checks for:
     * Checks user can withdraw succesfully
     */
    function withdrawSavings() external checkUserCanWithdrawSuccesfully(msg.sender) {
        if (s_savingsDetails[msg.sender].withdrawalChainSelector != s_polygonChainSelector) {
            revert CollectiveCore__CannotWithdrawOnThisChain();
        }

        uint256 usersShareInInterestPool = getUsersShareInInterestPool(msg.sender);
        if (IERC20(s_usdt).balanceOf(address(this)) < usersShareInInterestPool) {
            revert CollectiveCore__ContractDoesntHaveSufficientUsdtToFulFillWithdrawal();
        }

        if (usersShareInInterestPool > 0) IERC20(s_usdt).transfer(msg.sender, usersShareInInterestPool);

        CrossChainAssets memory usersChainBalance = s_savingsDetails[msg.sender].savingsBalance;
        if (usersChainBalance.wMATIC > 0) IERC20(s_wMATIC).transfer(msg.sender, usersChainBalance.wMATIC);

        s_interestPoolBalance -= usersShareInInterestPool;
        s_UsdtBalances.Polygon -= usersShareInInterestPool;

        s_totalChainSavings.wAVAX -= usersChainBalance.wAVAX;
        s_totalChainSavings.wOP -= usersChainBalance.wOP;
        s_totalChainSavings.wMATIC -= usersChainBalance.wMATIC;

        _resetUserSavingsDetails(msg.sender);

        bytes memory innerPayload = abi.encode(usersShareInInterestPool);
        bytes memory encodedPayload =
            abi.encode(s_withdrawSavingsPath, innerPayload, s_polygonChainSelector, msg.sender);

        _sendCrossChainMessage(s_optimismContractAddress, encodedPayload, s_optimismChainSelector);
        _sendCrossChainMessage(s_avalancheContractAddress, encodedPayload, s_avalancheChainSelector);
    }

    //////////////////////
    // GROUP SAVINGSSS ////
    //////////////////////

    function createGroupSavings() external {
        // 1. generate a new group savings ID
        // 2. update the group savings details
        // 3. collect starting amount for creating the savings group
        // fire event
        // 3. send a cross chain messgaing sending that information to other chains
    }

    function joinGroupSavings() external {
        // 1. allows a user using the group ID to become a member of the group
        // 2. require that the user isnt already in the group.
        // 3. require a deposit amount to join the svaings group.
        // make sure that the details for the group savings are still valid(not expired) before joining the group: else revert
        // 4. update the members count and the group details.abi
        // fire event
        // send a cross chain message updating the group details.
    }

    function contribute() external {
        // allows a member to contribute to the savings group
        // checks that the contribution amount is not zero
        // must be a member of the savings group
        // makes sure that conribution to the group wontrevert due to the group already failing to meet their target in specified time.
        // update the group details balance and member contribution.
        // fire event
        // send cross chain message updating the group details after contribution.
    }

    function dispatchAll() external {
        // dispatches all the assets to a particular address from a "succesfull" group saving.
        // checks that thr group svaing was succcesful
        // check that the dispatcher is a member of the group
        // updates the group svaings details and balance and dispatched the asset on individual chains
        // fire event
        // send cross chain message updating the group savings details and balance
    }

    function claimContribution() external {
        // claim contribution when a group savings fails to reach its saving goals
        // check that the user was a memberof the svaings group
        // checks that the amount he's withdrawing is actually >= what he has in his balance
        // sends tokens back to the user after collecting failure fee
        // fire event
        // sends cross chain message to initiate withdrawal across chain with failure fee attacthed to each chains
    }

    ///// INTERNAL FUNCTIONS //////

    /**
     * @notice Internal start savings funciton that handles the savings logic for a user
     * @dev Can be called directly by the saver or the `ccipReceive` function to handle information updating across chain
     * @param user The saver
     * @param amount Saving amount
     * @param startTime Saving start time
     * @param endTime Saving end time
     * @param reason Saving reason
     * @param target Cross chain savings target
     * @param chainSelector Chain selector for withdrawal
     */
    function _startSaving(
        address user,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        string memory reason,
        uint256[3] memory target,
        uint64 chainSelector
    ) internal {
        bool userSavingStatus = getUserSavingStatus(user);
        if (userSavingStatus) {
            revert CollectiveCore__UserHasAnExistingSaving();
        }

        s_savingsDetails[user] = SavingDetails({
            status: true,
            savingsStartTime: startTime,
            savingsEndTime: endTime,
            reason: reason,
            savingsBalance: CrossChainAssets(0, 0, 0),
            savingsTarget: CrossChainAssets(target[0], target[1], target[2]),
            withdrawalChainSelector: chainSelector
        });

        if (chainSelector == s_avalancheChainSelector) {
            s_savingsDetails[user].savingsBalance.wAVAX += amount;
            s_totalChainSavings.wAVAX += amount;
        }
        if (chainSelector == s_optimismChainSelector) {
            s_savingsDetails[user].savingsBalance.wOP += amount;
            s_totalChainSavings.wOP += amount;
        }
        if (chainSelector == s_polygonChainSelector) {
            s_savingsDetails[user].savingsBalance.wMATIC += amount;
            s_totalChainSavings.wMATIC += amount;
        }

        emit StartedSaving(
            user, amount, startTime, endTime, reason, CrossChainAssets(target[0], target[1], target[2]), chainSelector
        );
    }

    /**
     * @notice Internal top up savings function for updating users saving information on top up
     * @dev Can be called directly by the saver via external `topUp` or the `ccipReceive` function to handle information updating across chain
     * @param user The address of the saver
     * @param amount the amount of asset wished to be topped up
     */
    function _topUpSavings(address user, uint256 amount, uint64 chainSelector) internal {
        if (chainSelector == s_avalancheChainSelector) {
            s_savingsDetails[user].savingsBalance.wAVAX += amount;
            s_totalChainSavings.wAVAX += amount;
        }
        if (chainSelector == s_optimismChainSelector) {
            s_savingsDetails[user].savingsBalance.wOP += amount;
            s_totalChainSavings.wOP += amount;
        }
        if (chainSelector == s_polygonChainSelector) {
            s_savingsDetails[user].savingsBalance.wMATIC += amount;
            s_totalChainSavings.wMATIC += amount;
        }
    }

    /**
     * @notice Internal reedem usdt function for cosmic providers to reedem their usdt with IOU-usdt tokens
     * @dev Can be called directly by the CP via reedemUsdt or the `ccipReceive` function to handle information updating across chain
     * @param cosmicProvider The address of the cosmic provider
     * @param amount The amount of usdt to be reedemed
     * @param selectedChainSelector The chain selector specifying which of the CP's balances should be deducted
     */
    function _reedemUsdt(address cosmicProvider, uint256 amount, uint256 selectedChainSelector) internal {
        s_cosmicProvider[cosmicProvider].totalUSDT -= amount;
        s_cosmicProvider[cosmicProvider].IOU_USDT -= amount;

        if (selectedChainSelector == s_avalancheChainSelector) {
            if (amount > s_cosmicProvider[cosmicProvider].aUSDT) {
                revert CollectiveCore__InsufficientIouUsdtBalanceForSelectedChain();
            }
            s_cosmicProvider[cosmicProvider].aUSDT -= amount;
        }
        if (selectedChainSelector == s_optimismChainSelector) {
            if (amount > s_cosmicProvider[cosmicProvider].oUSDT) {
                revert CollectiveCore__InsufficientIouUsdtBalanceForSelectedChain();
            }
            s_cosmicProvider[cosmicProvider].oUSDT -= amount;
        }
        if (selectedChainSelector == s_polygonChainSelector) {
            if (amount > s_cosmicProvider[cosmicProvider].pUSDT) {
                revert CollectiveCore__InsufficientIouUsdtBalanceForSelectedChain();
            }
            s_cosmicProvider[cosmicProvider].pUSDT -= amount;
        }
    }

    /**
     * @notice internal break savings function that handles logic of transferring user saved amount after fee deduction
     * @param user The address of the user wishing to break their save.
     */
    function _breakSavings(address user) internal returns (uint256, uint256, uint256) {
        //
        ICollectiveCore.CrossChainAssets memory userSavingBalance = getUserSavingsDetails(user).savingsBalance;

        uint256 interestToAddToPool;
        uint256 avaxBufferAmount;
        uint256 opBufferAmount;

        if (userSavingBalance.wMATIC > 0) {
            uint256 opEthTakenFromUser = (userSavingBalance.wMATIC * POLYGON_DEFAULT_FEE) / 100;
            uint256 opEthToGiveUser = (userSavingBalance.wMATIC * (100 - POLYGON_DEFAULT_FEE)) / 100;

            IERC20(s_wMATIC).approve(address(s_franfranSwap), opEthTakenFromUser);
            interestToAddToPool = s_franfranSwap.swapForUSDT(s_wMATIC, opEthTakenFromUser);

            IERC20(s_wMATIC).transfer(user, opEthToGiveUser);

            s_interestPoolBalance += interestToAddToPool;
            s_UsdtBalances.Polygon += interestToAddToPool;
        }

        if (userSavingBalance.wAVAX > 0) {
            uint256 avaxTakenFromUser = (userSavingBalance.wAVAX * OPTIMISM_DEFAULT_FEE) / 100;
            (, int256 answer,,,) = AggregatorV3Interface(s_avaxPriceFeed).latestRoundData();
            uint256 answerInEighteenDecimals = uint256(answer) * 10e10;
            uint256 estimatedAvaxToBeTakenAsUsdtFromUser = (answerInEighteenDecimals * avaxTakenFromUser) / 10e18;
            avaxBufferAmount = (BUFFER_AMOUNT * estimatedAvaxToBeTakenAsUsdtFromUser) / 100;

            s_interestPoolBalance += interestToAddToPool;
            s_UsdtBalances.Avalanche += avaxBufferAmount;
        }

        if (userSavingBalance.wOP > 0) {
            uint256 opEthTakenFromUser = (userSavingBalance.wOP * OPTIMISM_DEFAULT_FEE) / 100;
            (, int256 answer,,,) = AggregatorV3Interface(s_opEthPriceFeed).latestRoundData();
            uint256 answerInEighteenDecimals = uint256(answer) * 10e10;
            uint256 estimatedOptimismEthToBeTakenAsUsdtFromUser =
                (answerInEighteenDecimals * opEthTakenFromUser) / 10e18;
            opBufferAmount = (BUFFER_AMOUNT * estimatedOptimismEthToBeTakenAsUsdtFromUser) / 100;

            s_interestPoolBalance += interestToAddToPool;
            s_UsdtBalances.Optimism += avaxBufferAmount;
        }

        _resetUserSavingsDetails(user);

        return (interestToAddToPool, avaxBufferAmount, opBufferAmount);
    }

    /**
     * @notice Resets the user savings details
     * @dev Resets the users saving information to default
     * @param user The address of the user
     */
    function _resetUserSavingsDetails(address user) internal {
        s_savingsDetails[user].status = false;
        s_savingsDetails[user].savingsStartTime = 0;
        s_savingsDetails[user].savingsEndTime = 0;
        s_savingsDetails[user].reason = "";

        s_savingsDetails[user].savingsBalance.wAVAX = 0;
        s_savingsDetails[user].savingsBalance.wOP = 0;
        s_savingsDetails[user].savingsBalance.wMATIC = 0;

        s_savingsDetails[user].savingsTarget.wAVAX = 0;
        s_savingsDetails[user].savingsTarget.wOP = 0;
        s_savingsDetails[user].savingsTarget.wMATIC = 0;

        s_savingsDetails[user].withdrawalChainSelector = 0;
    }

    ////////////////////////////////////////////////////
    /////// CROSSS CHAIN FUNCTIONS & HANDLERS /////////
    ////////////////////////////////////////////////////

    /**
     * @notice Sends the cross chain message with the encoded parameters to teh destination chains
     * @param receiverContractAddress The address of the receiving contract on the specified chain
     * @param encodedPayload The encoded payload containing the execution path params
     * @param destinationChainSelector The destination chain selector
     */
    function _sendCrossChainMessage(
        address receiverContractAddress,
        bytes memory encodedPayload,
        uint64 destinationChainSelector
    ) internal {
        Client.EVM2AnyMessage memory cc_message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverContractAddress),
            data: encodedPayload,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 200_000})),
            feeToken: address(s_linkToken)
        });

        uint256 fees = s_router.getFee(destinationChainSelector, cc_message);

        if (fees > s_linkToken.balanceOf(address(this))) {
            revert CollectiveCore__NotEnoughBalanceForCrossChainTransfer();
        }
        s_linkToken.approve(address(s_router), fees);
        s_router.ccipSend(destinationChainSelector, cc_message);
    }

    /**
     * @notice Receives the cross chain message
     * @dev receives the cross chain message and decodes the message path passing the innerPayload to specific handlers
     */
    function _ccipReceive(Client.Any2EVMMessage memory receivedMessage) internal override {
        bytes memory receivedPayload = receivedMessage.data;
        (bytes32 messagePath, bytes memory innerPayload, uint64 sourceChainSelector, address sender) =
            abi.decode(receivedPayload, (bytes32, bytes, uint64, address));

        if (messagePath == s_startavingsPath) {
            _handleStartSavingsMessagePath(sender, innerPayload, sourceChainSelector);
        }
        if (messagePath == s_topUpSavingsPath) {
            _handleTopUpSavingsMessagePath(sender, innerPayload, sourceChainSelector);
        }
        if (messagePath == s_depositUsdtPath) {
            _handleDepositUsdtMessagePath(sender, innerPayload, sourceChainSelector);
        }
        if (messagePath == s_reedemUsdtPath) {
            _handleReedemUsdtMessagePath(sender, innerPayload, sourceChainSelector);
        }
        if (messagePath == s_breakSavingsPath) {
            _handleBreakSavingsMessagePath(sender, innerPayload, sourceChainSelector);
        }
        if (messagePath == s_withdrawSavingsPath) {
            _handleWithdrawSavingsMessagePath(sender, innerPayload, sourceChainSelector);
        }
    }

    //// HANDLERS /////

    /**
     * @notice handles decoding parameters and executing the startSavings function from a source chain
     * @param saver The address of the user
     * @param startSavingsPayload The encoded startSavings Payload
     * @param sourceChainSelector The source chain selector
     */
    function _handleStartSavingsMessagePath(address saver, bytes memory startSavingsPayload, uint64 sourceChainSelector)
        internal
    {
        (
            uint256 amount,
            uint256 startTime,
            uint256 endTime,
            string memory reason,
            uint256[3] memory target,
            uint256 totalExpectedSaveTime,
            uint256 totalSavers
        ) = abi.decode(startSavingsPayload, (uint256, uint256, uint256, string, uint256[3], uint256, uint256));

        s_totalExpectedSaveTime = totalExpectedSaveTime;
        s_totalSavers = totalSavers;
        _startSaving(saver, amount, startTime, endTime, reason, target, sourceChainSelector);
    }

    /**
     * @notice handles decoding parameters and executing the topUpSavings function from a source chain
     * @param saver address of the saver
     * @param topUpSavingsPayload encoded payload for topping up saving
     * @param sourceChainSelector source chain selector
     */
    function _handleTopUpSavingsMessagePath(address saver, bytes memory topUpSavingsPayload, uint64 sourceChainSelector)
        internal
    {
        (uint256 amount) = abi.decode(topUpSavingsPayload, (uint256));
        _topUpSavings(saver, amount, sourceChainSelector);
    }

    /**
     * @notice handles decoding parameters and executing the depositUsdt function from a source chain
     * @param cosmicProvider address of the cosmic provider
     * @param depositUsdtPayload encoded apyload for depositing usdt
     * @param sourceChainSelector source chain selector
     */
    function _handleDepositUsdtMessagePath(
        address cosmicProvider,
        bytes memory depositUsdtPayload,
        uint64 sourceChainSelector
    ) internal {
        (uint256 amount, uint256 unlockPeriod) = abi.decode(depositUsdtPayload, (uint256, uint256));

        s_cosmicProvider[cosmicProvider].totalUSDT += amount;
        s_cosmicProvider[cosmicProvider].IOU_USDT += amount;
        s_cosmicProvider[cosmicProvider].unlockPeriod += unlockPeriod;

        if (sourceChainSelector == s_avalancheChainSelector) {
            s_UsdtBalances.Avalanche += amount;
            s_cosmicProvider[cosmicProvider].aUSDT += amount;
        }
        if (sourceChainSelector == s_optimismChainSelector) {
            s_UsdtBalances.Optimism += amount;
            s_cosmicProvider[cosmicProvider].oUSDT += amount;
        }
        if (sourceChainSelector == s_polygonChainSelector) {
            s_UsdtBalances.Polygon += amount;
            s_cosmicProvider[cosmicProvider].pUSDT += amount;
        }
    }

    /**
     * @notice handles decoding parameters and executing the reededmUsdt function from a source chain
     * @param cosmicProvider address of the cosmic provider
     * @param reedemUsdtPayload encoded payload for reedeming usdt
     */
    function _handleReedemUsdtMessagePath(
        address cosmicProvider,
        bytes memory reedemUsdtPayload,
        uint64 sourceChainSelector
    ) internal {
        (uint256 amount, uint64 selectedChainSelector) = abi.decode(reedemUsdtPayload, (uint256, uint64));
        if (sourceChainSelector == s_avalancheChainSelector) {
            s_UsdtBalances.Avalanche -= amount;
        }
        if (sourceChainSelector == s_optimismChainSelector) {
            s_UsdtBalances.Optimism -= amount;
        }
        if (sourceChainSelector == s_polygonChainSelector) {
            s_UsdtBalances.Polygon -= amount;
        }
        _reedemUsdt(cosmicProvider, amount, selectedChainSelector);
    }

    /**
     * @notice handles decoding parameters and executing the break savings function from a source chain
     * @param user address of the user
     * @param breakSavingsPayload endoded payload for breaking savings
     * @param sourceChainSelector The source chain selector
     */
    function _handleBreakSavingsMessagePath(address user, bytes memory breakSavingsPayload, uint64 sourceChainSelector)
        internal
    {
        (
            uint256 interestAddedToSourcePool,
            uint256 avaxBufferAmount,
            uint256 opBufferAmount,
            uint256 maticBufferAmount,
            uint256 newTotalExpectedSaveTime
        ) = abi.decode(breakSavingsPayload, (uint256, uint256, uint256, uint256, uint256));

        s_totalExpectedSaveTime = newTotalExpectedSaveTime;
        s_interestPoolBalance += interestAddedToSourcePool + avaxBufferAmount + opBufferAmount + maticBufferAmount;
        ICollectiveCore.CrossChainAssets memory userSavingBalance = getUserSavingsDetails(user).savingsBalance;

        if (userSavingBalance.wMATIC > 0) {
            uint256 maticTakenFromUser = (userSavingBalance.wMATIC * POLYGON_DEFAULT_FEE) / 100;
            uint256 maticToGiveUser = (userSavingBalance.wMATIC * (100 - POLYGON_DEFAULT_FEE)) / 100;

            IERC20(s_wMATIC).approve(address(s_franfranSwap), maticTakenFromUser);
            s_franfranSwap.swapForUSDT(s_wMATIC, maticTakenFromUser);

            s_UsdtBalances.Polygon += maticBufferAmount;

            IERC20(s_wMATIC).transfer(user, maticToGiveUser);
        }

        _resetUserSavingsDetails(user);

        if (sourceChainSelector == s_avalancheChainSelector) {
            s_UsdtBalances.Avalanche += interestAddedToSourcePool;
            s_UsdtBalances.Optimism += opBufferAmount;
        }
        if (sourceChainSelector == s_optimismChainSelector) {
            s_UsdtBalances.Optimism += interestAddedToSourcePool;
            s_UsdtBalances.Avalanche += avaxBufferAmount;
        }
    }

    /**
     * @notice handles decoding parameters and executing the withdraw savings function from a source chain
     * @param saver address of the user
     * @param withdrawSavingsPayload endoded payload for withdrawing savings
     * @param sourceChainSelector The source chain selector
     */
    function _handleWithdrawSavingsMessagePath(
        address saver,
        bytes memory withdrawSavingsPayload,
        uint64 sourceChainSelector
    ) internal {
        (uint256 updatedUsdtBalancesFromSourceChain, uint256 interestPoolBalance) =
            abi.decode(withdrawSavingsPayload, (uint256, uint256));

        s_interestPoolBalance = interestPoolBalance;

        if (sourceChainSelector == s_avalancheChainSelector) {
            s_UsdtBalances.Avalanche = updatedUsdtBalancesFromSourceChain;
        }
        if (sourceChainSelector == s_optimismChainSelector) {
            s_UsdtBalances.Optimism = updatedUsdtBalancesFromSourceChain;
        }

        CrossChainAssets memory userBalances = s_savingsDetails[saver].savingsBalance;
        if (userBalances.wMATIC > 0) {
            IERC20(s_wMATIC).transfer(saver, userBalances.wMATIC);
        }

        s_totalChainSavings.wAVAX -= userBalances.wAVAX;
        s_totalChainSavings.wOP -= userBalances.wOP;
        s_totalChainSavings.wMATIC -= userBalances.wMATIC;

        _resetUserSavingsDetails(saver);
    }

    ///////////////////////////////
    ///// GETTER FUNCTIONSS ////////
    ///////////////////////////////

    /// @notice gets the cross chain interest pool balance
    function getInterestPoolBalance() public view returns (uint256) {
        return s_interestPoolBalance;
    }

    /// @notice gets the total expected save time by all users across chain
    function getTotalExpectedSaveTime() public view returns (uint256) {
        return s_totalExpectedSaveTime;
    }

    /// @notice gets the total chain savings by users
    function getTotalChainSavings() public view returns (CrossChainAssets memory) {
        return s_totalChainSavings;
    }

    /// @notice gets the total number of unique savers accross chain
    function getTotalChainSavers() public view returns (uint256) {
        return s_totalSavers;
    }

    /// @notice gets the actual contract usdt balances for all chains
    function getUsdtBalances() public view returns (UsdtBalances memory) {
        return s_UsdtBalances;
    }

    /// @notice gets a users share in the cross chain interest pool based on saving time
    function getUsersShareInInterestPool(address user) public view returns (uint256) {
        if (s_savingsDetails[user].status) {
            uint256 userSavingTime = s_savingsDetails[user].savingsEndTime - s_savingsDetails[user].savingsStartTime;

            uint256 usersInterestShare = (userSavingTime * s_interestPoolBalance) / s_totalExpectedSaveTime;
            return usersInterestShare;
        } else {
            return 0;
        }
    }

    /// @notice returns true if the user has met their saving target
    function getUserMeetsSavingTarget(address user) public view returns (bool) {
        ICollectiveCore.CrossChainAssets memory savingsBalance = s_savingsDetails[user].savingsBalance;
        ICollectiveCore.CrossChainAssets memory savingsTarget = s_savingsDetails[user].savingsTarget;
        if (
            (savingsBalance.wAVAX >= savingsTarget.wAVAX) && (savingsBalance.wMATIC >= savingsTarget.wMATIC)
                && (savingsBalance.wOP >= savingsTarget.wOP)
        ) {
            return true;
        } else {
            return false;
        }
    }

    /// @notice gets the users saving status
    function getUserSavingStatus(address user) public view returns (bool) {
        return s_savingsDetails[user].status;
    }

    /// @notice gets the users svaing balance
    function getUserSavingBalance(address user) public view returns (ICollectiveCore.CrossChainAssets memory) {
        return s_savingsDetails[user].savingsBalance;
    }

    /// @notice gets the users saving time in seconds
    function getUserSavingTime(address user) public view returns (uint256) {
        return s_savingsDetails[user].savingsEndTime - s_savingsDetails[user].savingsStartTime;
    }

    /// @notice gets the users savings details
    function getUserSavingsDetails(address user) public view returns (SavingDetails memory) {
        return s_savingsDetails[user];
    }

    /// @notice gets the current block timestamp
    function getBlockTimeStamp() public view returns (uint256) {
        return block.timestamp;
    }

    /// @notice getsthe cosmic provider details
    function getCosmicProviderDetails(address cosmicProvider) public view returns (CosmicProvider memory) {
        return s_cosmicProvider[cosmicProvider];
    }

    /// @notice gets the cosmic providers unlock period for withdrawal of deposited USDT
    function getUnlockPeriod(address cosmicProvider) public view returns (uint256) {
        return s_cosmicProvider[cosmicProvider].unlockPeriod;
    }

    ///////////////////////////
    ///// ONE TIME FUNCTION ////
    ///////////////////////////

    /**
     * @notice updates the contract address forthe destination chains
     * @param avalancheContractAddress Avalanche collectiveCore contract address
     * @param optimismContractAddress Optimsim collectiveCore contract address
     */
    function updateCollectiveCoreContractAddressForOtherChains_(
        address avalancheContractAddress,
        address optimismContractAddress
    ) external {
        // if (locked) {
        //     revert CollectiveCore__CannotUpdateDestinationChainContractAddress();
        // }
        // locked = true;
        s_avalancheContractAddress = avalancheContractAddress;
        s_optimismContractAddress = optimismContractAddress;
    }

    ///////////////////////////
    ////// MODIFIERS //////////
    ///////////////////////////

    /// @notice checks if the deposited asset is supported
    modifier checkAssetSupport(address asset) {
        if (!s_supportedAsset[asset]) {
            revert CollectiveCore__AssetNotSupported();
        }
        _;
    }

    /// @notice checks that the amount sent isnt zero
    modifier checkAmountIsntZero(uint256 amount) {
        if (amount <= 0) {
            revert CollectiveCore__AmountMustBeGreaterThanZero();
        }
        _;
    }

    /// @notice checks if the users saving time has elapsed
    modifier checkIfUserSavingTimeHasExpired(address user) {
        uint256 savingsEndTime = getUserSavingsDetails(user).savingsEndTime;
        if (block.timestamp > savingsEndTime) {
            revert CollectiveCore__SavingsTimeHasPassed();
        }
        _;
    }

    /// @notice checks if the users saving target is greater than or equal to amount on specified chain
    modifier IndividualSavingsTargetGreaterThanOrEqualToSavingAmount(uint256[3] memory target, uint256 amount) {
        uint256 polygonTarget = 2;
        if (target[polygonTarget] < amount) {
            revert CollectiveCore__TargetAmountEqualsZero(polygonTarget);
        }
        _;
    }

    /// @notice checks that the saving time set by user is greater than zero.
    modifier checkSavingTimeIsNotZero(uint256 time) {
        if (time <= 0) {
            revert CollectiveCore__SavingsTimeIssZero();
        }
        _;
    }

    /// @notice checks to see if the users withdrawal time has arrived
    modifier checkUserWithdrawalTimeHasArrived(address user) {
        uint256 savingsEndTime = getUserSavingsDetails(user).savingsEndTime;
        if (block.timestamp < savingsEndTime) {
            revert CollectiveCore__WithdrawalTimeHasntArrived();
        }
        _;
    }

    /// @notice checks to see if all requirements to break save are valid
    modifier checkUserCanBreakSave(address user) {
        if (!getUserSavingsDetails(user).status) {
            revert CollectiveCore__CanOnlyBreakAnExistingSaving();
        }

        bool targetMet = getUserMeetsSavingTarget(user);
        if ((block.timestamp > getUserSavingsDetails(user).savingsEndTime) && targetMet) {
            revert CollectiveCore__SaveCanBeWithdrawnSuccessfully();
        }

        _;
    }

    /// @notice checks to see if all requirements to withdraw succesfully are valid
    modifier checkUserCanWithdrawSuccesfully(address user) {
        if (!getUserSavingsDetails(user).status) {
            revert CollectiveCore__CanOnlyWithdrawAnExistingSaving();
        }
        if (block.timestamp < getUserSavingsDetails(user).savingsEndTime) {
            revert CollectiveCore__WithdrawalTimeHasntArrived();
        }
        bool targetMet = getUserMeetsSavingTarget(user);
        if (!targetMet) {
            revert CollectiveCore__UserDidNotMeetSavingsTarget();
        }
        _;
    }
}
