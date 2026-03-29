// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ChainBank.sol";

contract ChainBankTest is Test {
    ChainBank public chainBank;
    
    // 测试用户地址
    address public user1 = address(1);
    address public user2 = address(2);
    address public user3 = address(3);
    address public user4 = address(4);
    address public user5 = address(5);
    address public user6 = address(6);
    address public user7 = address(7);
    address public user8 = address(8);
    address public user9 = address(9);
    address public user10 = address(10);
    address public user11 = address(11);
    
    // 测试金额
    uint256 public amount1 = 100 ether;
    uint256 public amount2 = 200 ether;
    uint256 public amount3 = 300 ether;
    uint256 public amount4 = 400 ether;
    uint256 public amount5 = 500 ether;
    uint256 public amount6 = 600 ether;
    uint256 public amount7 = 700 ether;
    uint256 public amount8 = 800 ether;
    uint256 public amount9 = 900 ether;
    uint256 public amount10 = 1000 ether;
    uint256 public amount11 = 50 ether;
    
    function setUp() public {
        chainBank = new ChainBank();
    }
    
    // 测试存款功能
    function testDeposit() public {
        // 向合约存款
        vm.deal(user1, amount1);
        vm.prank(user1);
        chainBank.deposit{value: amount1}();
        
        // 验证余额
        assertEq(chainBank.getBalance(user1), amount1);
        assertEq(chainBank.getTotalDeposits(), amount1);
    }
    
    // 测试通过receive函数存款
    function testReceiveDeposit() public {
        // 向合约直接转账
        vm.deal(user1, amount1);
        vm.prank(user1);
        (bool success, ) = address(chainBank).call{value: amount1}("");
        assertTrue(success);
        
        // 验证余额
        assertEq(chainBank.getBalance(user1), amount1);
        assertEq(chainBank.getTotalDeposits(), amount1);
    }
    
    // 测试前10名用户链表
    function testTopUsers() public {
        // 向合约存款，创建10个用户
        vm.deal(user1, amount1);
        vm.deal(user2, amount2);
        vm.deal(user3, amount3);
        vm.deal(user4, amount4);
        vm.deal(user5, amount5);
        vm.deal(user6, amount6);
        vm.deal(user7, amount7);
        vm.deal(user8, amount8);
        vm.deal(user9, amount9);
        vm.deal(user10, amount10);
        
        // 按金额从小到大存款
        vm.prank(user1);
        chainBank.deposit{value: amount1}();
        
        vm.prank(user2);
        chainBank.deposit{value: amount2}();
        
        vm.prank(user3);
        chainBank.deposit{value: amount3}();
        
        vm.prank(user4);
        chainBank.deposit{value: amount4}();
        
        vm.prank(user5);
        chainBank.deposit{value: amount5}();
        
        vm.prank(user6);
        chainBank.deposit{value: amount6}();
        
        vm.prank(user7);
        chainBank.deposit{value: amount7}();
        
        vm.prank(user8);
        chainBank.deposit{value: amount8}();
        
        vm.prank(user9);
        chainBank.deposit{value: amount9}();
        
        vm.prank(user10);
        chainBank.deposit{value: amount10}();
        
        // 获取前10名用户
        (address[] memory users, uint256[] memory balances) = chainBank.getTopUsers();
        
        // 验证用户数量
        assertEq(users.length, 10);
        
        // 验证用户顺序（按余额降序）
        assertEq(users[0], user10);
        assertEq(balances[0], amount10);
        
        assertEq(users[1], user9);
        assertEq(balances[1], amount9);
        
        assertEq(users[2], user8);
        assertEq(balances[2], amount8);
        
        assertEq(users[3], user7);
        assertEq(balances[3], amount7);
        
        assertEq(users[4], user6);
        assertEq(balances[4], amount6);
        
        assertEq(users[5], user5);
        assertEq(balances[5], amount5);
        
        assertEq(users[6], user4);
        assertEq(balances[6], amount4);
        
        assertEq(users[7], user3);
        assertEq(balances[7], amount3);
        
        assertEq(users[8], user2);
        assertEq(balances[8], amount2);
        
        assertEq(users[9], user1);
        assertEq(balances[9], amount1);
    }
    
    // 测试超过10个用户的情况
    function testOver10Users() public {
        // 向合约存款，创建11个用户
        vm.deal(user1, amount1);
        vm.deal(user2, amount2);
        vm.deal(user3, amount3);
        vm.deal(user4, amount4);
        vm.deal(user5, amount5);
        vm.deal(user6, amount6);
        vm.deal(user7, amount7);
        vm.deal(user8, amount8);
        vm.deal(user9, amount9);
        vm.deal(user10, amount10);
        vm.deal(user11, amount11);
        
        // 按金额从小到大存款
        vm.prank(user1);
        chainBank.deposit{value: amount1}();
        
        vm.prank(user2);
        chainBank.deposit{value: amount2}();
        
        vm.prank(user3);
        chainBank.deposit{value: amount3}();
        
        vm.prank(user4);
        chainBank.deposit{value: amount4}();
        
        vm.prank(user5);
        chainBank.deposit{value: amount5}();
        
        vm.prank(user6);
        chainBank.deposit{value: amount6}();
        
        vm.prank(user7);
        chainBank.deposit{value: amount7}();
        
        vm.prank(user8);
        chainBank.deposit{value: amount8}();
        
        vm.prank(user9);
        chainBank.deposit{value: amount9}();
        
        vm.prank(user10);
        chainBank.deposit{value: amount10}();
        
        // 存款第11个用户（金额最小）
        vm.prank(user11);
        chainBank.deposit{value: amount11}();
        
        // 获取前10名用户
        (address[] memory users, ) = chainBank.getTopUsers();
        
        // 验证用户数量
        assertEq(users.length, 10);
        
        // 验证第11个用户不在前10名中
        bool user11InList = false;
        for (uint256 i = 0; i < users.length; i++) {
            if (users[i] == user11) {
                user11InList = true;
                break;
            }
        }
        assertFalse(user11InList);
    }
    
    // 测试用户存款更新后链表排序
    function testUpdateUserBalance() public {
        // 向合约存款，创建2个用户
        vm.deal(user1, amount1);
        vm.deal(user2, amount2);
        
        vm.prank(user1);
        chainBank.deposit{value: amount1}();
        
        vm.prank(user2);
        chainBank.deposit{value: amount2}();
        
        // 验证初始排序
        (address[] memory users, uint256[] memory balances) = chainBank.getTopUsers();
        assertEq(users[0], user2);
        assertEq(balances[0], amount2);
        assertEq(users[1], user1);
        assertEq(balances[1], amount1);
        
        // 用户1再次存款，金额超过用户2
        vm.deal(user1, amount10);
        vm.prank(user1);
        chainBank.deposit{value: amount10}();
        
        // 验证更新后的排序
        (address[] memory updatedUsers, uint256[] memory updatedBalances) = chainBank.getTopUsers();
        assertEq(updatedUsers[0], user1);
        assertEq(updatedBalances[0], amount1 + amount10);
        assertEq(updatedUsers[1], user2);
        assertEq(updatedBalances[1], amount2);
    }
}