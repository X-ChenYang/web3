// SPDX-License-Identifier: MIT
//  SPDX 许可证标识符：MIT
//  多签钱包交互脚本
pragma solidity ^0.8.0;
import "forge-std/console.sol";

// 导入 Script 基类，用于编写交互脚本
import {Script} from "forge-std/Script.sol";
// 导入多签钱包合约
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

/**
 * @title 多签钱包交互脚本
 * @dev 用于测试多签钱包的完整功能流程
 */
contract MultiSigInteraction is Script {
    /**
     * @dev 交互测试函数
     * 执行步骤：
     * 1. 连接到已部署的多签钱包
     * 2. 使用账户1提交交易提案
     * 3. 使用账户2确认交易
     * 4. 执行交易
     * 5. 检查交易状态
     */
    function run() external {
        // 多签钱包地址（部署后需要更新为实际部署地址）
        address payable multiSigAddress = payable(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
        // 创建多签钱包合约实例
        MultiSigWallet multiSig = MultiSigWallet(multiSigAddress);
        
        // 测试地址 - 交易接收方
        address payable recipient = payable(0x90F79bf6EB2c4f870365E785982E1f101E93b906);
        // 交易金额 - 0.1 ETH
        uint256 amount = 0.1 ether;
        
        // 步骤1：使用账户1提交交易提案
        console.log("\n=== Step 1: Propose Transaction ===");
        // 开始广播交易，使用环境变量中的 PRIVATE_KEY（账户1私钥）
        vm.startBroadcast(vm.envUint("PRIVATE_KEY")); // 使用默认私钥（账户1）
        // vm.startBroadcast(输入私钥地址测试);
        // 调用 proposal 函数提交交易提案
        // 参数：
        // - recipient: 接收地址
        // - amount: 发送金额
        // - "": 交易数据（空，因为是简单的ETH转账）
        uint256 txId = multiSig.proposal(recipient, amount, "");
        // 结束广播
        vm.stopBroadcast();
        // 输出交易ID
        console.log("Transaction proposed with ID:", txId);
        
        // 步骤2：使用账户2确认交易
        console.log("\n=== Step 2: Confirm Transaction ===");
        // 开始广播交易，使用环境变量中的 PRIVATE_KEY2（账户2私钥）
        vm.startBroadcast(vm.envUint("PRIVATE_KEY2")); // 使用第二个私钥（账户2）
        // vm.startBroadcast(输入私钥地址测试);
        // 调用 confirm 函数确认交易
        // 参数：
        // - txId: 交易ID
        multiSig.confirm(txId);
        // 结束广播
        vm.stopBroadcast();
        // 输出确认信息
        console.log("Transaction confirmed by account 2");
        
        // 步骤3：执行交易
        console.log("\n=== Step 3: Execute Transaction ===");
        // 开始广播交易，使用账户1私钥（任何人都可以执行）
        vm.startBroadcast(vm.envUint("PRIVATE_KEY")); // 任何人都可以执行
        // vm.startBroadcast(输入私钥地址测试);
        // 调用 execute 函数执行交易
        // 参数：
        // - txId: 交易ID
        multiSig.execute(txId);
        // 结束广播
        vm.stopBroadcast();
        // 输出执行信息
        console.log("Transaction executed");
        
        // 检查交易状态
        console.log("\n=== Transaction Status ===");
        // 调用 getTransaction 函数获取交易详情
        (address to, uint256 value, bytes memory data, bool executed, uint256 confirmations) = multiSig.getTransaction(txId);
        // 输出交易详情
        console.log("To:", to);
        console.log("Value:", value);
        console.log("Executed:", executed);
        console.log("Confirmations:", confirmations);
    }
}
