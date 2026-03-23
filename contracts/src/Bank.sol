// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Bank {
    // 管理员地址
    address public admin;
    
    // 记录每个地址的存款余额（新增：用于追踪存款）
    mapping(address => uint256) public balances;
    
    // 事件：当管理员变更时触发
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    // 新增：存款事件，便于追踪
    event Deposited(address indexed depositor, uint256 amount);
    
    // 构造函数：设置初始管理员
    constructor(address initialAdmin) {
        admin = initialAdmin;
    }
    
    // modifier：只有管理员可以调用
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }
    
    // ========== 核心修复：添加接收 ETH 的函数 ==========
    // 1. receive 函数：处理纯 ETH 转账（优先触发）
    receive() external payable {
        // 记录存款人余额
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    // 2. fallback 函数：兜底处理（比如带数据的 ETH 转账）
    fallback() external payable {
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    // 3. 可选：显式的 deposit 函数（主动存款，更可控）
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }
    
    // 设置新管理员
    function setAdmin(address newAdmin) public onlyAdmin {
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminChanged(oldAdmin, newAdmin);
    }
    
    // 提取资金（示例函数）
    function withdraw(address to, uint256 amount) public onlyAdmin {
        // 新增：检查管理员提取金额不超过合约总余额
        require(amount <= address(this).balance, "Insufficient contract balance");
        payable(to).transfer(amount);
    }

    // 新增：查看合约总余额（便于测试验证）
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // 新增：查看指定地址的存款余额
    function getBalance(address user) public view returns (uint256) {
        return balances[user];
    }
}