// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

abstract contract CodeConstants is Script{
    string constant DOMAIN = "moshpit";
    string constant VERSION = "1";
    struct NFTVoucher {
        uint256 tokenId;
        uint256 price;
        uint256 quantity;
        uint256 buyerQty;
        uint256 start;
        uint256 end;
        uint96 royalty;
        bool isStealth;
        bool isSbt;
        bytes creator; // signature 1
        bytes validator; // signature 2
    }

    address constant MINT_VALIDATOR = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // ANVIL_DEFAULT Account
    string  mnemonic = "test test test test test test test test test test test junk";
    uint256 privateKey = vm.deriveKey(mnemonic, 0);
    address SIGNER = vm.rememberKey(privateKey);
}

contract creationsVoucher is Script, CodeConstants {
    
    error creationVoucher__NotSameAddressAsTestWalletCreated();

    /*//////////////////////////////////////////////////////////////
                             EIP712-PREREQ
    //////////////////////////////////////////////////////////////*/
    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private immutable _hashedName = keccak256(bytes(DOMAIN));
    bytes32 private immutable _hashedVersion = _hashedVersion = keccak256(bytes(VERSION));
    uint256 private immutable _cachedChainId = block.chainid;
    bytes32 private immutable _cachedDomainSeparator;

    constructor(address dappunkCreations) {
        _cachedDomainSeparator = _buildDomainSeparator(dappunkCreations);
    }

    function generateVoucher(uint256 collectionIndex,uint256 tokenIndex,uint256 price,uint256 quantity,uint256 buyerQty,uint256 start,uint256 end,uint96 royalty,bool isStealth,bool isSbt,address creator) public pure returns(NFTVoucher memory nftVoucher){
        uint256 tkID = generateTokenId(creator,collectionIndex,tokenIndex,quantity);
        nftVoucher = NFTVoucher({
            tokenId:tkID,
            price:price,
            quantity:quantity,
            buyerQty:buyerQty,
            start:start,
            end:end,
            royalty:royalty,
            isStealth:isStealth,
            isSbt:isSbt,
            creator: hex"",
            validator:hex""
        });
    }
    
    function generateTokenId(address creator,uint256 collectionIndex,uint256 tokenIndex,uint256 tokenQty) internal pure returns(uint256){

        // uint256 collectionIndexSize = 10; // in hex
        // uint256 tokenIndexSize = 10;
        // uint256 tokenQtySize = 4;

        // one hex = 4 bits
        // total bits = 10*4 + 10*4 + 4*4 = 40+40+16 = 80+16 = 96 bits
        // with address = 160 + 96 = 256

        uint256 tokenId = uint256(uint160(creator));
        tokenId = (tokenId << 40) + collectionIndex;
        tokenId = (tokenId << 40) + tokenIndex;
        tokenId = (tokenId << 16) + tokenQty;

        return tokenId;
        
    }

    function generateEIP712StructHash(NFTVoucher memory voucher,address dappunkCreations) public view returns (bytes32 digest) {
        // STEP 1 : Generate a EIP712 compliant voucher hash.
        // STEP 2 : Generate a Signature from the creator.
        // STEP 3 : Generate a Signature from the Admin 

        // For step on Import the EIP712 sol
        digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(
                        "NFTVoucher(uint256 tokenId,uint256 price,uint256 quantity,uint256 buyerQty,uint256 start,uint256 end,uint96 royalty,bool isStealth,bool isSbt)"
                    ),
                    voucher.tokenId,
                    voucher.price,
                    voucher.quantity,
                    voucher.buyerQty,
                    voucher.start,
                    voucher.end,
                    voucher.royalty,
                    voucher.isStealth,
                    voucher.isSbt
                )
            ), dappunkCreations
        );

    }

    function generateSignedVoucher(NFTVoucher memory voucher,bytes32 digest) public view returns (NFTVoucher memory, bytes memory, bytes memory) {
         // user Signature Generation
        uint8 v;
        bytes32 r;
        bytes32 s;
        
        if (voucher.tokenId >> 96 != uint256(uint160(SIGNER))) revert creationVoucher__NotSameAddressAsTestWalletCreated();
        
        // Creator signature
        (v,r,s) = vm.sign(SIGNER,digest);
        voucher.creator = abi.encodePacked(r, s, v);

        //Admin Signature
        (v,r,s) = vm.sign(MINT_VALIDATOR,digest);
        voucher.validator = abi.encodePacked(r, s, v);

        return (voucher,voucher.creator,voucher.validator);
    }


    
    function _buildDomainSeparator(address dappunkCreations) private view returns (bytes32) {
        return keccak256(abi.encode(TYPE_HASH, _hashedName, _hashedVersion, block.chainid, dappunkCreations));
    }

     function _hashTypedDataV4(bytes32 structHash,address dappunkCreations) internal view returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(_buildDomainSeparator(dappunkCreations), structHash);
    }


}