// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.7.5;

import "./libs/SafeERC20.sol";
import "./libs/SafeMath.sol";
import "./libs/IERC20.sol";
import "./libs/Ownable.sol";
import "./libs/IUniswapV2Pair.sol";

interface IStaking {
    function stake( uint _amount, address _recipient ) external returns ( bool );
    function claim( address _recipient ) external;
    function unstake( uint _amount, bool _trigger ) external;
}

contract IDO is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint;

    uint public constant lockDuration = 5259487;

    uint public constant idoZDAmount = 10000 * 1e9;
    uint public constant idoBUSDAmount = 100000 * 1e18;
    uint public constant maxBuy = 2500 * 1e18;
    uint public constant minBuy = 500 * 1e18;
    uint public constant priceIDO = 10 * 1e18;

    address public ZD;
    address public sZD;
    address public BUSD;
    address public PairLP;
    address public staking;

    struct Purchase {
        uint payout;
        uint vesting;
        uint lastBlock;
    }

    mapping(address => Purchase) public purchases;

    event UpdatePurchase(address[] addresses, uint[] amount);
    event IDORedeemed( address indexed recipient, uint payout, uint remaining );

    constructor(address _ZD, address _sZD, address _BUSD, address _PairLP, address _staking) {
        ZD = _ZD;
        sZD = _sZD;
        BUSD = _BUSD;
        PairLP = _PairLP;
        staking = _staking;
    }

    function finalize() external onlyOwner {
        IERC20(ZD).transfer(PairLP, idoZDAmount);
        IERC20(BUSD).transfer(PairLP, idoBUSDAmount);
        uint256 lpBalance = IUniswapV2Pair(PairLP).mint(address(this));

        IUniswapV2Pair(PairLP).transfer(msg.sender, lpBalance);
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

    function redeemIDO() external {
        Purchase memory info = purchases[msg.sender];
        uint percentVested = percentVestedFor( msg.sender );

        if ( percentVested >= 10000 ) { 
            require(preRedeem(info.payout), "No Token");
            delete purchases[ msg.sender ];
            emit IDORedeemed( msg.sender, info.payout, 0 );
            IERC20( ZD ).transfer( msg.sender, info.payout );
        } else {
            uint payout = info.payout.mul( percentVested ).div( 10000 );
            require(preRedeem(payout), "No Token");
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

    function stake() external onlyOwner {
        IERC20( ZD ).approve( staking, IERC20( ZD ).balanceOf(address(this)) );
        IStaking( staking ).stake( IERC20( ZD ).balanceOf(address(this)), address(this) );
        IStaking( staking ).claim( address(this) );
    }

    function claim() external onlyOwner {
        IStaking( staking ).claim( address(this) );
    }

    function preRedeem(uint _amount) internal returns(bool) {
        uint balanceZD = IERC20( ZD ).balanceOf(address(this));
        if(balanceZD >= _amount) {
            return true;
        }
        uint balanceSZD = IERC20( sZD ).balanceOf(address(this));
        if(balanceSZD >= _amount) {
            IStaking( staking ).unstake( _amount, false );
            return true;
        }
        return false;
    }

    function recoverLostToken(address _token) external onlyOwner {
        IERC20(_token).transfer(msg.sender, IERC20(_token).balanceOf(address(this)));
    }
    
}