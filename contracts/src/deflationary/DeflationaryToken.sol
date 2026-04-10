// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DeflationaryToken 通缩型ERC20代币
 * @dev 实现了rebase机制的通缩型代币
 * 起始发行量为1亿，每年通缩1%
 */
contract DeflationaryToken is ERC20, Ownable {
    // 起始发行量：1亿
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10**18;
    // 年通缩率：1%
    uint256 public constant ANNUAL_DEFLATION_RATE = 1;
    // 上一次rebase的时间戳
    uint256 public lastRebaseTimestamp;
    // 通缩系数（初始为10000，每通缩1%减少100）
    uint256 public deflationFactor = 10000;
    // 用户余额映射（存储原始余额，不考虑通缩）
    mapping(address => uint256) private _originalBalances;

    /**
     * @dev 构造函数
     * @param initialOwner 初始所有者地址
     */
    constructor(address initialOwner) ERC20("Deflationary Token", "DEFL") Ownable(initialOwner) {
        // 记录初始余额
        _originalBalances[initialOwner] = INITIAL_SUPPLY;
        // 设置初始rebase时间戳
        lastRebaseTimestamp = block.timestamp;
    }

    /**
     * @dev 执行rebase操作，进行通缩
     * @notice 每年调用一次，将总供应量减少1%
     */
    function rebase() external onlyOwner {
        // 检查是否已经过了一年
        require(block.timestamp >= lastRebaseTimestamp + 365 days, "Not enough time has passed");
        
        // 计算新的通缩系数
        uint256 newDeflationFactor = deflationFactor - (deflationFactor * ANNUAL_DEFLATION_RATE) / 100;
        require(newDeflationFactor > 0, "Deflation factor cannot be zero");
        
        // 更新通缩系数
        deflationFactor = newDeflationFactor;
        // 更新lastRebaseTimestamp
        lastRebaseTimestamp = block.timestamp;
        
        // 触发Rebase事件
        emit Rebase(deflationFactor);
    }

    /**
     * @dev 获取用户的实际余额（考虑通缩后的余额）
     * @param account 用户地址
     * @return 通缩后的用户余额
     */
    function balanceOf(address account) public view override returns (uint256) {
        // 获取用户的原始余额
        uint256 originalBalance = _originalBalances[account];
        // 计算通缩后的余额
        return (originalBalance * deflationFactor) / 10000;
    }

    /**
     * @dev 获取总供应量（考虑通缩后的总供应量）
     * @return 通缩后的总供应量
     */
    function totalSupply() public view override returns (uint256) {
        // 计算通缩后的总供应量
        return (INITIAL_SUPPLY * deflationFactor) / 10000;
    }

    /**
     * @dev 重写transfer方法，处理通缩后的转账
     * @param to 接收地址
     * @param value 转移金额（通缩后的金额）
     * @return 是否成功
     */
    function transfer(address to, uint256 value) public override returns (bool) {
        // 检查发送者的通缩后余额是否足够
        require(balanceOf(msg.sender) >= value, "Insufficient balance");
        
        // 计算需要转移的原始金额（使用精确计算）
        uint256 transferOriginal = (value * 10000 + deflationFactor - 1) / deflationFactor;
        
        // 更新原始余额
        _originalBalances[msg.sender] -= transferOriginal;
        _originalBalances[to] += transferOriginal;
        
        // 触发Transfer事件
        emit Transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev 重写transferFrom方法，处理通缩后的转账
     * @param from 发送地址
     * @param to 接收地址
     * @param value 转移金额（通缩后的金额）
     * @return 是否成功
     */
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        // 检查发送者的通缩后余额是否足够
        require(balanceOf(from) >= value, "Insufficient balance");
        // 检查授权是否足够
        uint256 currentAllowance = allowance(from, msg.sender);
        require(currentAllowance >= value, "Insufficient allowance");
        
        // 更新授权
        _approve(from, msg.sender, currentAllowance - value);
        
        // 计算需要转移的原始金额（使用精确计算）
        uint256 transferOriginal = (value * 10000 + deflationFactor - 1) / deflationFactor;
        
        // 更新原始余额
        _originalBalances[from] -= transferOriginal;
        _originalBalances[to] += transferOriginal;
        
        // 触发Transfer事件
        emit Transfer(from, to, value);
        return true;
    }

    /**
     * @dev 铸造代币并记录原始余额
     * @param to 接收地址
     * @param amount 铸造金额（通缩后的金额）
     */
    function mint(address to, uint256 amount) external onlyOwner {
        // 计算原始金额（反通缩）
        uint256 originalAmount = (amount * 10000 + deflationFactor - 1) / deflationFactor;
        // 更新接收者的原始余额
        _originalBalances[to] += originalAmount;
        // 触发Transfer事件
        emit Transfer(address(0), to, amount);
    }

    /**
     * @dev 销毁代币并记录原始余额
     * @param amount 销毁金额（通缩后的金额）
     */
    function burn(uint256 amount) external {
        // 检查发送者的通缩后余额是否足够
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        // 获取发送者的当前原始余额
        uint256 senderOriginalBalance = _originalBalances[msg.sender];
        
        // 计算发送者销毁后的通缩后余额
        uint256 senderNewBalance = balanceOf(msg.sender) - amount;
        
        // 计算发送者销毁后的原始余额
        uint256 senderNewOriginalBalance = (senderNewBalance * 10000 + deflationFactor - 1) / deflationFactor;
        
        // 计算需要销毁的原始金额
        uint256 burnOriginal = senderOriginalBalance - senderNewOriginalBalance;
        
        // 更新原始余额
        _originalBalances[msg.sender] = senderNewOriginalBalance;
        
        // 触发Transfer事件
        emit Transfer(msg.sender, address(0), amount);
    }

    // 事件定义
    event Rebase(uint256 newDeflationFactor);
}
