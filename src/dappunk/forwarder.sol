// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC2771Forwarder} from "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Logic Contract for Forwarder Execution with Role-Based Access and Signature Management
/// @dev This contract allows execution of forwarder requests with specific signature management,
///         native and custom call enablement, and deprication functionality.
/// @dev Inherits ERC2771Forwarder for meta-transactions, AccessControl for role-based permissions,
///      and ReentrancyGuard for preventing reentrancy attacks.
contract logic is ERC2771Forwarder, AccessControl, ReentrancyGuard {
    /// @dev Role for managing signatures and native/custom enablement.
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @dev Flag to indicate if the contract is deprecated.
    bool public depricated;

    /// @dev Mapping to enable specific signatures with data length.
    mapping(bytes4 => mapping(uint256 => bool)) public signatureEnabler;

    /// @dev Mapping to enable native function calls.
    mapping(bytes4 => bool) public nativeEnabler;

    /// @dev Mapping to enable custom calls for custom gifting signatures.
    mapping(bytes4 => bool) public customEnabler;

    /// @dev Errors for different invalid operations.

    /// @dev Error thrown when functions are called and contract is depricated.
    error isDepricated();

    /// @dev Error thrown when trying to delete already deleted function signature.
    error signatureDisabled();

    /// @dev Error thrown when trying to delete already deleted native function signature.
    error nativeSignatureDisabled();

    /// @dev Error thrown when trying to delete already deleted custom gifting function signature.
    error customSignatureDisabled();

    /// @dev Error thrown when call made to a unrecogonised function.
    error invalidRequest();

    /// @dev Error thrown when same signature is being added.
    error signatureAlreadyPresent();

    /// @dev Error thrown when same Native signature is being added.
    error nativeSignatureAlreadyPresent();

    /// @dev Error thrown when same custom gifting signature is being added.
    error customSignatureAlreadyPresent();

    /// @dev Error thrown native Enabler is false for the function signature.
    error callNotAllowed();

    /// @dev Events for tracking operations in the contract.

    /// @dev Emitted when a call is executed through the forwarder contract.
    event callExecuted(address indexed to, address indexed caller);

    /// @dev Emitted when a new function signature is added to the `signatureEnabler` mapping.
    event signatureAdded(bytes4 indexed signature);

    /// @dev Emitted when a function signature is removed from the `signatureEnabler` mapping.
    event signatureDeleted(bytes4 indexed signature);

    /// @dev Emitted when a new function signature is added to the `nativeEnabler` mapping.
    event nativeSignatureAdded(bytes4 indexed signature);

    /// @dev Emitted when a function signature is removed from the `nativeEnabler` mapping.
    event nativeSignatureDeleted(bytes4 indexed signature);

    /// @dev Emitted when a new function signature is added to the `customEnabler` mapping.
    event customSignatureAdded(bytes4 indexed signature);

    /// @dev Emitted when a function signature is removed from the `customEnabler` mapping.
    event customSignatureDeleted(bytes4 indexed signature);

    /// @dev Initializes the contract with a domain for meta-transactions.
    /// @param domain The domain string used for EIP-712 typed data.
    constructor(string memory domain) ERC2771Forwarder(domain) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);

        // Add pre-defined signatures with data lengths
        signatureEnabler[0x6b92eaa9][676] = true; // mintNative
        signatureEnabler[0x0c6233a4][676] = true; // mintApi
        signatureEnabler[0xc188ef0a][676] = true; // mintToken
        signatureEnabler[0xf8ac7cef][644] = true; // verifyVoucher

        signatureEnabler[0xf448e169][868] = true; // purchaseNative
        signatureEnabler[0x1fa0db1f][868] = true; // purchasePunk
        signatureEnabler[0x4bca327b][868] = true; // purchaseUSD
        signatureEnabler[0xb2595927][164] = true; // refund

        signatureEnabler[0x44c0e162][516] = true; // giftSponsored
        signatureEnabler[0xae2f8959][516] = true; // giftWithNative
        signatureEnabler[0x8bd90420][516] = true; // giftWithToken

        nativeEnabler[0x6b92eaa9] = true;
        nativeEnabler[0x46f223cf] = true;
        nativeEnabler[0xf448e169] = true;

        customEnabler[0x7b6a0751] = true; // giftCustomSponsored
        customEnabler[0x185557a7] = true; // giftCustomToken
        customEnabler[0xfbc4a292] = true; // giftCustom
    }

    /// @dev Modifier to restrict execution if the contract is deprecated.
    modifier _depricated() {
        if (depricated) revert isDepricated();
        _;
    }

    /// @dev Toggles the deprecated state of the contract.
    function depricateContract() external onlyRole(DEFAULT_ADMIN_ROLE) {
        depricated = !depricated;
    }

    /// @dev Executes a forwarder request if valid.
    /// @param request The forwarder request data.
    function execute(ForwardRequestData calldata request)
        public
        payable
        override(ERC2771Forwarder)
        _depricated
        nonReentrant
    {
        if (!customEnabler[bytes4(request.data)]) {
            if (!signatureEnabler[bytes4(request.data)][request.data.length]) {
                revert invalidRequest();
            }

            if (hasRole(MANAGER_ROLE, msg.sender)) {
                ERC2771Forwarder.execute(request);
            } else {
                if (!nativeEnabler[bytes4(request.data)]) {
                    revert callNotAllowed();
                }
                ERC2771Forwarder.execute(request);
            }
        } else {
            ERC2771Forwarder.execute(request);
        }
        emit callExecuted(request.to, request.from);
    }

    /// @dev Adds a new signature with data length to the signature enabler.
    /// @param _signature The function signature to add.
    /// @param _dataLength The corresponding data length.
    function addSignatures(bytes4 _signature, uint256 _dataLength) external onlyRole(MANAGER_ROLE) nonReentrant {
        if (signatureEnabler[_signature][_dataLength]) {
            revert signatureAlreadyPresent();
        }
        signatureEnabler[_signature][_dataLength] = true;
        emit signatureAdded(_signature);
    }

    /// @dev Deletes a signature with a specific data length from the signature enabler.
    /// @param _signature The function signature to delete.
    /// @param _dataLength The corresponding data length to delete.
    function deleteSignature(bytes4 _signature, uint256 _dataLength) external onlyRole(MANAGER_ROLE) nonReentrant {
        if (!signatureEnabler[_signature][_dataLength]) {
            revert signatureDisabled();
        }
        delete signatureEnabler[_signature][_dataLength];
        emit signatureDeleted(_signature);
    }

    /// @dev Adds a signature to the native enabler mapping.
    /// @param _signature The function signature to enable for native function calls.
    function addToNativeEnabler(bytes4 _signature) external onlyRole(MANAGER_ROLE) nonReentrant {
        if (nativeEnabler[_signature]) revert nativeSignatureAlreadyPresent();
        nativeEnabler[_signature] = true;
        emit nativeSignatureAdded(_signature);
    }

    /// @dev Deletes a signature from the native enabler mapping.
    /// @param _signature The function signature to disable for native function calls.
    function deleteNativeSignature(bytes4 _signature) external onlyRole(MANAGER_ROLE) nonReentrant {
        if (!nativeEnabler[_signature]) revert nativeSignatureDisabled();
        delete nativeEnabler[_signature];
        emit nativeSignatureDeleted(_signature);
    }

    /// @dev Adds a signature to the custom enabler mapping.
    /// @param _signature The function signature to enable for custom gifting calls.
    function addTocustomEnabler(bytes4 _signature) external onlyRole(MANAGER_ROLE) nonReentrant {
        if (customEnabler[_signature]) revert customSignatureAlreadyPresent();
        customEnabler[_signature] = true;
        emit customSignatureAdded(_signature);
    }

    /// @dev Deletes a signature from the custom enabler mapping.
    /// @param _signature The function signature to disable for custom gifting calls.
    function deletecustomSignature(bytes4 _signature) external onlyRole(MANAGER_ROLE) nonReentrant {
        if (!customEnabler[_signature]) revert customSignatureDisabled();
        delete customEnabler[_signature];
        emit customSignatureDeleted(_signature);
    }

    /// @dev Disables batch execution of forwarder requests.
    /// @dev Currently, batch execution is not allowed and will revert.
    /// @param /*requests*/ Array of forwarder request data (unused).
    /// @param /*refundReceiver*/ Address for refunding unused gas (unused).
    function executeBatch(ForwardRequestData[] calldata, /*requests*/ address payable /*refundReceiver*/ )
        public
        payable
        override(ERC2771Forwarder)
    {
        revert();
    }

    /// @dev Fallback function to prevent external interaction with the contract.
    /// @dev Reverts any unexpected calls to the contract with raw `msg.data`.
    fallback() external {
        revert();
    }

    /// @dev Allows the contract to receive Ether.
    receive() external payable {}

    /// @dev Withdraws the Ether balance from the contract to a specified address.
    /// @param _to The address to receive the withdrawn Ether.
    function withdraw(address payable _to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool sent,) = _to.call{value: address(this).balance}("");
        if (!sent) revert();
    }
}
