// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract HyToken is Initializable, ERC20Upgradeable {
    function initialize(string memory name, string memory symbol, uint256 initialSupply) public initializer {
        __ERC20_init(name, symbol);
        _mint(msg.sender, initialSupply);
    }
}
