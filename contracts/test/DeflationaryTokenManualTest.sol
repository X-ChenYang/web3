// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/deflationary/DeflationaryToken.sol";

/**
 * @title DeflationaryTokenManualTest 手动测试合约
 * @dev 手动测试通缩型Token的功能
 */
contract DeflationaryTokenManualTest is Test {
    // 通缩型Token合约实例
    DeflationaryToken public deflationaryToken;
    // 测试账户Alice
    address public alice = makeAddr("alice");

    /**
     * @dev 测试设置函数
     * @notice 在每个测试用例执行前运行
     */
    function setUp() public {
        // 部署通缩型Token合约
        deflationaryToken = new DeflationaryToken(address(this));
    }

    /**
     * @dev 手动测试rebase后的转账
     * @notice 测试rebase后转账是否正确
     */
    function testManualTransferAfterRebase() public {
        // 第一次rebase（1年后）
        vm.warp(block.timestamp + 365 days);
        deflationaryToken.rebase();
        assertEq(deflationaryToken.deflationFactor(), 9900);
        
        // 计算初始余额
        uint256 initialBalance = deflationaryToken.balanceOf(address(this));
        console.log("Initial balance:", initialBalance);
        
        // 转账100个代币给Alice（通缩后的100个）
        uint256 transferAmount = 100 * 10**18;
        console.log("Transfer amount:", transferAmount);
        
        deflationaryToken.transfer(alice, transferAmount);
        
        // 验证Alice的余额
        uint256 aliceBalance = deflationaryToken.balanceOf(alice);
        console.log("Alice balance:", aliceBalance);
        assertEq(aliceBalance, transferAmount);
        
        // 验证部署者的余额
        uint256 finalBalance = deflationaryToken.balanceOf(address(this));
        console.log("Final balance:", finalBalance);
        
        // 计算预期余额
        uint256 expectedBalance = initialBalance - transferAmount;
        console.log("Expected balance:", expectedBalance);
        
        // 检查余额是否在预期范围内（允许1 wei的误差）
        assertLe(finalBalance, expectedBalance + 1, "Balance should not exceed expected by more than 1 wei");
        assertGe(finalBalance, expectedBalance - 1, "Balance should not be less than expected by more than 1 wei");
    }
}