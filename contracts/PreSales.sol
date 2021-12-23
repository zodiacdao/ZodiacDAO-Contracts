// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.7.5;

import "./libs/SafeERC20.sol";
import "./libs/SafeMath.sol";
import "./libs/IERC20.sol";
import "./libs/Ownable.sol";
import "./libs/IUniswapV2Pair.sol";

contract PreSale is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint;

    uint public constant buyDuration = 15 minutes;
    uint public constant lockDuration = 6 * 30 * 24 hours;

    uint public constant idoZDAmount = 20000 * 1e9;
    uint public constant idoBUSDAmount = 100000 * 1e18;
    uint public constant maxBuy = 2500 * 1e18;
    uint public constant minBuy = 500 * 1e18;
    uint public constant priceIDO = 10 * 1e18;

    address public ZD;
    address public BUSD;
    address public PairLP;

    uint public lockTime;
    uint public startTime;
    uint public endTime;
    bool public ended;

    uint public preWhiteListCount;

    mapping(address => bool) public preWhiteList;

    struct Purchase {
        uint payout;
        uint vesting;
        uint lastBlock;
    }

    mapping(address => Purchase) public purchases;

    event RegisterWhiteList(address indexed wallet);
    event UpdatePurchase(address[] addresses, uint[] amount);
    event IDORedeemed( address indexed recipient, uint payout, uint remaining );

    constructor(address _ZD, address _BUSD, address _PairLP) {
        ZD = _ZD;
        BUSD = _BUSD;
        PairLP = _PairLP;
    }

    function startIDO() external onlyOwner {
        require(startTime == 0, "IDO Started");
        startTime = block.timestamp;
        endTime = startTime.add(buyDuration);
    }

    function registerWhiteList() external {
        require(startTime == 0, "End Time");
        require(!preWhiteList[msg.sender], "Already registered");
        preWhiteList[msg.sender] = true;
        preWhiteListCount = preWhiteListCount.add(1);

        emit RegisterWhiteList(msg.sender);
    }

    function updatePurchase(address[] memory _addresses, uint[] memory _amount) external onlyOwner {
        for (uint256 index = 0; index < _addresses.length; index++) {
            uint _payout = _amount[index].div(priceIDO);
            _payout = _payout * 1e9;
            purchases[_addresses[index]] = Purchase({ 
                payout: purchases[_addresses[index]].payout.add(_payout),
                vesting: lockDuration,
                lastBlock: block.number
            });
        }

        emit UpdatePurchase(_addresses, _amount);
    }

    function finalize() external onlyOwner {
        require(endTime <= block.timestamp, "Not Finish");

        IERC20(ZD).transfer(PairLP, idoZDAmount);
        IERC20(BUSD).transfer(PairLP, idoBUSDAmount);
        uint256 lpBalance = IUniswapV2Pair(PairLP).mint(address(this));

        IUniswapV2Pair(PairLP).transfer(msg.sender, lpBalance);
        
        ended = true;
    }

    function redeemIDO() external {
        require(ended, "Not Ended");
        Purchase memory info = purchases[msg.sender];
        uint percentVested = percentVestedFor( msg.sender );

        if ( percentVested >= 10000 ) { 
            delete purchases[ msg.sender ];
            emit IDORedeemed( msg.sender, info.payout, 0 );
            IERC20( ZD ).transfer( msg.sender, info.payout );
        } else {
            uint payout = info.payout.mul( percentVested ).div( 10000 );

            purchases[ msg.sender ] = Purchase({
                payout: info.payout.sub( payout ),
                vesting: info.vesting.sub( block.number.sub( info.lastBlock ) ),
                lastBlock: block.number
            });
            IERC20( ZD ).transfer( msg.sender, payout );
            emit IDORedeemed( msg.sender, payout, purchases[ msg.sender ].payout );
        }
    }

    function percentVestedFor( address _depositor ) public view returns ( uint percentVested_ ) {
        Purchase memory purchase = purchases[ _depositor ];
        uint blocksSinceLast = block.number.sub( purchase.lastBlock );
        uint vesting = purchase.vesting;

        if ( vesting > 0 ) {
            percentVested_ = blocksSinceLast.mul( 10000 ).div( vesting );
        } else {
            percentVested_ = 0;
        }
    }

    function deposit() external onlyOwner {
        require(IERC20(BUSD).balanceOf(address(this)) == 0, "Deposited");
        IERC20(BUSD).transferFrom(msg.sender, address(this), idoBUSDAmount);
    }

    function recoverLostToken(address _token) external onlyOwner {
        require(_token != ZD);
        IERC20(_token).transfer(msg.sender, IERC20(_token).balanceOf(address(this)));
    }
    
}