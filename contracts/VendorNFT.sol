// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IZodiacNFT {
    function redeemLottery(uint[] memory _tokenIDs, address _owner) external;
    function getZodiacType(uint _tokenID) external view returns(uint8);
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract Vendor is Initializable, OwnableUpgradeable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    uint internal constant zodiacTeam = 12;
    address public ZodiacNFT;
    address public sZD;
    address public rewardToken;
    address public staking;
    uint public priceBox;
    uint public totalBox;

    struct Prize {
        uint reward;
        uint max;
        uint claimed;
        uint zodiacNeed;
        address[] claimlist;
    }

    mapping(uint => Prize) public prizes;
    mapping(address => bool) public whiteList;
    mapping(address => bool) public metaPlayers;
    mapping(address => uint) public metaBox;
    mapping(uint => bool) public metaUnpublic;

    event RedeemLottery(address indexed winner, uint typePrize, uint reward, uint[] tokenIDs);

    modifier onlyWhiteList() {
        require(whiteList[msg.sender], "Only whiteList");
        _;
    }

    function initialize(address _ZodiacNFT, address _szd, address _staking) public initializer {
        __Ownable_init_unchained();

        ZodiacNFT = _ZodiacNFT;
        sZD = _szd;
        staking = _staking;
    }

    function setPrize(uint _type, uint _reward, uint _max, uint _zodiacNeed) external onlyOwner {
        Prize storage prize = prizes[_type];
        prize.reward = _reward;
        prize.max = _max;
        prize.zodiacNeed = _zodiacNeed;
    }

    function setPriceBox(uint _price) external onlyOwner {
        require(_price > 0, "Price not zero");
        priceBox = _price;
    }

    function setZodiacNFT(address _zodiac) external onlyOwner {
        require(_zodiac != address(0));
        ZodiacNFT = _zodiac;
    }

    function toggleWhiteList(address _whitelist) external onlyOwner {
        require(_whitelist != address(0));
        whiteList[_whitelist] = !whiteList[_whitelist];
    }

    function toggleMetaPlayers(address _whitelist) external onlyOwner {
        require(_whitelist != address(0));
        metaPlayers[_whitelist] = !metaPlayers[_whitelist];
    }

    function toggleMetaUnpublic(uint _meta) external onlyOwner {
        require(_meta < zodiacTeam);
        metaUnpublic[_meta] = !metaUnpublic[_meta];
    }

    function setMetaBox(address _recipient, uint _amount) external onlyWhiteList {
        metaBox[_recipient] = metaBox[_recipient].add(_amount);
        totalBox = totalBox.add(_amount);
    }

    function setRewardToken(address _token) external onlyOwner {
        require(_token != address(0));
        rewardToken = _token;
    }

    function openBox(address _owner, uint _zodiac) external returns(uint8) {
        require(msg.sender == ZodiacNFT, "Only NFT");
        require(metaBox[_owner] > 0, "No Box");
        uint _class = _seed(zodiacTeam + block.number) % zodiacTeam;
        if(metaUnpublic[_class] && !metaPlayers[_owner]) {
            _class = 1;
        }
        if(_zodiac < zodiacTeam && metaPlayers[_owner]) {
            _class = _zodiac;
        }

        metaBox[_owner] = metaBox[_owner].sub(1);
        return uint8(_class);
    }

    function redeemLottery(uint _type, uint[] memory _tokenIDs) external {
        uint length = _tokenIDs.length;
        Prize storage prize = prizes[_type];
        require(prize.reward > 0, "No Reward");
        require(prize.claimed < prize.max, "Out Stock");
        require(length == prize.zodiacNeed, "Wrong quantity");

        uint8[] memory zd = new uint8[](prize.zodiacNeed);
        bool dup;
        for(uint i = 0; i < _tokenIDs.length; i++) {
            uint tokenID = _tokenIDs[i];
            require(IZodiacNFT(ZodiacNFT).ownerOf(tokenID) == msg.sender, "Not Owner");
            uint8 zodiac = IZodiacNFT(ZodiacNFT).getZodiacType(tokenID) + 1;
            for(uint j = 0; j < zd.length; j++) {
                if(zd[j] != 0 && zd[j] == zodiac) {
                    dup = true;
                }
            }
            zd[i] = zodiac;
        }
        require(!dup, "Wrong reward code");
        IZodiacNFT(ZodiacNFT).redeemLottery(_tokenIDs, msg.sender);
        IERC20(rewardToken).transfer(msg.sender, prize.reward);
        prize.claimed = prize.claimed.add(1);
    }

    function buyBox(uint _amount) external {
        uint totalPrice = priceBox.mul(_amount);
        uint feeMarket = totalPrice.mul(95).div(100);
        uint priceSubFee = totalPrice.sub(feeMarket);
        require(
            IERC20(sZD).transferFrom(msg.sender, staking, feeMarket),
            "Buy Box: Fail To Burn Amount"
        );
        require(
            IERC20(sZD).transferFrom(msg.sender, address(this), priceSubFee),
            "Market: Fail To Transfer Fee Amount"
        );
        metaBox[msg.sender] = metaBox[msg.sender].add(_amount);
        totalBox = totalBox.add(_amount);
    }

    function _random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }
    
    function _seed(uint _heroId) public view returns (uint rand) {
        rand = _random(
            string(
                abi.encodePacked(
                    _heroId,
                    msg.sender,
                    block.timestamp,
                    block.difficulty,
                    uint256(keccak256(abi.encodePacked(block.coinbase)))
                )
            )
        );
    }
}