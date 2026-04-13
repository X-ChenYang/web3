// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SimpleLeverageDEX1
 * @dev 基于vAMM机制的极简杠杆DEX合约
 * @notice 实现了开启杠杆头寸、关闭头寸并结算、清算头寸等功能
 * @notice 引入预言机价格字段，盈亏计算基于预言机价格
 */
contract SimpleLeverageDEX1 {
    /**
     * @dev 虚拟池常数，由初始vETH和vUSDC数量计算得出
     * @notice vK = vETHAmount * vUSDCAmount，用于维持虚拟池的恒定乘积
     */
    uint public vK;  // 虚拟池常数
    
    /**
     * @dev 虚拟池中的vETH数量
     * @notice 用于计算vETH价格和处理交易
     */
    uint public vETHAmount;
    
    /**
     * @dev 虚拟池中的vUSDC数量
     * @notice 用于计算vETH价格和处理交易
     */
    uint public vUSDCAmount;

    /**
     * @dev USDC代币接口
     * @notice 用于处理真实资金的转账
     */
    IERC20 public USDC;  // USDC代币接口

    /**
     * @dev 预言机价格（USDC/ETH）
     * @notice 用于计算盈亏和清算定价
     */
    uint public oraclePrice;  // 预言机价格（USDC/ETH）

    /**
     * @dev 开仓时的预言机价格
     * @notice 存储用户开仓时的预言机价格，用于计算盈亏
     */
    mapping(address => uint) public openPrice;  // 开仓时的预言机价格

    /**
     * @dev 头寸信息结构体
     * @notice 存储用户的头寸数据
     */
    struct PositionInfo {
        uint256 margin;     // 保证金（真实USDC资金）
        uint256 borrowed;   // 借入的资金
        int256 position;    // 虚拟ETH持仓（正数为多头，负数为空头）
    }
    
    /**
     * @dev 用户地址到头寸信息的映射
     * @notice 存储每个用户的头寸数据
     */
    mapping(address => PositionInfo) public positions;

    /**
     * @dev 构造函数
     * @param _usdc USDC代币地址
     * @param vEth 初始虚拟ETH数量
     * @param vUSDC 初始虚拟USDC数量
     * @notice 初始化合约状态，设置虚拟池参数和初始预言机价格
     */
    constructor(address _usdc, uint vEth, uint vUSDC) {
        USDC = IERC20(_usdc);
        vETHAmount = vEth;
        vUSDCAmount = vUSDC;
        vK = vEth * vUSDC;  // 计算虚拟池常数
        oraclePrice = vUSDC * 1e18 / vEth;  // 初始预言机价格设为初始池内价格
    }

    /**
     * @dev 设置预言机价格
     * @param _price 新的预言机价格（USDC/ETH）
     * @notice 用于测试验证，模拟预言机价格更新
     */
    function setOraclePrice(uint _price) external {
        oraclePrice = _price;
    }

    /**
     * @dev 开启杠杆头寸
     * @param _margin 保证金金额（USDC）
     * @param level 杠杆倍数
     * @param long 是否为多头（true为多头，false为空头）
     * @notice 根据杠杆倍数和方向开启头寸，更新虚拟池参数
     * @notice 开仓时按池内价格计算用户仓位大小，记录开仓时的预言机价格
     */
    function openPosition(uint256 _margin, uint level, bool long) external {
        // 验证用户没有未平仓头寸
        require(positions[msg.sender].position == 0, "Position already open");
        // 验证杠杆倍数大于0
        require(level > 0, "Level must be greater than 0");

        // 获取用户头寸信息
        PositionInfo storage pos = positions[msg.sender];

        // 用户转移保证金到合约
        USDC.transferFrom(msg.sender, address(this), _margin);
        
        // 安全计算总交易金额，防止溢出
        uint amount = _margin * level;
        require(amount >= _margin, "Amount overflow");
        
        // 计算借入金额
        uint256 borrowAmount = amount - _margin;

        // 记录开仓时的预言机价格
        openPrice[msg.sender] = oraclePrice;

        // 更新头寸信息
        pos.margin = _margin;
        pos.borrowed = borrowAmount;
        
        if (long) {
            // 多头：从虚拟池购买vETH
            // 计算新的vUSDC数量
            uint newVUSDCAmount = vUSDCAmount + amount;
            require(newVUSDCAmount > vUSDCAmount, "newVUSDCAmount overflow");
            require(newVUSDCAmount > 0, "newVUSDCAmount cannot be zero");
            
            // 确保交易金额不会导致虚拟池异常
            require(newVUSDCAmount <= vK, "Amount too large");
            
            // 计算新的vETH数量
            uint newVETHAmount = vK / newVUSDCAmount;
            require(newVETHAmount > 0, "newVETHAmount cannot be zero");
            require(newVETHAmount < vETHAmount, "Insufficient vETH in pool");
            
            // 计算购买的vETH数量
            uint boughtVETH = vETHAmount - newVETHAmount;
            
            // 更新虚拟池参数
            vETHAmount = newVETHAmount;
            vUSDCAmount = newVUSDCAmount;
            
            // 设置多头头寸（正数）
            pos.position = int256(boughtVETH);
        } else {
            // 空头：向虚拟池卖出vETH
            // 验证虚拟池中有足够的vUSDC
            require(vUSDCAmount > 0, "vUSDCAmount cannot be zero");
            
            // 安全计算，防止溢出
            uint vethValue = amount * vETHAmount;
            require(vethValue / amount == vETHAmount, "Overflow in calculation");
            
            // 计算卖出的vETH数量
            uint soldVETH = vethValue / vUSDCAmount;
            require(soldVETH > 0, "Sold VETH must be greater than 0");
            
            // 计算新的vETH数量
            uint newVETHAmount = vETHAmount + soldVETH;
            require(newVETHAmount > vETHAmount, "newVETHAmount overflow");
            
            // 确保交易金额不会导致虚拟池异常
            require(newVETHAmount <= vK, "Amount too large");
            
            // 计算新的vUSDC数量
            uint newVUSDCAmount = vK / newVETHAmount;
            require(newVUSDCAmount > 0, "newVUSDCAmount cannot be zero");
            
            // 更新虚拟池参数
            vETHAmount = newVETHAmount;
            vUSDCAmount = newVUSDCAmount;
            
            // 设置空头头寸（负数）
            pos.position = -int256(soldVETH);
        }
    }

    /**
     * @dev 关闭头寸并结算
     * @notice 计算盈亏并返还资金给用户，不考虑协议亏损
     * @notice 平仓时按预言机价格计算盈亏
     */
    function closePosition() external {
        // 获取用户头寸信息
        PositionInfo storage pos = positions[msg.sender];
        // 验证用户有未平仓头寸
        require(pos.position != 0, "No open position");
        
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
        
        // 清理头寸和开仓价格记录
        delete positions[msg.sender];
        delete openPrice[msg.sender];
    }

    /**
     * @dev 清算头寸
     * @param _user 需要清算的用户地址
     * @notice 当用户亏损超过保证金80%时，可由其他用户清算，清算人获取剩余资金
     * @notice 清算时按预言机价格计算盈亏
     */
    function liquidatePosition(address _user) external {
        // 验证清算人不是用户自己
        require(msg.sender != _user, "Cannot liquidate yourself");
        
        // 获取用户头寸信息
        PositionInfo storage position = positions[_user];
        // 验证用户有未平仓头寸
        require(position.position != 0, "No open position");
        
        // 计算盈亏
        int256 pnl = calculatePnL(_user);
        
        // 检查清算条件：亏损大于保证金的80%
        require(pnl < -int256(position.margin * 80 / 100), "Not eligible for liquidation");
        
        // 计算清算后的金额
        uint256 refundAmount = position.margin;
        if (pnl > 0) {
            // 如果盈利，清算人获取保证金 + 盈利
            refundAmount += uint256(pnl);
        } else {
            // 如果亏损，清算人获取剩余保证金
            uint256 lossAmount = uint256(-pnl);
            if (lossAmount < position.margin) {
                refundAmount -= lossAmount;
            } else {
                refundAmount = 0;
            }
        }
        
        // 返还资金给清算人
        if (refundAmount > 0) {
            USDC.transfer(msg.sender, refundAmount);
        }
        
        // 清理头寸和开仓价格记录
        delete positions[_user];
        delete openPrice[_user];
    }

    /**
     * @dev 计算盈亏
     * @param user 用户地址
     * @return pnl 盈亏金额
     * @notice 基于预言机价格计算头寸盈亏
     * @notice 开仓价格为开仓时的预言机价格，当前价格为最新的预言机价格
     */
    function calculatePnL(address user) public view returns (int256) {
        // 获取用户头寸信息
        PositionInfo memory pos = positions[user];
        // 验证用户有未平仓头寸
        require(pos.position != 0, "No open position");
        
        // 获取开仓时的预言机价格和当前预言机价格
        uint openOraclePrice = openPrice[user];
        uint currentOraclePrice = oraclePrice;
        
        int256 pnl;
        if (pos.position > 0) {
            // 多头：价格上涨盈利，下跌亏损
            int256 priceDiff = int256(currentOraclePrice) - int256(openOraclePrice);
            pnl = priceDiff * int256(pos.position) / 1e18;
        } else {
            // 空头：价格下跌盈利，上涨亏损
            int256 priceDiff = int256(openOraclePrice) - int256(currentOraclePrice);
            pnl = priceDiff * int256(-pos.position) / 1e18;
        }
        
        return pnl;
    }
}