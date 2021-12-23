// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IVendorNFT {
    function metaBox(address _owner) external view returns(uint);
    function openBox(address _owner, uint _seed) external returns(uint8);
}

contract ZodiacNFT is Ownable, ERC721Enumerable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    enum Zodiac { Aries, Taurus, Gemini, Cancer, Leo, Virgo, Libra, Scorpio, Sagittarius, Capricorn, Aquarius, Pisces }
    
    event OpenBox(uint indexed tokenID, address owner, Zodiac zodiac);
    event Listing(uint indexed tokenID, address seller, uint price);
    event UnListing(uint indexed tokenID, address seller);
    event PlaceOrder(uint indexed tokenID, address seller);

    struct SaleInfo {
        uint tokenId;
        address owner;
        uint price;
    }

    uint private constant ONE_HUNDRED_PERCENT = 10**4;
    uint public nextToken;
    uint public serviceFee;
    uint public sZDNeed;
    address public sZD;
    address public vendor;

    EnumerableSet.UintSet private tokenSales;
    mapping(uint => Zodiac) public zodiacs;
    mapping(uint => SaleInfo) public markets;
    mapping(address => EnumerableSet.UintSet) private sellerTokens;

    constructor(address _sZD) ERC721("Zodiac NFT", "ZDNFT") {
        sZD = _sZD;
        nextToken++;
    }

    function setServiceFee(uint _value) external onlyOwner {
        serviceFee = _value;
    }

    function setSZDNeed(uint _value) external onlyOwner {
        sZDNeed = _value;
    }

    function setVendor(address _vendor) external onlyOwner {
        vendor = _vendor;
    }

    function openBox(uint _seed) external returns(Zodiac) {
        require(IVendorNFT(vendor).metaBox(_msgSender()) > 0, "No Box");
        require(IERC20(sZD).balanceOf(_msgSender()) >= sZDNeed, "Must hold enough sZD");
        uint8 unbox = IVendorNFT(vendor).openBox(_msgSender(), _seed);
        Zodiac zodiac = Zodiac(unbox);
        zodiacs[nextToken] = zodiac;
        super._safeMint(_msgSender(), nextToken);
        emit OpenBox(nextToken, _msgSender(), zodiac);

        nextToken++;
        return zodiac;
    }

    function redeemLottery(uint[] memory _tokenIDs, address _owner) external {
        require(msg.sender == vendor, "Only Vendor");
        require(IERC20(sZD).balanceOf(_owner) >= sZDNeed, "Must hold enough sZD");
        for(uint i = 0; i < _tokenIDs.length; i++) {
            require(ownerOf(_tokenIDs[i]) == _owner);
            _transfer(_owner, address(this), _tokenIDs[i]);
        }
    }

    function getZodiacType(uint _tokenID) external view returns(uint8) {
        return uint8(zodiacs[_tokenID]);
    }

    function createSell(uint _tokenID, uint _price) external {
        require(ownerOf(_tokenID) == _msgSender());
        require(_price > 0);
        
        _setItemSale(_tokenID, true, _price);
        
        emit Listing(_tokenID, _msgSender(), _price);
    }
    
    function unSell(uint _tokenID) external {
        require(tokenSales.contains(_tokenID));
        SaleInfo storage saleInfo = markets[_tokenID];
        require(saleInfo.owner == _msgSender());

        _setItemSale(_tokenID, false, 0);

        emit UnListing(_tokenID, _msgSender());
    }

    function placeOrder(uint _tokenID) public {
        require(tokenSales.contains(_tokenID));
        SaleInfo storage saleInfo = markets[_tokenID];
        uint feeMarket = saleInfo.price.mul(serviceFee).div(ONE_HUNDRED_PERCENT);
        uint priceSubFee = saleInfo.price.sub(feeMarket);
        require(
            IERC20(sZD).transferFrom(_msgSender(), address(this), feeMarket),
            "Market: Fail To Transfer Fee Amount"
        );
        require(
            IERC20(sZD).transferFrom(_msgSender(), saleInfo.owner, priceSubFee),
            "Market: Fail To Transfer Amount"
        );

        _setItemSale(_tokenID, false, 0);
        emit PlaceOrder(_tokenID, _msgSender());
    }

    function marketSize() external view returns (uint) {
        return tokenSales.length();
    }

    function countSellBuyOwner(address _seller) external view returns (uint) {
        return sellerTokens[_seller].length();
    }

    function tokenSaleByIndex(uint index) external view returns (uint) {
        return tokenSales.at(index);
    }

    function tokenSaleOfOwnerByIndex(address _seller, uint index) external view returns (uint) {
        return sellerTokens[_seller].at(index);
    }

    function _setItemSale(uint _tokenID, bool _isSell, uint _price) internal {
        SaleInfo memory saleInfo = markets[_tokenID];
        if(_isSell) {
            _transfer(_msgSender(), address(this), _tokenID);
            tokenSales.add(_tokenID);
            sellerTokens[_msgSender()].add(_tokenID);

            markets[_tokenID] = SaleInfo({
                tokenId: _tokenID,
                price: _price,
                owner: _msgSender()
            });
        } else {
            tokenSales.remove(_tokenID);
            sellerTokens[saleInfo.owner].remove(_tokenID);
            delete markets[_tokenID];
            _transfer(address(this), _msgSender(), _tokenID);
        }
    }
}