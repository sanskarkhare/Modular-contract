// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../NFTFactoryContract1155.sol";
import "../Libraries/LibBid1155.sol";
import "../Libraries/LibMeta1155.sol";

contract NFTBid1155 is NFTFactoryContract1155 {
    event BidOrderReturn(LibBid1155.BidOrder bid);
    event BidExecuted(uint256 price);
    event AuctionStarted(uint time);

    using Counters for Counters.Counter;

    function Bid(uint256 _saleId, uint256 _amount) public payable {
        require(_tokenMeta[_saleId].currentOwner != msg.sender);
        require(_tokenMeta[_saleId].status == true);
        require(_tokenMeta[_saleId].bidSale == true);
        require(msg.value % _amount == 0);
        require(msg.value / _amount >= _tokenMeta[_saleId].price);
        require(_tokenMeta[_saleId].numberOfTokens >= _amount);

        LibBid1155.BidOrder memory bid = LibBid1155.BidOrder(
            _saleId,
            _amount,
            _tokenMeta[_saleId].currentOwner,
            msg.sender,
            msg.value,
            false
        );
        Bids[_saleId].push(bid);

        emit BidOrderReturn(bid);
    }

    function SellNFT_byBid(address _collectionAddress, uint256 _tokenId, uint256 _price, uint256 _amount)
        public
        nonReentrant
    {
        uint256 bal = ERC1155(_collectionAddress).balanceOf(msg.sender, _tokenId);
        require(bal >= _amount);

         _tokenIdTracker.increment();

        //needs approval on frontend
        ERC1155(_collectionAddress).safeTransferFrom(msg.sender, address(this), _tokenId, _amount, "");

        LibMeta1155.TokenMeta memory meta = LibMeta1155.TokenMeta(
            _collectionAddress,
            _tokenId,
            _amount,
            _price,
            false,
            true,
            true,
            msg.sender
        );

         _tokenMeta[_tokenIdTracker.current()] = meta;

        emit TokenMetaReturn(meta, _tokenIdTracker.current());
      
    }

    function executeBidOrder(uint256 _saleId, uint256 _bidOrderID)
        public
        nonReentrant
    {   
        require(msg.sender == _tokenMeta[_saleId].currentOwner);
        require(Bids[_saleId][_bidOrderID].withdrawn == false);
        require(_tokenMeta[_saleId].status == true);
        require(_tokenMeta[_saleId].numberOfTokens >= Bids[_saleId][_bidOrderID].numberOfTokens);

         LibShare.Share[] memory royalties;

        if(_tokenMeta[_saleId].collectionAddress == PNDC1155Address) {
            royalties = PNDC_ERC1155(PNDC1155Address).getRoyalties(_tokenMeta[_saleId].tokenId);
        }

        else {
            royalties = TokenERC1155(_tokenMeta[_saleId].collectionAddress).getRoyalties(_tokenMeta[_saleId].tokenId);
        }

        LibMeta1155.transfer(_tokenMeta[_saleId], Bids[_saleId][_bidOrderID].numberOfTokens);
        Bids[_saleId][_bidOrderID].withdrawn = true;

        ERC1155(_tokenMeta[_saleId].collectionAddress).safeTransferFrom(
            address(this),
            Bids[_saleId][_bidOrderID].buyerAddress,
            _tokenMeta[_saleId].tokenId,
            Bids[_saleId][_bidOrderID].numberOfTokens,
            ""
        );

        uint sum = Bids[_saleId][_bidOrderID].price;
        uint fee = Bids[_saleId][_bidOrderID].price / 100;

        for(uint256 i = 0; i < royalties.length; i ++) {
            uint256 amount = (royalties[i].value * Bids[_saleId][_bidOrderID].price) / 10000;
            royalties[i].account.transfer(amount);
            sum = sum - amount;
        }

        payable(msg.sender).transfer(sum - fee);
        payable(feeAddress).transfer(fee);

        emit BidExecuted(Bids[_saleId][_bidOrderID].price);
    }

    function withdrawBidMoney(uint256 _saleId, uint256 _bidId) public nonReentrant{
        require(
            Bids[_saleId][_bidId].buyerAddress == msg.sender
        );
        require(Bids[_saleId][_bidId].withdrawn == false);
        if (payable(msg.sender).send(Bids[_saleId][_bidId].price)) {
            Bids[_saleId][_bidId].withdrawn = true;
        } else {
            revert("No Money left!");
        }
    }
}