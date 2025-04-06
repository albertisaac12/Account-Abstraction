// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_SUCCESS, SIG_VALIDATION_FAILED} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract MinimalAccount is IAccount, Ownable {
    /*
        struct PackedUserOperation {
        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        bytes32 accountGasLimits;
        uint256 preVerificationGas;
        bytes32 gasFees;
        bytes paymasterAndData; // if paymaster is setUp we will send
        bytes signature;
    }
    
    
     */

    error MinimalAccount_NotFromEntryPoint();
    error MinimalAccount_NotFromEntryPointOrOwner();
    error MinimalAccount_CallFailed(bytes);

    IEntryPoint private immutable i_entryPoint;

    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint))
            revert MinimalAccount_NotFromEntryPoint();
        _;
    }

    modifier requireFromEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner())
            revert MinimalAccount_NotFromEntryPointOrOwner();
        _;
    }

    constructor(address _i_entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(_i_entryPoint);
    }

    /// @dev This function will validate the userOp basically like a signature verification
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external requireFromEntryPoint returns (uint256 validationData) {
        validationData = _validateSignature(userOp, userOpHash);

        _payRefund(missingAccountFunds);
    }

    // EIP-191 version of signed hash
    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal view returns (uint256 validationData) {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            userOpHash
        );

        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);

        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }

        return SIG_VALIDATION_SUCCESS;
    }

    function _payRefund(uint256 missingAccountFunds) internal {
        (bool success, ) = payable(address(i_entryPoint)).call{
            value: missingAccountFunds,
            gas: type(uint256).max
        }("");

        (success);
    }

    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }

    /*//////////////////////////////////////////////////////////////
                                EXECUTE
    //////////////////////////////////////////////////////////////*/

    function execute(
        address dest,
        uint256 value,
        bytes calldata funcData
    ) external requireFromEntryPointOrOwner {
        (bool success, bytes memory result) = dest.call{value: value}(funcData);
        if (!success) revert MinimalAccount_CallFailed(result);
    }

    receive() external payable {}
}
