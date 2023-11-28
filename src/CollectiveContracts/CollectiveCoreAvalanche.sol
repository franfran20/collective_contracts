// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

// my imports
import {ICollectiveCore} from "../interfaces/ICollectiveCore.sol";

// chainlink imports
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {LinkTokenInterface} from "@chainlink/contracts-ccip/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {AggregatorV3Interface} from "@chainlink/contracts-ccip/src/v0.4/interfaces/AggregatorV3Interface.sol";

// oz's imports
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {FranFranSwap} from "../../test/mocks/FranFranSwap.sol";

/**
 * @title Collective Core Contract
 * @author fRaNFrAn
 * @notice Collective Core Contract For AVALANCHE
 */
contract CollectiveCoreAvalanche is ICollectiveCore, CCIPReceiver, Ownable {
    IRouterClient private s_router;
    LinkTokenInterface private s_linkToken;
    FranFranSwap public s_franfranSwap;

    mapping(address user => SavingDetails) private s_savingsDetails;
    mapping(address asset => bool supported) private s_supportedAsset;
    /**
     * @dev chain id to the chain selectors specified by chainlink ccip. see chainlink docs for chain selectors
     */
    mapping(uint256 chainId => uint64 chainSelector) private s_chainSelectors;

    /**
     * @notice cosmic provider details
     */
    mapping(address cosmicProvider => CosmicProvider) private s_cosmicProvider;

    /**
     * @notice contracts usdt balances across chain
     */
    UsdtBalances private s_UsdtBalances;

    /**
     * @notice keeps track of the amount saved on each chain
     */

    CrossChainAssets private s_totalChainSavings;

    /**
     * @dev wrapped AVAX token and Collective Token
     */
    address public s_wAVAX;
    address public s_usdt;

    /**
     * @notice priceFeedAddresses
     */
    address public s_avaxPriceFeed;
    address public s_opEthPriceFeed;
    address public s_maticPriceFeed;

    /**
     * @dev the contract Addresses of the collective contract on the optimism and polygon network.
     */
    address private s_optimismContractAddress;
    address private s_polygonContractAddress;

    /**
     * @dev The chain selectors specified by chainlink for the following chains.
     * see https://docs.chain.link/ccip/supported-networks#overview for more details
     */
    uint64 s_avalancheChainSelector = 14767482510784806043;
    uint64 s_optimismChainSelector = 2664363617261496610;
    uint64 s_polygonChainSelector = 12532609583862916517;

    // @notice unlock period for withdrawal after depositing usdt as a CP
    uint256 constant UNLOCK_PERIOD = 3 hours;

    uint256 s_interestPoolBalance;
    uint256 public s_totalExpectedSaveTime;
    uint256 s_totalSavers;

    /**
     * @notice protocol fees per chain on breaking save
     * @dev I'm exaggerating the percentage to see the results in tests
     */
    uint256 public constant AVALANCHE_DEFAULT_FEE = 25;
    uint256 public constant OPTIMISM_DEFAULT_FEE = 20;
    uint256 public constant POLYGON_DEFAULT_FEE = 30;

    uint256 public constant BUFFER_AMOUNT = 95;

    /**
     * @notice The function path id for cross chain interaction.
     * @dev This allows the chainlink `_ccipReceive` function to know what execution path it should follow e.g startSavings, withdrawSavings etc.
     * Its basically the keccak256 hash of the function name that was called on the source Contract.
     */
    bytes32 constant s_startavingsPath = keccak256("startSavings");
    bytes32 constant s_topUpSavingsPath = keccak256("topUpSavings");
    bytes32 constant s_depositUsdtPath = keccak256("depositUSDT");
    bytes32 constant s_reedemUsdtPath = keccak256("reedemUSDT");
    bytes32 constant s_breakSavingsPath = keccak256("breakSavings");
    bytes32 constant s_withdrawSavingsPath = keccak256("withdrawSavings");

    /**
     *
     * @param asset The address of the CLT tokens and wrapped AVAX token
     * @param router The address of the ccip router on Avalanche
     * @param link The address of the link token on Avalanche
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
    ) Ownable(msg.sender) CCIPReceiver(router) {
        s_wAVAX = asset;

        s_supportedAsset[asset] = true;

        s_router = IRouterClient(router);
        s_linkToken = LinkTokenInterface(link);
        s_usdt = usdt;

        s_avaxPriceFeed = avaxPriceFeed;
        s_opEthPriceFeed = opEthPriceFeed;
        s_maticPriceFeed = maticPriceFeed;

        s_franfranSwap = FranFranSwap(franfranSwap);
    }

    /////// EXTERNAL FUNCTIONS ///////

    /**
     * @inheritdoc ICollectiveCore
     * @notice Checks whether the asset is supported, checks that the saving amount isnt zero, checks the individual savings target is greater than or equal to saving amount
     */
    function startSavings(address asset, uint256 amount, uint256 time, string memory reason, uint256[3] memory target)
        external
        checkAssetSupport(asset)
        checkAmountIsntZero(amount)
        IndividualSavingsTargetGreaterThanOrEqualToSavingAmount(target, amount)
        checkSavingTimeIsNotZero(time)
    {
        bool success = IERC20(asset).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert CollectiveCore__ERC20TransferFromFailed();
        }

        // Also include test for time saved, total savers and amount saved per chain

        _startSaving(
            msg.sender, amount, block.timestamp, block.timestamp + time, reason, target, s_avalancheChainSelector
        );

        s_totalExpectedSaveTime += time;
        s_totalSavers += 1;

        bytes memory innerPayload = abi.encode(
            amount, block.timestamp, block.timestamp + time, reason, target, s_totalExpectedSaveTime, s_totalSavers
        );
        bytes memory encodedPayload = abi.encode(s_startavingsPath, innerPayload, s_avalancheChainSelector, msg.sender);

        _sendCrossChainMessage(s_optimismContractAddress, encodedPayload, s_optimismChainSelector);
        _sendCrossChainMessage(s_polygonContractAddress, encodedPayload, s_polygonChainSelector);
    }

    /**
     * @inheritdoc ICollectiveCore
     * @dev checks asset support, amount != 0, user saving time still valid?
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

        _topUpSavings(msg.sender, amount, s_avalancheChainSelector);

        bytes memory innerPayload = abi.encode(amount);
        bytes memory encodedPayload = abi.encode(s_topUpSavingsPath, innerPayload, s_avalancheChainSelector, msg.sender);

        _sendCrossChainMessage(s_optimismContractAddress, encodedPayload, s_optimismChainSelector);
        _sendCrossChainMessage(s_polygonContractAddress, encodedPayload, s_polygonChainSelector);
    }

    /**
     * @inheritdoc ICollectiveCore
     * @dev chchecks that the deposit amount is > 0
     */
    function depositUSDT(uint256 amount) external checkAmountIsntZero(amount) {
        if (IERC20(s_usdt).balanceOf(msg.sender) < amount) {
            revert CollectiveCore__InsufficientUsdtBalance();
        }

        (bool success) = IERC20(s_usdt).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert CollectiveCore__ERC20TransferFromFailed();
        }

        s_cosmicProvider[msg.sender].aUSDT += amount;
        s_cosmicProvider[msg.sender].totalUSDT += amount;
        s_cosmicProvider[msg.sender].IOU_USDT += amount;
        s_cosmicProvider[msg.sender].unlockPeriod = block.timestamp + UNLOCK_PERIOD;

        s_UsdtBalances.Avalanche += amount;

        bytes memory innerPayload = abi.encode(amount, block.timestamp + UNLOCK_PERIOD);
        bytes memory encodedPayload = abi.encode(s_depositUsdtPath, innerPayload, s_avalancheChainSelector, msg.sender);

        _sendCrossChainMessage(s_optimismContractAddress, encodedPayload, s_optimismChainSelector);
        _sendCrossChainMessage(s_polygonContractAddress, encodedPayload, s_polygonChainSelector);
    }

    /**
     * @inheritdoc ICollectiveCore
     * @notice checks that the amount to reedem is > 0
     */
    function reedemUSDT(uint256 amount, uint64 selectedChainSelector) external checkAmountIsntZero(amount) {
        if (amount > s_cosmicProvider[msg.sender].totalUSDT) {
            revert CollectiveCore__InsufficientIouUsdtBalance();
        }
        if (block.timestamp < s_cosmicProvider[msg.sender].unlockPeriod) {
            revert CollectiveCore__UnlockPeriodHasntArrived();
        }
        if (s_UsdtBalances.Avalanche < amount) {
            revert CollectiveCore__ContractDoesntHaveSufficientUsdtToReedemOnThisChain();
        }

        IERC20(s_usdt).transfer(msg.sender, amount);
        s_UsdtBalances.Avalanche -= amount;

        _reedemUsdt(msg.sender, amount, selectedChainSelector);

        bytes memory innerPayload = abi.encode(amount, selectedChainSelector);
        bytes memory encodedPayload = abi.encode(s_reedemUsdtPath, innerPayload, s_avalancheChainSelector, msg.sender);

        _sendCrossChainMessage(s_optimismContractAddress, encodedPayload, s_optimismChainSelector);
        _sendCrossChainMessage(s_polygonContractAddress, encodedPayload, s_polygonChainSelector);
    }

    /**
     * @inheritdoc ICollectiveCore
     * @notice checks if the user can break their save
     */
    function breakSavings() external checkUserCanBreakSave(msg.sender) {
        uint256 userSavingTime =
            s_savingsDetails[msg.sender].savingsEndTime - s_savingsDetails[msg.sender].savingsStartTime;
        s_totalExpectedSaveTime -= userSavingTime;

        (uint256 interestToAddToPool, uint256 opBufferAmount, uint256 maticBufferAmount) = _breakSavings(msg.sender);
        uint256 avaxBufferAmountNotInUse = 0;

        bytes memory innerPayload = abi.encode(
            interestToAddToPool, avaxBufferAmountNotInUse, opBufferAmount, maticBufferAmount, s_totalExpectedSaveTime
        );
        bytes memory encodedPayload = abi.encode(s_breakSavingsPath, innerPayload, s_avalancheChainSelector, msg.sender);

        _sendCrossChainMessage(s_optimismContractAddress, encodedPayload, s_optimismChainSelector);
        _sendCrossChainMessage(s_polygonContractAddress, encodedPayload, s_polygonChainSelector);
    }

    function withdrawSavings() external checkUserCanWithdrawSuccesfully(msg.sender) {
        if (s_savingsDetails[msg.sender].withdrawalChainSelector != s_avalancheChainSelector) {
            revert CollectiveCore__CannotWithdrawOnThisChain();
        }

        uint256 usersShareInInterestPool = getUsersShareInInterestPool(msg.sender);
        if (IERC20(s_usdt).balanceOf(address(this)) < usersShareInInterestPool) {
            revert CollectiveCore__ContractDoesntHaveSufficientUsdtToFulFillWithdrawal();
        }

        if (usersShareInInterestPool > 0) IERC20(s_usdt).transfer(msg.sender, usersShareInInterestPool);

        uint256 usersChainBalance = s_savingsDetails[msg.sender].savingsBalance.wAVAX;
        if (usersChainBalance > 0) IERC20(s_wAVAX).transfer(msg.sender, usersChainBalance);

        s_interestPoolBalance -= usersShareInInterestPool;
        s_UsdtBalances.Avalanche -= usersShareInInterestPool;
        s_totalChainSavings.wAVAX -= usersChainBalance;

        _resetUserSavingsDetails(msg.sender);

        bytes memory innerPayload = abi.encode(usersShareInInterestPool);
        bytes memory encodedPayload =
            abi.encode(s_withdrawSavingsPath, innerPayload, s_avalancheChainSelector, msg.sender);

        _sendCrossChainMessage(s_optimismContractAddress, encodedPayload, s_optimismChainSelector);
        _sendCrossChainMessage(s_polygonContractAddress, encodedPayload, s_polygonChainSelector);
    }

    /////////////////////////////////
    /////// GROUP RELATED STUFFF ////
    ////////////////////////////////
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
     * @param chainSelector Chain selector specified from chainlink
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

        // keep track of totalsavers, savers on each chain, and amount saved on each chain

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
     * @notice Internal top up savings function for updating users saving information
     * @dev Can be called directly by the saver or the `ccipReceive` function to handle information updating across chain
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
     * @dev Can be called directly by the saver or the `ccipReceive` function to handle information updating across chain
     * @param cosmicProvider The address of the cosmic provider
     * @param amount The amount of usdt to be reedemed
     * @param selectedChainSelector the chai selector specifying which of the CP's balances should be deducted
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
     * @notice internal function that checks if theres an interest to be collected on this chain and goes ahead to break the savings
     * @param user The address of the user wishing to break their save.
     */
    function _breakSavings(address user) internal returns (uint256, uint256, uint256) {
        //
        ICollectiveCore.CrossChainAssets memory userSavingBalance = getUserSavingsDetails(user).savingsBalance;

        uint256 interestToAddToPool;
        uint256 opBufferAmount;
        uint256 maticBufferAmount;

        if (userSavingBalance.wAVAX > 0) {
            // get amount to transfer user and amount protocol would take
            uint256 avaxTakenFromUser = (userSavingBalance.wAVAX * AVALANCHE_DEFAULT_FEE) / 100;
            uint256 avaxToGiveUser = (userSavingBalance.wAVAX * (100 - AVALANCHE_DEFAULT_FEE)) / 100;

            // approve tokens for protocol for swap to usdt
            IERC20(s_wAVAX).approve(address(s_franfranSwap), avaxTakenFromUser);
            interestToAddToPool = s_franfranSwap.swapForUSDT(s_wAVAX, avaxTakenFromUser);

            // transfer user the amount user has after fee taken
            IERC20(s_wAVAX).transfer(user, avaxToGiveUser);

            // increase the interest pool balance
            s_interestPoolBalance += interestToAddToPool;
            s_UsdtBalances.Avalanche += interestToAddToPool;
        }

        if (userSavingBalance.wOP > 0) {
            uint256 optimismEthTakenFromUser = (userSavingBalance.wOP * OPTIMISM_DEFAULT_FEE) / 100;
            (, int256 answer,,,) = AggregatorV3Interface(s_opEthPriceFeed).latestRoundData();
            uint256 answerInEighteenDecimals = uint256(answer) * 10e10;
            uint256 estimatedOptimismEthToBeTakenAsUsdtFromUser =
                (answerInEighteenDecimals * optimismEthTakenFromUser) / 10e18;
            opBufferAmount = (BUFFER_AMOUNT * estimatedOptimismEthToBeTakenAsUsdtFromUser) / 100;

            s_interestPoolBalance += opBufferAmount;
            s_UsdtBalances.Optimism += opBufferAmount;
        }

        if (userSavingBalance.wMATIC > 0) {
            uint256 maticTakenFromUser = (userSavingBalance.wMATIC * POLYGON_DEFAULT_FEE) / 100;
            (, int256 answer,,,) = AggregatorV3Interface(s_maticPriceFeed).latestRoundData();
            uint256 answerInEighteenDecimals = uint256(answer) * 10e10;
            uint256 estimatedMaticToBeTakenAsUsdtFromUser = (answerInEighteenDecimals * maticTakenFromUser) / 10e18;
            maticBufferAmount = (BUFFER_AMOUNT * estimatedMaticToBeTakenAsUsdtFromUser) / 100;

            s_interestPoolBalance += maticBufferAmount;
            s_UsdtBalances.Polygon += maticBufferAmount;
        }

        _resetUserSavingsDetails(user);

        return (interestToAddToPool, opBufferAmount, maticBufferAmount);
    }

    /**
     * @notice Resets the user savings details
     */
    function _resetUserSavingsDetails(address user) internal {
        // regular details
        s_savingsDetails[user].status = false;
        s_savingsDetails[user].savingsStartTime = 0;
        s_savingsDetails[user].savingsEndTime = 0;
        s_savingsDetails[user].reason = "";

        // balance details
        s_savingsDetails[user].savingsBalance.wAVAX = 0;
        s_savingsDetails[user].savingsBalance.wOP = 0;
        s_savingsDetails[user].savingsBalance.wMATIC = 0;

        // saving Target
        s_savingsDetails[user].savingsTarget.wAVAX = 0;
        s_savingsDetails[user].savingsTarget.wOP = 0;
        s_savingsDetails[user].savingsTarget.wMATIC = 0;

        s_savingsDetails[user].withdrawalChainSelector = 0;
    }

    /**
     * @notice Sends the cc message with the encoded params
     * @param receiverContractAddress The address of the receiving contract on the specified chain
     * @param encodedPayload The encoded payload containing the execution path params
     * @param destinationChainSelector The destination chain selector specified by chainlink
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
     *
     * @notice decodes the payload sent in the message from the source chain and handles execution based on the message path
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

    /**
     * @notice handles decoding and executing the startSavings function from a source chain
     * @param startSavingsPayload The encoded startSavings Payload
     * @param sourceChainSelector The source chain selector for the function call
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
     * @notice handles decoding and executing the topUpSavings function from a source chain
     * @param saver address of the saver
     * @param topUpSavingsPayload encoded apyload for topping up saving
     * @param sourceChainSelector source chain selector
     */
    function _handleTopUpSavingsMessagePath(address saver, bytes memory topUpSavingsPayload, uint64 sourceChainSelector)
        internal
    {
        (uint256 amount) = abi.decode(topUpSavingsPayload, (uint256));
        _topUpSavings(saver, amount, sourceChainSelector);
    }

    /**
     * @notice handles decoding and executing the depositusdt function called by a cosmic provider
     * @param cosmicProvider address of the cosmic provider
     * @param depositUsdtPayload encoded apyload for topping up saving
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
     * @notice handles decoding and executing the reededmUsdt function called by a cosmic provider
     * @param cosmicProvider address of the cosmic provider
     * @param reedemUsdtPayload encoded apyload for topping up saving
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
            s_UsdtBalances.Optimism -= amount; /////
        }
        if (sourceChainSelector == s_polygonChainSelector) {
            s_UsdtBalances.Polygon -= amount;
        }
        _reedemUsdt(cosmicProvider, amount, selectedChainSelector);
    }

    /**
     * @notice handles executing the break savings function
     * @param user address of the user
     */
    function _handleBreakSavingsMessagePath(address user, bytes memory breakSavingsPayload, uint64 sourceChainSelector)
        internal
    {
        // note the interest added to source pool will cancel out one of the zero buffered amount
        // e.g if the message came from polygin the maticBufferAmount will be zero while the interestAddedToSourcePool would
        // be the actual interets added to the polygon pool chain
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

        if (userSavingBalance.wAVAX > 0) {
            // get amount to transfer user and amount protocol would take
            uint256 avaxTakenFromUser = (userSavingBalance.wAVAX * AVALANCHE_DEFAULT_FEE) / 100;
            uint256 avaxToGiveUser = (userSavingBalance.wAVAX * (100 - AVALANCHE_DEFAULT_FEE)) / 100;

            // approve tokens for protocol for swap to usdt
            IERC20(s_wAVAX).approve(address(s_franfranSwap), avaxTakenFromUser);
            s_franfranSwap.swapForUSDT(s_wAVAX, avaxTakenFromUser);

            s_UsdtBalances.Avalanche += avaxBufferAmount;
            // transfer user the amount user has after fee taken
            IERC20(s_wAVAX).transfer(user, avaxToGiveUser);
        }

        _resetUserSavingsDetails(user);

        if (sourceChainSelector == s_optimismChainSelector) {
            s_UsdtBalances.Optimism += interestAddedToSourcePool;
            s_UsdtBalances.Polygon += maticBufferAmount;
        }
        if (sourceChainSelector == s_polygonChainSelector) {
            s_UsdtBalances.Polygon += interestAddedToSourcePool;
            s_UsdtBalances.Optimism += opBufferAmount;
        }
    }

    function _handleWithdrawSavingsMessagePath(address saver, bytes memory withdrawSavingsPayload, uint64) internal {
        uint256 usersShareInInterestPool = abi.decode(withdrawSavingsPayload, (uint256));

        // transfer them their balance of this chain
        uint256 userBalanceOnThisChain = s_savingsDetails[saver].savingsBalance.wAVAX;
        if (userBalanceOnThisChain > 0) {
            IERC20(s_wAVAX).transfer(saver, userBalanceOnThisChain);
        }

        // stopped here!!!
        s_interestPoolBalance -= usersShareInInterestPool;
        s_UsdtBalances.Avalanche -= usersShareInInterestPool;
        s_totalChainSavings.wAVAX -= userBalanceOnThisChain;

        _resetUserSavingsDetails(saver);
    }

    ///////////////////////////
    ///// GETTER FUNCTIONSS ////////
    ///////////////////////////

    function getInterestPoolBalance() public view returns (uint256) {
        return s_interestPoolBalance;
    }

    function getTotalExpectedSaveTime() public view returns (uint256) {
        return s_totalExpectedSaveTime;
    }

    function getTotalChainSavings() public view returns (CrossChainAssets memory) {
        return s_totalChainSavings;
    }

    /**
     * @notice gets the users share in the cross chain interest pool
     */
    function getUsersShareInInterestPool(address user) public view returns (uint256) {
        if (s_savingsDetails[user].status) {
            uint256 userSavingTime = s_savingsDetails[user].savingsEndTime - s_savingsDetails[user].savingsStartTime;

            uint256 usersInterestShare = (userSavingTime * s_interestPoolBalance) / s_totalExpectedSaveTime;
            return usersInterestShare;
        } else {
            return 0;
        }
    }

    /**
     * @notice returns true if the user has met their saving target
     */
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

    /**
     * @notice gets the user svaings status
     */
    function getUserSavingStatus(address user) public view returns (bool) {
        return s_savingsDetails[user].status;
    }

    function getUserSavingBalance(address user) public view returns (ICollectiveCore.CrossChainAssets memory) {
        return s_savingsDetails[user].savingsBalance;
    }

    function getUserSavingTime(address user) public view returns (uint256) {
        return s_savingsDetails[user].savingsEndTime - s_savingsDetails[user].savingsStartTime;
    }

    /**
     * @notice get user savings details
     */

    function getUserSavingsDetails(address user) public view returns (SavingDetails memory) {
        return s_savingsDetails[user];
    }

    /**
     * @notice get cosmic provider details
     */
    function getCosmicProviderDetails(address cosmicProvider) public view returns (CosmicProvider memory) {
        return s_cosmicProvider[cosmicProvider];
    }

    /**
     * @notice get unlock period
     */
    function getUnlockPeriod(address cosmicProvider) public view returns (uint256) {
        return s_cosmicProvider[cosmicProvider].unlockPeriod;
    }

    /**
     * @notice gets the usdt balances for all contracts
     */
    function getUsdtBalances() public view returns (UsdtBalances memory) {
        return s_UsdtBalances;
    }

    ///////////////////////////
    ///// ADMIN FUNCTIONS ////
    ///////////////////////////

    function updateCollectiveCoreContractAddressForOtherChains_(
        address optimismContractAddress,
        address polygonContractAddress
    ) external {
        s_optimismContractAddress = optimismContractAddress;
        s_polygonContractAddress = polygonContractAddress;
    }

    ///////////////////////////
    ////// MODIFIERS //////////
    ///////////////////////////

    /**
     * @notice checks if the asset sent is supported
     */
    modifier checkAssetSupport(address asset) {
        if (!s_supportedAsset[asset]) {
            revert CollectiveCore__AssetNotSupported();
        }
        _;
    }

    modifier checkAmountIsntZero(uint256 amount) {
        if (amount <= 0) {
            revert CollectiveCore__AmountMustBeGreaterThanZero();
        }
        _;
    }

    modifier checkIfUserSavingTimeHasExpired(address user) {
        uint256 savingsEndTime = getUserSavingsDetails(user).savingsEndTime;
        if (block.timestamp > savingsEndTime) {
            revert CollectiveCore__SavingsTimeHasPassed();
        }
        _;
    }

    /**
     * @notice checks if the individual saving target is greater than or equal to the savings amount
     */
    modifier IndividualSavingsTargetGreaterThanOrEqualToSavingAmount(uint256[3] memory target, uint256 amount) {
        for (uint256 i = 0; i < target.length; i++) {
            if (target[i] < amount) {
                revert CollectiveCore__TargetAmountEqualsZero(i);
            }
        }
        _;
    }

    /**
     * @notice checks that the saving time is greater than zero
     */
    modifier checkSavingTimeIsNotZero(uint256 time) {
        if (time <= 0) {
            revert CollectiveCore__SavingsTimeIssZero();
        }
        _;
    }

    /**
     * @notice checks that the users saving time has passed else: revert
     */

    modifier checkUserWithdrawalTimeHasArrived(address user) {
        uint256 savingsEndTime = getUserSavingsDetails(user).savingsEndTime;
        if (block.timestamp < savingsEndTime) {
            revert CollectiveCore__WithdrawalTimeHasntArrived();
        }
        _;
    }

    /**
     * @notice checks to see if the user can break their save if they cant it should revert because the save can be succesfully withdrawn
     */
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
