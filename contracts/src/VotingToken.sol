// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title VotingToken
 * @dev 可计票的ERC20代币，用于治理投票
 */
contract VotingToken is ERC20Votes, Ownable {
    constructor(address initialOwner) ERC20("Voting Token", "VOT") EIP712("Voting Token", "1") Ownable(initialOwner) {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    // 覆盖_update函数以更新投票权重
    function _update(address from, address to, uint256 value) internal override(ERC20Votes) {
        super._update(from, to, value);
    }

    // 额外的mint函数，仅owner可调用
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}