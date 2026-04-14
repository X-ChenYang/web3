// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BankV2
 * @dev 资金管理合约V2，只有管理员可以提取资金
 */
contract BankV2 is Ownable {
    /**
     * @dev 构造函数
     * @param initialOwner 初始管理员地址
     */
    constructor(address initialOwner) Ownable(initialOwner) {
    }

    /**
     * @dev 存款函数
     */
    function deposit() external payable {
        // 存款逻辑，直接接收ETH
    }

    /**
     * @dev 提取资金函数，仅管理员可调用
     * @param to 接收资金的地址
     * @param amount 提取的金额
     */
    function withdraw(address to, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        payable(to).transfer(amount);
    }

    /**
     * @dev 获取合约余额
     * @return 合约当前ETH余额
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}