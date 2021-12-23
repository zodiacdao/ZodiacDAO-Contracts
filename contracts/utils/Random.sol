// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Random {

    function d100(uint _heroId) external view returns (uint) {
        return dn(_heroId, 100);
    }

    function d20(uint _heroId) external view returns (uint) {
        return dn(_heroId, 20);
    }

    function d12(uint _heroId) external view returns (uint) {
        return dn(_heroId, 12);
    }

    function d10(uint _heroId) external view returns (uint) {
        return dn(_heroId, 10);
    }

    function d8(uint _heroId) external view returns (uint) {
        return dn(_heroId, 8);
    }

    function d6(uint _heroId) external view returns (uint) {
        return dn(_heroId, 6);
    }

    function d4(uint _heroId) external view returns (uint) {
        return dn(_heroId, 4);
    }

    function dn(uint _heroId, uint _number) public view returns (uint) {
        return _seed(_heroId) % _number;
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