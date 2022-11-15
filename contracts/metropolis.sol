// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Metropolis is ERC721URIStorage {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;   // _tokenIds is how many no. of tokens are created
  Counters.Counter private _itemsSold;

  address payable owner; // owner is platform owner, me

  constructor() ERC721("Metropolis NFT", "METRO") {
    owner = payable(msg.sender);
  }

  struct NFT {
    uint256 tokenId;
    address payable seller;
    address payable owner;
    address payable artist;
    uint256 price;
    uint256 royaltyFeeInBips;
    bool sold;
  }

  mapping(uint256 => NFT) idToNFT;

  event nftCreated (
    uint256 indexed tokenId,
    address payable seller,
    address payable owner,
    address payable artist,
    uint256 price,
    uint256 royaltyFeeInBips,
    bool sold
  );

  // this function will create a token and list it in Metropolis market
  function createToken(string memory tokenURI, uint256 price, uint256 royaltyFeeInBips) public payable returns(uint){

    _tokenIds.increment();
    uint256 newItemId = _tokenIds.current();

    _mint(msg.sender, newItemId);
    _setTokenURI(newItemId, tokenURI);

    // user defined function
    createMarketItem(newItemId, price, royaltyFeeInBips);

    return newItemId;
  }

  // function to calculate royalty fee
  function getRoyaltyFee(uint256 _salePrice, uint256 royaltyFeeInBips) pure public returns(uint256) {
    return (_salePrice/10000)*royaltyFeeInBips;
  }

  // fucntion to calculate commission fee
  function getCommissionFee(uint256 _salePrice) pure public returns(uint256){
    return (_salePrice/10000)*300; // 3% commission
  }

  // will be called by creaeToken()
  function createMarketItem(
    uint256 tokenId,
    uint256 price,
    uint256 royaltyFeeInBips
  ) private {
    require(price > 0,"Price can't be zero.");

    idToNFT[tokenId] = NFT(
        tokenId,
        payable(msg.sender), // seller
        payable(address(this)),
        payable(msg.sender), // seller is the artist
        price,
        royaltyFeeInBips,
        false // flase because till now it is in market, not sold
    );

    // transfer nft to marketplace from seller
    _transfer(msg.sender, address(this), tokenId);
    emit nftCreated(
        tokenId,
        payable(msg.sender),
        payable(address(this)),
        payable(msg.sender),
        price,
        royaltyFeeInBips,
        false
    );
  }

  // Some user is buying NFT, transfer ownership of Nft and price between parties
  function buyNft(
    uint tokenId
  ) public payable {
    uint price = idToNFT[tokenId].price;
    uint royaltyFee = idToNFT[tokenId].royaltyFeeInBips;
    address seller = idToNFT[tokenId].seller;
    address artist = idToNFT[tokenId].artist;
    require(msg.value==price,"Submitted price not equal to NFT price.");
    // when someone buy nft for the first time, change it's owner from platform to him/her
    idToNFT[tokenId].owner = payable(msg.sender);
    idToNFT[tokenId].sold = true;
    idToNFT[tokenId].seller = payable(address(0));

    _itemsSold.increment();

    // transfer ownership of the NFT
    _transfer(address(this), msg.sender, tokenId);

    // now transfer the NFT amount royalty if it is there and commission to the platform owner

    if(idToNFT[tokenId].seller==idToNFT[tokenId].artist){
      // means artist is the seller and it's the first sell of the NFT and artist don't charge royalty fee to himself
      // only charge the commission fetches

      uint256 commissionFee = getCommissionFee(price);
      uint256 toSeller = (msg.value)-commissionFee;

      // transfer commissionFee to the platform owner
      owner.transfer(commissionFee);

      // transfer rest amount to the seller
      payable(seller).transfer(toSeller);
    }else {
      uint256 commissionFee = getCommissionFee(price);
      uint256 _royaltyFee = getRoyaltyFee(price, royaltyFee);
      uint256 toSeller = (msg.value)-(commissionFee + _royaltyFee);
      // transfer royalty fee to the artist
      payable(artist).transfer(_royaltyFee);

      // transfer commissionFee to the platform
      owner.transfer(commissionFee);

      // transfer rest amount to the seller
      payable(seller).transfer(toSeller);
    }
  }

  // this function returns all the unsold NFTs
  // if sold then don't list in the market
  function fetchMarket() public view returns(NFT[] memory) {
    uint256 nftCount = _tokenIds.current();
    uint256 unsoldNftCount = _tokenIds.current() - _itemsSold.current();
    uint currentIndex = 0; // for looping

    // dynamic array of size unsoldNftCount
    NFT[] memory allItems = new NFT[](unsoldNftCount);

    for(uint i=0; i<nftCount; i++){
        if(idToNFT[i+1].owner == address(this)) {
            uint currentId = i+1;
            NFT storage currentNFT = idToNFT[currentId];
            allItems[currentIndex] = currentNFT;
            currentIndex++;
        }
    }
    return allItems;
  }

  // this fucntion fetches NFTs bought by you
  function fetchMyNFTs() public view returns(NFT[] memory) {
    uint256 totalNFTsCount = _tokenIds.current();
    uint256 nftCount = 0;
    uint256 currentIndex = 0;

    // first find total no. of nfts owned by the user
    for(uint i=0; i<totalNFTsCount; i++){
        if(idToNFT[i+1].owner==msg.sender){
            nftCount++;
        }
    }

    NFT[] memory myNFTs = new NFT[](nftCount);
    for(uint i=0; i<totalNFTsCount; i++){
        if(idToNFT[i+1].owner==msg.sender){
            uint currentId = i+1;
            NFT storage currentNFT = idToNFT[currentId];
            myNFTs[currentIndex] = currentNFT;
            currentIndex++;
        }
    }
    return myNFTs;
  }

  // this function returns NFTs created by the user
  function fetchMyListings() public view returns(NFT[] memory){
     uint256 totalNFTsCount = _tokenIds.current();
    uint256 nftCount = 0;
    uint256 currentIndex = 0;

    // first find total no. of nfts owned by the user
    for(uint i=0; i<totalNFTsCount; i++){
        if(idToNFT[i+1].seller==msg.sender){
            nftCount++;
        }
    }

    NFT[] memory myListings = new NFT[](nftCount);
    for(uint i=0; i<totalNFTsCount; i++){
        if(idToNFT[i+1].seller==msg.sender){
            uint currentId = i+1;
            NFT storage currentNFT = idToNFT[currentId];
            myListings[currentIndex] = currentNFT;
            currentIndex++;
        }
    }
    return myListings;
  }


  // this function resell the nfts owned by the owner
  function resellNFTs(
    uint256 tokenId,
    uint256 price
  ) public payable {
    require(idToNFT[tokenId].owner==msg.sender,"You are not owner of this NFT");
    idToNFT[tokenId].owner=payable(address(this));
    idToNFT[tokenId].sold=false;
    idToNFT[tokenId].seller=payable(msg.sender);
    idToNFT[tokenId].price=price;
    _itemsSold.decrement();

    _transfer(msg.sender, address(this), tokenId);
  }
}