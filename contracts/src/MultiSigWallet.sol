// SPDX-License-Identifier: MIT
//  SPDX 许可证标识符：MIT
//  这是一个简单的多签钱包合约，用于演示多签名交易的基本原理
pragma solidity ^0.8.0;

/**
 * @title 多签钱包合约
 * @dev 实现了基本的多签名钱包功能，包括提案、确认和执行交易
 */
contract MultiSigWallet {
    // 多签持有人列表 - 存储所有拥有签名权限的地址
    address[] public owners;
    // 多签门槛（需要多少个确认） - 执行交易所需的最少确认数
    uint256 public required;
    
    /**
     * @dev 交易结构 - 定义了多签钱包中的交易信息
     * @param to 交易目标地址
     * @param value 交易金额（ETH）
     * @param data 交易数据（用于合约调用）
     * @param executed 交易是否已执行
     * @param confirmations 已确认的数量
     */
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }
    
    // 交易列表 - 存储所有提案的交易
    Transaction[] public transactions;
    // 记录每个交易的确认状态 - mapping[交易ID][持有人地址] => 是否确认
    mapping(uint256 => mapping(address => bool)) public isConfirmed;
    // 记录是否是多签持有人 - mapping[地址] => 是否是持有人
    mapping(address => bool) public isOwner;
    
    // 事件定义
    // 当有ETH存入时触发
    event Deposit(address indexed sender, uint256 amount);
    // 当提交交易提案时触发
    event Proposal(uint256 indexed txId, address indexed proposer, address indexed to, uint256 value, bytes data);
    // 当确认交易时触发
    event Confirmation(uint256 indexed txId, address indexed confirmer);
    // 当执行交易时触发
    event Execution(uint256 indexed txId);
    
    /**
     * @dev 修饰器：只有多签持有人可以调用
     */
    modifier onlyOwner() {
        // 检查调用者是否是多签持有人
        require(isOwner[msg.sender], "Not an owner");
        _; // 继续执行原函数
    }
    
    /**
     * @dev 修饰器：交易必须存在
     * @param txId 交易ID
     */
    modifier txExists(uint256 txId) {
        // 检查交易ID是否有效
        require(txId < transactions.length, "Transaction does not exist");
        _;
    }
    
    /**
     * @dev 修饰器：交易未执行
     * @param txId 交易ID
     */
    modifier notExecuted(uint256 txId) {
        // 检查交易是否已执行
        require(!transactions[txId].executed, "Transaction already executed");
        _;
    }
    
    /**
     * @dev 修饰器：交易未被当前用户确认
     * @param txId 交易ID
     */
    modifier notConfirmed(uint256 txId) {
        // 检查当前用户是否已确认该交易
        require(!isConfirmed[txId][msg.sender], "Transaction already confirmed");
        _;
    }
    
    /**
     * @dev 构造函数
     * @param _owners 多签持有人列表
     * @param _required 多签门槛（需要多少个确认）
     */
    constructor(address[] memory _owners, uint256 _required) {
        // 检查持有人列表是否为空
        require(_owners.length > 0, "Owners required");
        // 检查门槛值是否有效（大于0且不超过持有人数量）
        require(_required > 0 && _required <= _owners.length, "Invalid required number of confirmations");
        
        // 遍历持有人列表，添加到合约中
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            // 检查地址是否有效
            require(owner != address(0), "Invalid owner");
            // 检查地址是否唯一
            require(!isOwner[owner], "Owner not unique");
            
            // 标记为持有人
            isOwner[owner] = true;
            // 添加到持有人列表
            owners.push(owner);
        }
        
        // 设置多签门槛
        required = _required;
    }
    
    /**
     * @dev 接收 ETH 的函数
     * 当有人直接向合约发送ETH时触发
     */
    receive() external payable {
        // 触发存款事件
        emit Deposit(msg.sender, msg.value);
    }
    
    /**
     * @dev 1. 提交交易提案
     * @param to 交易目标地址
     * @param value 交易金额（ETH）
     * @param data 交易数据（用于合约调用）
     * @return txId 交易ID
     */
    function proposal(address to, uint256 value, bytes calldata data) external onlyOwner returns (uint256) {
        // 生成交易ID（使用交易列表的长度）
        uint256 txId = transactions.length;
        
        // 创建新交易并添加到交易列表
        transactions.push(Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            confirmations: 0
        }));
        
        // 自动为提案人添加确认
        transactions[txId].confirmations += 1;
        isConfirmed[txId][msg.sender] = true;
        
        // 触发提案事件
        emit Proposal(txId, msg.sender, to, value, data);
        // 触发确认事件
        emit Confirmation(txId, msg.sender);
        // 返回交易ID
        return txId;
    }
    
    /**
     * @dev 2. 确认交易
     * @param txId 交易ID
     */
    function confirm(uint256 txId) external onlyOwner txExists(txId) notExecuted(txId) notConfirmed(txId) {
        // 获取交易存储引用
        Transaction storage transaction = transactions[txId];
        // 增加确认计数
        transaction.confirmations += 1;
        // 标记当前用户已确认
        isConfirmed[txId][msg.sender] = true;
        
        // 触发确认事件
        emit Confirmation(txId, msg.sender);
    }
    
    /**
     * @dev 3. 执行交易
     * @param txId 交易ID
     */
    function execute(uint256 txId) external txExists(txId) notExecuted(txId) {
        // 获取交易存储引用
        Transaction storage transaction = transactions[txId];
        // 检查确认数是否达到门槛
        require(transaction.confirmations >= required, "Not enough confirmations");
        
        // 标记交易为已执行
        transaction.executed = true;
        
        // 执行交易（调用目标地址，发送指定金额和数据）
        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        // 检查执行是否成功
        require(success, "Transaction execution failed");
        
        // 触发执行事件
        emit Execution(txId);
    }
    
    /**
     * @dev 获取交易数量
     * @return 交易总数
     */
    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }
    
    /**
     * @dev 获取交易详情
     * @param txId 交易ID
     * @return to 交易目标地址
     * @return value 交易金额
     * @return data 交易数据
     * @return executed 是否已执行
     * @return confirmations 确认数量
     */
    function getTransaction(uint256 txId) external view returns (address to, uint256 value, bytes memory data, bool executed, uint256 confirmations) {
        Transaction storage transaction = transactions[txId];
        return (transaction.to, transaction.value, transaction.data, transaction.executed, transaction.confirmations);
    }
    
    /**
     * @dev 获取多签持有人列表
     * @return 持有人地址数组
     */
    function getOwners() external view returns (address[] memory) {
        return owners;
    }
}
