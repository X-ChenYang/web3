// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MyToken.sol";
import "../src/Bank.sol";

contract SafeWalletInteraction is Script {
    function run() external {
        // 从环境变量中读取部署者的私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署 MyToken 合约
        console.log(unicode"部署 MyToken 合约...");
        MyToken token = new MyToken("MyToken", "MTK", 18, 1000000);
        console.log(unicode"MyToken 合约地址:", address(token));
        
        // 部署 Bank 合约
        console.log(unicode"\n部署 Bank 合约...");
        Bank bank = new Bank(deployer);
        console.log(unicode"Bank 合约地址:", address(bank));
        
        // 停止广播交易
        vm.stopBroadcast();
        
        // 输出操作说明
        console.log(unicode"\n==========================================");
        console.log(unicode"Safe Wallet 多签钱包操作指南");
        console.log(unicode"==========================================");
        
        console.log(unicode"\n1. 在 Safe Wallet 支持的测试网上创建 2/3 多签钱包:");
        console.log(unicode"   - 访问 https://app.safe.global/");
        console.log(unicode"   - 点击 'Create new Safe'");
        console.log(unicode"   - 选择网络：Sepolia（或其他支持的测试网）");
        console.log(unicode"   - 连接钱包（如 MetaMask）");
        console.log(unicode"   - 设置钱包名称");
        console.log(unicode"   - 添加所有者：至少添加 3 个地址");
        console.log(unicode"   - 设置阈值：2（2/3 多签）");
        console.log(unicode"   - 确认创建并支付 gas 费用");
        
        console.log(unicode"\n2. 往多签中存入 ERC20 Token:");
        console.log(unicode"   - 复制 Safe 钱包地址");
        console.log(unicode"   - 方法 1：使用 MetaMask 直接转账");
        console.log(unicode"     * 打开 MetaMask，选择 MyToken");
        console.log(unicode"     * 点击 'Send'");
        console.log(unicode"     * 粘贴 Safe 钱包地址");
        console.log(unicode"     * 输入金额，点击 'Next' -> 'Confirm'");
        console.log(unicode"   - 方法 2：使用 Forge 脚本转账");
        console.log(unicode"     * 运行命令：");
        console.log(unicode"       forge script script/SafeWalletInteraction.s.sol:SafeWalletInteraction --rpc-url https://eth-sepolia-rpc.publicnode.com --private-key $PRIVATE_KEY --sig 'transferToken(address,address,uint256)'", address(token), "<SAFE_WALLET_ADDRESS> <AMOUNT>");
        
        console.log(unicode"\n3. 从多签中转出 ERC20 Token:");
        console.log(unicode"   - 登录 Safe 钱包界面");
        console.log(unicode"   - 点击 'New transaction' -> 'Send tokens'");
        console.log(unicode"   - 在 'Token' 下拉菜单中选择 'MyToken'");
        console.log(unicode"   - 输入接收地址和金额");
        console.log(unicode"   - 点击 'Review'");
        console.log(unicode"   - 点击 'Submit'");
        console.log(unicode"   - 等待其他所有者签名并执行交易");
        
        console.log(unicode"\n4. 把 Bank 合约的管理员设置为多签:");
        console.log(unicode"   - 登录 Safe 钱包界面");
        console.log(unicode"   - 点击 'New transaction' -> 'Contract interaction'");
        console.log(unicode"   - 输入 Bank 合约地址:", address(bank));
        console.log(unicode"   - 点击 'Select an ABI' -> 'Upload ABI'");
        console.log(unicode"   - 复制粘贴 Bank 合约的 ABI（从 out/Bank.sol/Bank.json 文件中获取）");
        console.log(unicode"   - 选择 'setAdmin' 函数");
        console.log(unicode"   - 输入 Safe 钱包地址作为 newAdmin 参数");
        console.log(unicode"   - 点击 'Review'");
        console.log(unicode"   - 点击 'Submit'");
        console.log(unicode"   - 等待其他所有者签名并执行交易");
        
        console.log(unicode"\n5. 从多签中发起对 Bank 的 withdraw 调用:");
        console.log(unicode"   - 首先确保 Bank 合约中有足够的 ETH");
        console.log(unicode"   - 登录 Safe 钱包界面");
        console.log(unicode"   - 点击 'New transaction' -> 'Contract interaction'");
        console.log(unicode"   - 输入 Bank 合约地址:", address(bank));
        console.log(unicode"   - 选择 'withdraw' 函数");
        console.log(unicode"   - 输入接收地址和金额");
        console.log(unicode"   - 点击 'Review'");
        console.log(unicode"   - 点击 'Submit'");
        console.log(unicode"   - 等待其他所有者签名并执行交易");
        
        console.log(unicode"\n6. 提供 Safe 钱包链接:");
        console.log(unicode"   - 在 Safe 钱包界面，复制浏览器地址栏中的 URL");
        console.log(unicode"   - 该 URL 类似于：https://app.safe.global/sepolia:<SAFE_WALLET_ADDRESS>");
        console.log(unicode"   - 请提供此链接作为完成任务的证明");
        
        console.log(unicode"\n==========================================");
        console.log(unicode"操作完成后，请提供以下信息：");
        console.log(unicode"1. Safe 钱包链接");
        console.log(unicode"2. 操作过程中的截图（可选）");
        console.log(unicode"==========================================");
    }
    
    // 辅助函数：转账代币
    function transferToken(address tokenAddress, address to, uint256 amount) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        MyToken(tokenAddress).transfer(to, amount);
        vm.stopBroadcast();
        console.log("Transferred", amount, "tokens to", to);
    }
}