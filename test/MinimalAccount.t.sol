// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {DeployMinimal} from "./../script/DeployMinimal.s.sol";
import {MinimalAccount} from "./../src/Ethereum/Minimal-Account.sol";
import {HelperConfig} from "./../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation} from "script/SendPackedUserOp.s.sol";
// import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {creationsVoucher,CodeConstants} from "./../script/createVoucher.s.sol";
import {dappunkCreations} from "./../src/dappunk/dappunkCreations.sol";

contract MinimalAccountTest is Test , CodeConstants {
    using MessageHashUtils for bytes32;

    HelperConfig helperConfig;
    MinimalAccount minimalAccount;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;
    dappunkCreations creations;
    creationsVoucher cv;

    address randomUser = makeAddr("randomUser");
    uint256 constant AMOUNT = 1e18;

    function setUp() public {
        DeployMinimal deployMinimal = new DeployMinimal();
        (helperConfig, minimalAccount,creations) = deployMinimal.deployMinimalAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
        cv = new creationsVoucher(address(creations));
    }

    //USDC Mint
    //msg.sender == minimalAccount
    // USDC Contract
    //come from entryPoint

    function testOwnerCanExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        vm.startPrank(minimalAccount.owner());
        // vm.deal(minimalAccount.owner(), 10e18);
        minimalAccount.execute(dest, value, functionData);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testNonOwnerCannotExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        vm.prank(randomUser);
        vm.expectRevert(MinimalAccount.MinimalAccount_NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(dest, value, functionData);
    }

    /*//////////////////////////////////////////////////////////////
                             PACKEDUSEROPS
    //////////////////////////////////////////////////////////////*/

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

    function testRecoverSignedOp() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);

        (PackedUserOperation memory packedUserOperation,) = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOperation);

        address actualSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOperation.signature);

        assertEq(actualSigner, minimalAccount.owner());
    }

    //1. Sign UserOps
    // 2. Call Validate userOps
    // 3. Assert the return is correct
    //
    function testValidationOfUserOps() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);

        (PackedUserOperation memory packedUserOperation,) = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOperation);
        uint256 missingAccountFunds = 1e18;
        // ACT
        vm.prank(helperConfig.getConfig().entryPoint);
        uint256 validationData =
            minimalAccount.validateUserOp(packedUserOperation, userOperationHash, missingAccountFunds);
        assertEq(validationData, 0);
    }

    function testEntryPointCanExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);

        (PackedUserOperation memory packedUserOperation,) = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );
        // bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOperation);
        // uint256 missingAccountFunds = 1e18;

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOperation;
        // ACT
        vm.deal(address(minimalAccount), 1e18);
        vm.prank(randomUser);
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(randomUser));

        //Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }


    function testAddressRecoveredFromVoucher() public view {
        // generateVoucher(uint256 collectionIndex,uint256 tokenIndex,uint256 price,uint256 quantity,uint256 buyerQty,uint256 start,uint256 end,uint96 royalty,bool isStealth,bool isSbt,address creator)
        NFTVoucher memory unsignedVoucher = cv.generateVoucher(1,1,1e18,10,1,0,0,0,false,false,SIGNER);
        
        bytes32 voucherHash = cv.generateEIP712StructHash(unsignedVoucher,address(creations));

        (,bytes memory creatorSignature,bytes memory validatorSignature) = cv.generateSignedVoucher(unsignedVoucher,voucherHash);
        address creator = ECDSA.recover(voucherHash, creatorSignature);
        address validator = ECDSA.recover(voucherHash, validatorSignature);

        assertEq(creator,SIGNER);
        assertEq(validator,MINT_VALIDATOR);

    }


     function testVerifyVoucher() public view {
        // generateVoucher(uint256 collectionIndex,uint256 tokenIndex,uint256 price,uint256 quantity,uint256 buyerQty,uint256 start,uint256 end,uint96 royalty,bool isStealth,bool isSbt,address creator)
        NFTVoucher memory unsignedVoucher = cv.generateVoucher(1,1,1e18,10,1,0,0,0,false,false,SIGNER);
        
        bytes32 voucherHash = cv.generateEIP712StructHash(unsignedVoucher,address(creations));

         (NFTVoucher memory signedVoucher,,) = cv.generateSignedVoucher(unsignedVoucher,voucherHash);
       
        address creator = creations.verifyVoucher(dappunkCreations.NFTVoucher({
                    tokenId:signedVoucher.tokenId,
                    price:signedVoucher.price,
                    quantity:signedVoucher.quantity,
                    buyerQty:signedVoucher.buyerQty,
                    start:signedVoucher.start,
                    end:signedVoucher.end,
                    royalty:signedVoucher.royalty,
                    isStealth:signedVoucher.isStealth,
                    isSbt:signedVoucher.isSbt,
                    creator:signedVoucher.creator,
                    validator:signedVoucher.validator
        }));

        assertEq(creator,SIGNER);

    }


    function testMintWithEntryPoint() public {
        NFTVoucher memory unsignedVoucher = cv.generateVoucher(1,1,1e18,10,1,0,0,0,false,false,SIGNER);
        bytes32 voucherHash = cv.generateEIP712StructHash(unsignedVoucher,address(creations));
        (NFTVoucher memory signedVoucher,,) = cv.generateSignedVoucher(unsignedVoucher,voucherHash);

        address buyer = makeAddr("buyer");
        address dest = address(creations);
        uint256 value = 0;
        // Generate Data for execute
         bytes memory functionData = abi.encodeWithSelector(creations.mintNft.selector,dappunkCreations.NFTVoucher({
            tokenId:signedVoucher.tokenId,
            price:signedVoucher.price,
            quantity:signedVoucher.quantity,
            buyerQty:signedVoucher.buyerQty,
            start:signedVoucher.start,
            end:signedVoucher.end,
            royalty:signedVoucher.royalty,
            isStealth:signedVoucher.isStealth,
            isSbt:signedVoucher.isSbt,
            creator:signedVoucher.creator,
            validator:signedVoucher.validator
        }),buyer);

        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);

        (PackedUserOperation memory packedUserOperation,) = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOperation;
        vm.deal(address(minimalAccount), 1e18);
        vm.prank(randomUser);
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(randomUser));

        assertEq(creations.balanceOf(buyer,signedVoucher.tokenId),1);

    }
}
