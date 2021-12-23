// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IBond {
    function deposit( 
        uint _amount, 
        uint _maxPrice,
        address _depositor,
        bytes32 referralCode_
    ) external returns ( uint );

    function principle() external view returns (address);
}

contract BondHelper is Initializable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    mapping(address => bool) public bonds;

    function initialize() public initializer {
        __Ownable_init_unchained();
    }

    function deposit(
        address bond,
        uint _amount, 
        uint _maxPrice,
        address _depositor,
        bytes32 referralCode_
    ) external {
        require(bonds[bond], "Bond not accept");
        require(_depositor != address(0), "Depositor cannot be zero");
        require(_amount > 0, "Amount should be greater than 0");

        address principle = IBond(bond).principle();

        IERC20(principle).safeTransferFrom(msg.sender, address(this), _amount);
        IERC20(principle).safeIncreaseAllowance(bond, _amount);
        IBond(bond).deposit(_amount, _maxPrice, _depositor, referralCode_);
    }

    function toggleBondContract( address _bond ) external onlyOwner() {
        require( _bond != address(0) );
        bonds[_bond] = !bonds[_bond];
    }

    /**
     *  @notice allow anyone to send lost tokens to the owner
     */
    function recoverLostToken(address token_) external onlyOwner() {
        IERC20(token_).safeTransfer(msg.sender, IERC20(token_).balanceOf(address(this)));
    }
}