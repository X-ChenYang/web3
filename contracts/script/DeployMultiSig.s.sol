// SPDX-License-Identifier: MIT
//  SPDX 许可证标识符：MIT
//  多签钱包部署脚本
pragma solidity ^0.8.0;
import "forge-std/console.sol";
import "forge-std/Script.sol";
// 导入 Script 基类，用于编写部署脚本
import {Script} from "forge-std/Script.sol";
// 导入多签钱包合约
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

/**
 * @title 多签钱包部署脚本
 * @dev 用于部署多签钱包合约并配置初始参数
 */
contract DeployMultiSig is Script {
    /**
     * @dev 部署函数
     * 执行步骤：
     * 1. 开始广播交易
     * 2. 定义多签持有人列表
     * 3. 部署多签钱包合约
     * 4. 结束广播
     * 5. 输出部署信息
     */
    function run() external {
        // 开始广播交易 - 使用默认私钥签名交易
        vm.startBroadcast();
        
        // 定义多签持有人列表
        // 这里创建一个包含3个地址的数组
        address[] memory owners = new address[](3);
        // 账户1 - Foundry 默认测试账户1
        owners[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // 账户1
        // 账户2 - Foundry 默认测试账户2
        owners[1] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // 账户2
        // 账户3 - Foundry 默认测试账户3
        owners[2] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // 账户3
        
        // 部署多签钱包，设置需要2个确认
        // 构造函数参数：
        // - owners: 多签持有人列表
        // - 2: 需要2个确认才能执行交易
        MultiSigWallet multiSig = new MultiSigWallet(owners, 2);
        
        // 结束广播 - 完成交易签名和广播
        vm.stopBroadcast();
        
        // 输出合约地址和配置信息
        console.log("MultiSigWallet deployed at:", address(multiSig));
        console.log("Required confirmations:", multiSig.required());
        console.log("Owner 1:", multiSig.owners(0));
        console.log("Owner 2:", multiSig.owners(1));
        console.log("Owner 3:", multiSig.owners(2));
    }
}
