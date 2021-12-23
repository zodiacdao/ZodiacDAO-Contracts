// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LuckyBox is Ownable {

    uint luckRate;

    function setLuckRate(uint _rate) external onlyOwner {
        require(_rate <= 100000);
        luckRate = _rate;
    }

    function luckyMe(uint _amount) external view returns (bool) {
        uint _r = _seed(_amount + block.number) % 100000;
        if(_r >= luckRate) return true;
        else return false;
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