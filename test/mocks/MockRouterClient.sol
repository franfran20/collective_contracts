// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";

/**
 * @title Chainlink MockRouterClient.
 * @author FranFran.
 * @notice A contract that mocks chainlink ccip router functionality.
 */
contract MockRouterClient {
    uint256 messageIdCounter;
    uint256 GENERAL_LINK_FEE = 0.01 ether;

    function ccipSend(uint64, Client.EVM2AnyMessage calldata message) external payable returns (bytes32) {
        // craft message id
        bytes32 messageId = keccak256(abi.encodePacked(msg.sender, messageIdCounter));
        messageIdCounter++;

        address destinationContractAddress = abi.decode(message.receiver, (address));
        (,, uint64 sourceChainSelector, address msgSender) = abi.decode(message.data, (bytes32, bytes, uint64, address));

        Client.Any2EVMMessage memory messageToSend = Client.Any2EVMMessage({
            messageId: messageId,
            sourceChainSelector: sourceChainSelector,
            sender: abi.encode(msgSender),
            data: message.data,
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        (bool success,) =
            destinationContractAddress.call(abi.encodeWithSelector(CCIPReceiver.ccipReceive.selector, messageToSend));
        require(success, "Cross Chain Call Failed!");

        return messageId;
    }

    function getFee(uint64, Client.EVM2AnyMessage memory) external view returns (uint256) {
        return GENERAL_LINK_FEE;
    }
}
