// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SimpleLeverageDEX 极简杠杆DEX
 * @dev 基于vAMM机制实现的简单杠杆DEX
 */
contract SimpleLeverageDEX {
    // 稳定币合约地址
    IERC20 public USDC;
    
    // 头寸状态
    enum Position { NONE, LONG, SHORT }
    
    // 头寸信息
    struct PositionInfo {
        uint256 margin;        // 保证金
        uint256 borrowed;      // 借入金额
        Position position;      // 头寸方向
        uint level;            // 杠杆倍数
    }
    
    // 用户头寸映射
    mapping(address => PositionInfo) public positions;
    
    // 价格模拟（实际应用中应使用预言机）
    uint256 public constant INITIAL_PRICE = 1000 ether; // 初始价格为1000 USDC
    uint256 public currentPrice = INITIAL_PRICE;
    
    /**
     * @dev 构造函数
     * @param _usdc USDC合约地址
     */
    constructor(address _usdc) {
        USDC = IERC20(_usdc);
    }
    
    /**
     * @dev 开启杠杆头寸
     * @param _margin 保证金金额
     * @param level 杠杆倍数
     * @param long 是否为多头
     */
    function openPosition(uint256 _margin, uint level, bool long) external {
        require(positions[msg.sender].position == Position.NONE, "Position already open");
        
        PositionInfo storage pos = positions[msg.sender];
        
        // 用户提供保证金
        USDC.transferFrom(msg.sender, address(this), _margin);
        
        uint256 amount = _margin * level;
        uint256 borrowedAmount = amount - _margin;
        
        pos.margin = _margin;
        pos.borrowed = borrowedAmount;
        
        // 设置头寸方向
        if (long) {
            pos.position = Position.LONG;
        } else {
            pos.position = Position.SHORT;
        }
        
        pos.level = level;
    }
    
    /**
     * @dev 关闭头寸并结算，不考虑协议亏损
     * @notice 返还保证金 + 盈利（如果盈利的话），亏损时扣除相应金额
     */
    function closePosition() external {
        PositionInfo storage pos = positions[msg.sender];
        require(pos.position != Position.NONE, "No open position");
        
        // 计算盈亏
        int256 pnl = calculatePnL(msg.sender);
        
        // 计算应返还给用户的金额
        uint256 refundAmount = pos.margin;
        if (pnl > 0) {
            // 如果盈利，返还保证金 + 盈利
            refundAmount += uint256(pnl);
        } else if (pnl < 0) {
            // 如果亏损，从保证金中扣除亏损金额
            uint256 lossAmount = uint256(-pnl);
            if (lossAmount > pos.margin) {
                // 亏损超过保证金，只返还0（简化处理）
                refundAmount = 0;
            } else {
                // 亏损未超过保证金，返还剩余保证金
                refundAmount -= lossAmount;
            }
        }
        
        // 返还资金给用户
        if (refundAmount > 0) {
            USDC.transfer(msg.sender, refundAmount);
        }
        
        // 清理头寸
        delete positions[msg.sender];
    }
    
    /**
     * @dev 清算头寸
     * @param _user 要清算的用户地址
     */
    function liquidatePosition(address _user) external {
        PositionInfo storage pos = positions[_user];
        require(pos.position != Position.NONE, "No open position");
        
        // 计算盈亏
        int256 pnl = calculatePnL(_user);
        
        // 检查是否需要清算（保证金不足）
        // 这里简化处理，当保证金亏损超过80%时触发清算
        // 即：当 pnl < -pos.margin * 0.8 时触发清算
        if (pnl < -int256(pos.margin * 80 / 100)) {
            // 清理头寸
            delete positions[_user];
        }
    }
    
    /**
     * @dev 计算盈亏
     * @param user 用户地址
     * @return 盈亏金额
     */
    function calculatePnL(address user) public view returns (int256) {
        PositionInfo storage pos = positions[user];
        require(pos.position != Position.NONE, "No open position");
        
        uint256 initialPrice = INITIAL_PRICE;
        
        int256 pnl;
        if (pos.position == Position.LONG) {
            // 多头：价格上涨盈利，下跌亏损
            if (currentPrice >= initialPrice) {
                uint256 priceChange = currentPrice - initialPrice;
                pnl = int256((priceChange * (pos.margin + pos.borrowed)) / initialPrice);
            } else {
                uint256 priceChange = initialPrice - currentPrice;
                pnl = -int256((priceChange * (pos.margin + pos.borrowed)) / initialPrice);
            }
        } else {
            // 空头：价格下跌盈利，上涨亏损
            if (currentPrice <= initialPrice) {
                uint256 priceChange = initialPrice - currentPrice;
                pnl = int256((priceChange * (pos.margin + pos.borrowed)) / initialPrice);
            } else {
                uint256 priceChange = currentPrice - initialPrice;
                pnl = -int256((priceChange * (pos.margin + pos.borrowed)) / initialPrice);
            }
        }
        
        return pnl;
    }
    
    /**
     * @dev 模拟价格变化（实际应用中应使用预言机）
     * @param newPrice 新价格
     */
    function setPrice(uint256 newPrice) external {
        currentPrice = newPrice;
    }
}