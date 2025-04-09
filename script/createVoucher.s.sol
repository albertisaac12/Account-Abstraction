// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {EIP712} from "lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

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

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
}

contract creationsVoucher is Script, CodeConstants {
    
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

    function generateEIP712SignedVoucher(NFTVoucher memory voucher) public returns (NFTVoucher memory,bytes32 voucherHash) {
        // STEP 1 : Generate a EIP712 compliant voucher hash.
        // STEP 2 : Generate a Signature from the creator.
        // STEP 3 : Generate a Signature from the Admin 

        // For step on Import the EIP712 sol

    }
}