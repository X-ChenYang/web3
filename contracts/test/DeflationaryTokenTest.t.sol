// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/deflationary/DeflationaryToken.sol";

/**
 * @title DeflationaryTokenTest 测试合约
 * @dev 测试通缩型Token的功能
 */
contract DeflationaryTokenTest is Test {
    // 通缩型Token合约实例
    DeflationaryToken public deflationaryToken;
    // 测试账户Alice
    address public alice = makeAddr("alice");
    // 测试账户Bob
    address public bob = makeAddr("bob");

    /**
     * @dev 测试设置函数
     * @notice 在每个测试用例执行前运行
     */
    function setUp() public {
        // 部署通缩型Token合约
        deflationaryToken = new DeflationaryToken(address(this));
    }

    /**
     * @dev 测试初始余额
     * @notice 测试初始供应量是否正确
     */
    function testInitialSupply() public {
        // 验证部署者的余额是否为初始供应量
        assertEq(deflationaryToken.balanceOf(address(this)), 100_000_000 * 10**18);
        // 验证总供应量是否为初始供应量
        assertEq(deflationaryToken.totalSupply(), 100_000_000 * 10**18);
        // 验证初始通缩系数是否为10000
        assertEq(deflationaryToken.deflationFactor(), 10000);
    }

    /**
     * @dev 测试转账功能
     * @notice 测试转账后余额是否正确
     */
    function testTransfer() public {
        // 转账100个代币给Alice
        uint256 transferAmount = 100 * 10**18;
        deflationaryToken.transfer(alice, transferAmount);
        
        // 验证Alice的余额
        assertEq(deflationaryToken.balanceOf(alice), transferAmount);
        // 验证部署者的余额
        assertEq(deflationaryToken.balanceOf(address(this)), 100_000_000 * 10**18 - transferAmount);
    }

    /**
     * @dev 测试rebase功能
     * @notice 测试rebase后余额是否正确通缩
     */
    function testRebase() public {
        // 转账100个代币给Alice
        uint256 transferAmount = 100 * 10**18;
        deflationaryToken.transfer(alice, transferAmount);
        
        // 模拟时间流逝1年
        vm.warp(block.timestamp + 365 days);
        
        // 执行rebase操作
        deflationaryToken.rebase();
        
        // 验证通缩系数是否变为9900（减少1%）
        assertEq(deflationaryToken.deflationFactor(), 9900);
        
        // 计算通缩后的余额
        uint256 expectedAliceBalance = (transferAmount * 9900) / 10000;
        uint256 expectedDeployerBalance = ((100_000_000 * 10**18 - transferAmount) * 9900) / 10000;
        uint256 expectedTotalSupply = (100_000_000 * 10**18 * 9900) / 10000;
        
        // 验证Alice的余额
        assertEq(deflationaryToken.balanceOf(alice), expectedAliceBalance);
        // 验证部署者的余额
        assertEq(deflationaryToken.balanceOf(address(this)), expectedDeployerBalance);
        // 验证总供应量
        assertEq(deflationaryToken.totalSupply(), expectedTotalSupply);
    }

    /**
     * @dev 测试多次rebase
     * @notice 测试多次rebase后余额是否正确
     */
    function testMultipleRebase() public {
        // 转账100个代币给Alice
        uint256 transferAmount = 100 * 10**18;
        deflationaryToken.transfer(alice, transferAmount);
        
        // 第一次rebase（1年后）
        vm.warp(block.timestamp + 365 days);
        deflationaryToken.rebase();
        assertEq(deflationaryToken.deflationFactor(), 9900);
        
        // 第二次rebase（又1年后）
        vm.warp(block.timestamp + 365 days);
        deflationaryToken.rebase();
        assertEq(deflationaryToken.deflationFactor(), 9801); // 9900 * 0.99
        
        // 计算两次通缩后的余额
        uint256 expectedAliceBalance = (transferAmount * 9801) / 10000;
        uint256 expectedDeployerBalance = ((100_000_000 * 10**18 - transferAmount) * 9801) / 10000;
        uint256 expectedTotalSupply = (100_000_000 * 10**18 * 9801) / 10000;
        
        // 验证Alice的余额
        assertEq(deflationaryToken.balanceOf(alice), expectedAliceBalance);
        // 验证部署者的余额
        assertEq(deflationaryToken.balanceOf(address(this)), expectedDeployerBalance);
        // 验证总供应量
        assertEq(deflationaryToken.totalSupply(), expectedTotalSupply);
    }

    /**
     * @dev 测试rebase前的转账
     * @notice 测试rebase后转账是否正确
     */
    function testTransferAfterRebase() public {
        // 第一次rebase（1年后）
        vm.warp(block.timestamp + 365 days);
        deflationaryToken.rebase();
        assertEq(deflationaryToken.deflationFactor(), 9900);
        
        // 转账100个代币给Alice（通缩后的100个）
        uint256 transferAmount = 100 * 10**18;
        
        // 记录转账前的余额
        uint256 beforeBalance = deflationaryToken.balanceOf(address(this));
        
        deflationaryToken.transfer(alice, transferAmount);
        
        // 验证Alice的余额
        uint256 aliceBalance = deflationaryToken.balanceOf(alice);
        assertEq(aliceBalance, transferAmount);
        
        // 验证部署者的余额
        uint256 afterBalance = deflationaryToken.balanceOf(address(this));
        // 计算预期余额（直接使用转账前余额减去转账金额）
        uint256 expectedDeployerBalance = beforeBalance - transferAmount;
        
        // 检查余额是否在预期范围内（允许1 wei的误差）
        assertLe(afterBalance, expectedDeployerBalance + 1, "Balance should not exceed expected by more than 1 wei");
        assertGe(afterBalance, expectedDeployerBalance - 1, "Balance should not be less than expected by more than 1 wei");
    }
}
