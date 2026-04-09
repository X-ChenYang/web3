// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./KKToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IStaking 接口
 * @dev 定义了质押相关的核心方法
 */
interface IStaking {
    /**
     * @dev 质押ETH到合约
     * @notice 调用时需要附带ETH
     */
    function stake() payable external;

    /**
     * @dev 赎回质押的ETH
     * @param amount 赎回数量
     */
    function unstake(uint256 amount) external;

    /**
     * @dev 领取KK Token收益
     */
    function claim() external;

    /**
     * @dev 获取质押的ETH数量
     * @param account 质押账户
     * @return 质押的ETH数量
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev 获取待领取的KK Token收益
     * @param account 质押账户
     * @return 待领取的KK Token收益
     */
    function earned(address account) external view returns (uint256);
}

/**
 * @title StakingPool 合约
 * @dev 实现了IStaking接口，允许用户质押ETH赚取KK Token
 * 每区块产出10个KK Token，根据质押时长和数量公平分配
 */
contract StakingPool is Ownable, IStaking {
    // KK Token合约实例
    KKToken public kkToken;
    // 每区块产出的KK Token数量（10个）
    uint256 public constant REWARD_PER_BLOCK = 10 * 10**18;
    // 上一次计算奖励的区块号
    uint256 public lastRewardBlock;
    // 累积的KK Token每股收益（精度1e18）
    uint256 public accKkPerShare;
    // 总质押ETH数量
    uint256 public totalStaked;

    /**
     * @dev 用户信息结构体
     * @param amount 用户质押的ETH数量
     * @param rewardDebt 已领取的奖励债务（用于计算待领取奖励）
     */
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    // 用户信息映射
    mapping(address => UserInfo) public userInfo;

    // 事件定义
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);

    /**
     * @dev 构造函数
     * @param _kkToken KK Token合约地址
     */
    constructor(address initialOwner, address _kkToken) Ownable(initialOwner) {
        kkToken = KKToken(_kkToken);
        lastRewardBlock = block.number;
    }

    /**
     * @dev 质押ETH到合约
     * @notice 调用时需要附带ETH
     */
    function stake() payable public override {
        // 更新奖励池状态
        updatePool();
        
        // 获取质押的ETH数量
        uint256 amount = msg.value;
        require(amount > 0, "Amount must be greater than 0");

        // 获取用户信息
        UserInfo storage user = userInfo[msg.sender];
        
        // 如果用户已有质押，先领取之前的奖励
        if (user.amount > 0) {
            uint256 pending = user.amount * accKkPerShare / 1e18 - user.rewardDebt;
            if (pending > 0) {
                kkToken.mint(msg.sender, pending);
                emit Claimed(msg.sender, pending);
            }
        }

        // 更新用户质押数量和奖励债务
        user.amount += amount;
        user.rewardDebt = user.amount * accKkPerShare / 1e18;
        
        // 更新总质押数量
        totalStaked += amount;

        // 发射质押事件
        emit Staked(msg.sender, amount);
    }

    /**
     * @dev 赎回质押的ETH
     * @param amount 赎回数量
     */
    function unstake(uint256 amount) external override {
        // 更新奖励池状态
        updatePool();
        
        // 获取用户信息
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= amount, "Insufficient staked amount");

        // 领取待领取的奖励
        uint256 pending = user.amount * accKkPerShare / 1e18 - user.rewardDebt;
        if (pending > 0) {
            kkToken.mint(msg.sender, pending);
            emit Claimed(msg.sender, pending);
        }

        // 更新用户质押数量和奖励债务
        user.amount -= amount;
        user.rewardDebt = user.amount * accKkPerShare / 1e18;
        
        // 更新总质押数量
        totalStaked -= amount;

        // 转账ETH给用户
        payable(msg.sender).transfer(amount);
        
        // 发射赎回事件
        emit Unstaked(msg.sender, amount);
    }

    /**
     * @dev 领取KK Token收益
     */
    function claim() external override {
        // 更新奖励池状态
        updatePool();
        
        // 获取用户信息
        UserInfo storage user = userInfo[msg.sender];
        
        // 计算待领取的奖励
        uint256 pending = user.amount * accKkPerShare / 1e18 - user.rewardDebt;
        if (pending > 0) {
            // 铸造KK Token给用户
            kkToken.mint(msg.sender, pending);
            // 更新用户奖励债务
            user.rewardDebt = user.amount * accKkPerShare / 1e18;
            // 发射领取事件
            emit Claimed(msg.sender, pending);
        }
    }

    /**
     * @dev 获取质押的ETH数量
     * @param account 质押账户
     * @return 质押的ETH数量
     */
    function balanceOf(address account) external view override returns (uint256) {
        return userInfo[account].amount;
    }

    /**
     * @dev 获取待领取的KK Token收益
     * @param account 质押账户
     * @return 待领取的KK Token收益
     */
    function earned(address account) external view override returns (uint256) {
        // 获取用户信息
        UserInfo storage user = userInfo[account];
        // 复制当前的累积收益值
        uint256 currentAccKkPerShare = accKkPerShare;
        
        // 如果区块号大于上一次奖励计算的区块号，且总质押量大于0
        if (block.number > lastRewardBlock && totalStaked > 0) {
            // 计算经过的区块数
            uint256 blocks = block.number - lastRewardBlock;
            // 计算应分配的KK Token数量
            uint256 kkReward = blocks * REWARD_PER_BLOCK;
            // 计算新的累积收益值
            currentAccKkPerShare += kkReward * 1e18 / totalStaked;
        }
        
        // 计算用户待领取的奖励
        return user.amount * currentAccKkPerShare / 1e18 - user.rewardDebt;
    }

    /**
     * @dev 更新奖励池状态
     * @notice 计算从上次更新到现在的奖励，并更新累积收益值
     */
    function updatePool() public {
        // 如果当前区块号小于等于上一次奖励计算的区块号，直接返回
        if (block.number <= lastRewardBlock) {
            return;
        }
        
        // 如果总质押量为0，更新上一次奖励计算的区块号并返回
        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }
        
        // 计算经过的区块数
        uint256 blocks = block.number - lastRewardBlock;
        // 计算应分配的KK Token数量
        uint256 kkReward = blocks * REWARD_PER_BLOCK;
        // 更新累积收益值
        accKkPerShare += kkReward * 1e18 / totalStaked;
        // 更新上一次奖励计算的区块号
        lastRewardBlock = block.number;
    }

    /**
     * @dev 允许合约接收ETH
     * @notice 当直接向合约转账ETH时，会自动调用stake方法
     */
    receive() external payable {
        stake();
    }
}

