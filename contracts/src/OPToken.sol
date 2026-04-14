// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title OPToken
 * @dev 看涨期权ERC20代币合约
 * @notice 本合约实现了基于ETH的看涨期权，支持发行、行权和过期销毁功能
 */
contract OPToken is ERC20, Ownable {
    using SafeERC20 for IERC20;
    
    // 错误类型
    error ZeroAmount();
    error NotExerciseDay();
    error NotExpired();
    error AlreadyExpired();
    error MintClosed();
    error TransferFailed();
    error InsufficientOPTokenBalance();
    
    // 行权价格（1800 USDT/ETH）
    uint256 public constant STRIKE_PRICE = 1800 ether;
    // 行权日期（2026/10/1 00:00:00 UTC）
    uint256 public constant EXERCISE_DATE = 1780416000;
    // 行权窗口
    uint256 public constant EXERCISE_WINDOW = 1 days;
    // USDT代币地址
    IERC20 public immutable usdt;
    // 合约是否已过期
    bool public expired;
    // 标的资产ETH的持有量
    uint256 public ethReserve;
    
    /**
     * @dev 构造函数
     * @param initialOwner 初始所有者
     * @param usdt_ USDT代币地址
     */
    constructor(
        address initialOwner,
        IERC20 usdt_
    ) ERC20("Option Token", "OP") Ownable(initialOwner) {
        usdt = usdt_;
    }
    
    /**
     * @dev 发行期权（项目方角色）
     * @notice 根据转入的ETH发行等量的期权Token
     * @param to 接收地址
     */
    function mint(address to) external payable onlyOwner {
        if (msg.value == 0) revert ZeroAmount();
        if (expired) revert AlreadyExpired();
        if (block.timestamp >= EXERCISE_DATE) revert MintClosed();
        
        uint256 amount = msg.value;
        _mint(to, amount);
        ethReserve += amount;
    }
    
    /**
     * @dev 行权方法（用户角色）
     * @notice 在行权窗口内，通过转入OPToken和对应的行权价格的USDT来兑换出ETH，并销毁期权Token
     * @param amount 行权数量
     */
    function exercise(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (expired) revert AlreadyExpired();
        if (!_isExerciseDay(block.timestamp)) revert NotExerciseDay();
        if (balanceOf(msg.sender) < amount) revert InsufficientOPTokenBalance();
        
        // 计算需要的USDT数量
        uint256 usdtAmount = (amount * STRIKE_PRICE) / 1 ether;
        
        // 转移USDT
        usdt.safeTransferFrom(msg.sender, owner(), usdtAmount);
        
        // 销毁OPToken
        _burn(msg.sender, amount);
        
        // 减少ETH储备
        ethReserve -= amount;
        
        // 发送ETH给用户
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();
    }
    
    /**
     * @dev 过期销毁（项目方角色）
     * @notice 标记合约过期并赎回剩余的ETH
     */
    function expire() external onlyOwner {
        if (block.timestamp < EXERCISE_DATE + EXERCISE_WINDOW) revert NotExpired();
        if (expired) revert AlreadyExpired();
        
        expired = true;
        
        // 赎回剩余的ETH
        uint256 remainingETH = address(this).balance;
        if (remainingETH != 0) {
            (bool success, ) = payable(owner()).call{value: remainingETH}("");
            if (!success) revert TransferFailed();
        }
    }
    
    /**
     * @dev 检查是否在行权窗口内
     * @param timestamp 时间戳
     * @return bool 是否在行权窗口内
     */
    function _isExerciseDay(uint256 timestamp) internal pure returns (bool) {
        return timestamp >= EXERCISE_DATE && timestamp < EXERCISE_DATE + EXERCISE_WINDOW;
    }
    
    /**
     * @dev 接收ETH
     */
    receive() external payable {}
}