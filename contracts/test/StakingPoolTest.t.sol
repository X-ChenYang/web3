// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/staking/KKToken.sol";
import "../src/staking/StakingPool.sol";

/**
 * @title StakingPoolTest 测试合约
 * @dev 测试KKToken和StakingPool合约的功能
 */
contract StakingPoolTest is Test {
    // KK Token合约实例
    KKToken public kkToken;
    // StakingPool合约实例
    StakingPool public stakingPool;
    // 测试账户Alice
    address public alice = makeAddr("alice");
    // 测试账户Bob
    address public bob = makeAddr("bob");

    /**
     * @dev 测试设置函数
     * @notice 在每个测试用例执行前运行
     * 部署KK Token和StakingPool合约，并将KK Token的所有权转移给StakingPool
     */
    function setUp() public {
        // 部署KK Token合约，将部署者设为初始所有者
        kkToken = new KKToken(address(this));
        
        // 部署StakingPool合约，将部署者设为初始所有者
        stakingPool = new StakingPool(address(this), address(kkToken));
        
        // 将KK Token的所有权转移给StakingPool，使其具备铸造权限
        kkToken.transferOwnership(address(stakingPool));
    }

    /**
     * @dev 测试质押功能
     * @notice 测试用户是否可以成功质押ETH
     */
    function testStake() public {
        // 模拟Alice调用stake方法
        vm.prank(alice);
        // 给Alice账户发送1 ETH
        vm.deal(alice, 1 ether);
        // Alice质押1 ETH
        stakingPool.stake{value: 1 ether}();
        
        // 验证Alice的质押数量是否正确
        assertEq(stakingPool.balanceOf(alice), 1 ether);
    }

    /**
     * @dev 测试赎回功能
     * @notice 测试用户是否可以成功赎回质押的ETH
     */
    function testUnstake() public {
        // 模拟Alice质押1 ETH
        vm.prank(alice);
        vm.deal(alice, 1 ether);
        stakingPool.stake{value: 1 ether}();
        
        // 模拟Alice赎回0.5 ETH
        vm.prank(alice);
        stakingPool.unstake(0.5 ether);
        
        // 验证Alice剩余的质押数量是否正确
        assertEq(stakingPool.balanceOf(alice), 0.5 ether);
    }

    /**
     * @dev 测试领取收益功能
     * @notice 测试用户是否可以成功领取KK Token收益
     */
    function testClaim() public {
        // 模拟Alice质押1 ETH
        vm.prank(alice);
        vm.deal(alice, 1 ether);
        stakingPool.stake{value: 1 ether}();
        
        // 增加区块高度，产生10个区块的奖励
        vm.roll(block.number + 10);
        
        // 模拟Alice领取收益
        vm.prank(alice);
        stakingPool.claim();
        
        // 验证Alice获得了KK Token
        assertGt(kkToken.balanceOf(alice), 0);
    }

    /**
     * @dev 测试earned方法
     * @notice 测试earned方法是否返回正确的待领取收益
     */
    function testEarned() public {
        // 模拟Alice质押1 ETH
        vm.prank(alice);
        vm.deal(alice, 1 ether);
        stakingPool.stake{value: 1 ether}();
        
        // 增加区块高度，产生5个区块的奖励
        vm.roll(block.number + 5);
        
        // 调用earned方法获取待领取收益
        uint256 earnedAmount = stakingPool.earned(alice);
        // 验证待领取收益大于0
        assertGt(earnedAmount, 0);
    }

    /**
     * @dev 测试奖励分配机制
     * @notice 测试奖励是否根据质押数量按比例分配
     */
    function testRewardDistribution() public {
        // 模拟Alice质押2 ETH
        vm.prank(alice);
        vm.deal(alice, 2 ether);
        stakingPool.stake{value: 2 ether}();
        
        // 模拟Bob质押1 ETH
        vm.prank(bob);
        vm.deal(bob, 1 ether);
        stakingPool.stake{value: 1 ether}();
        
        // 增加区块高度，产生3个区块的奖励
        vm.roll(block.number + 3);
        
        // 模拟Alice领取收益
        vm.prank(alice);
        stakingPool.claim();
        
        // 模拟Bob领取收益
        vm.prank(bob);
        stakingPool.claim();
        
        // 验证Alice获得的奖励是Bob的两倍（因为质押了两倍的ETH）
        assertEq(kkToken.balanceOf(alice), 2 * kkToken.balanceOf(bob));
    }
}

