#!/usr/bin/env node

// Viem CLI 钱包脚本
// 功能：生成私钥、查询余额、构建 ERC20 转账交易、签名和发送到 Sepolia 网络

// 导入 Viem 库的核心函数和类
// createWalletClient: 创建钱包客户端，用于签名和发送交易
// createPublicClient: 创建公共客户端，用于查询区块链数据
// http: HTTP 传输协议，用于连接到以太坊节点
// parseEther: 将字符串格式的 ETH 数量转换为 wei（最小单位）
// formatEther: 将 wei 格式化为可读的 ETH 数量
// Wallet: 钱包类，用于生成和管理私钥
const { createWalletClient, createPublicClient, http, parseEther, formatEther, parseUnits, encodeFunctionData } = require('viem');
const { Wallet } = require('viem/accounts');
const { generatePrivateKey, privateKeyToAccount } = require('viem/accounts');
// 导入 Sepolia 测试网络配置
const { sepolia } = require('viem/chains');

// ERC20 代币标准接口 ABI（Application Binary Interface）
// ABI 是智能合约与外部世界交互的接口定义，包含函数名称、参数、返回值等信息
const ERC20_ABI = [
  {
    "constant": true,  // 函数不修改合约状态
    "inputs": [{ "name": "_owner", "type": "address" }],  // 输入参数：所有者地址
    "name": "balanceOf",  // 函数名称：查询余额
    "outputs": [{ "name": "balance", "type": "uint256" }],  // 返回值：余额（无符号256位整数）
    "payable": false,  // 函数不接受以太币
    "stateMutability": "view",  // 状态可变性：只读，不消耗 gas
    "type": "function"  // 类型：函数
  },
  {
    "constant": false,  // 函数会修改合约状态
    "inputs": [
      { "name": "_to", "type": "address" },  // 接收方地址
      { "name": "_value", "type": "uint256" }  // 转账金额
    ],
    "name": "transfer",  // 函数名称：转账
    "outputs": [{ "name": "success", "type": "bool" }],  // 返回值：转账是否成功
    "payable": false,  // 函数不接受以太币
    "stateMutability": "nonpayable",  // 状态可变性：非支付函数
    "type": "function"  // 类型：函数
  },
  {
    "constant": true,  // 函数不修改合约状态
    "inputs": [],  // 无输入参数
    "name": "decimals",  // 函数名称：查询代币小数位数
    "outputs": [{ "name": "", "type": "uint8" }],  // 返回值：小数位数（8位无符号整数）
    "payable": false,  // 函数不接受以太币
    "stateMutability": "view",  // 状态可变性：只读，不消耗 gas
    "type": "function"  // 类型：函数
  },
  {
    "constant": true,  // 函数不修改合约状态
    "inputs": [],  // 无输入参数
    "name": "symbol",  // 函数名称：查询代币符号
    "outputs": [{ "name": "", "type": "string" }],  // 返回值：代币符号（字符串）
    "payable": false,  // 函数不接受以太币
    "stateMutability": "view",  // 状态可变性：只读，不消耗 gas
    "type": "function"  // 类型：函数
  }
];

// 主函数：钱包的主要逻辑流程
async function main() {
  // 打印欢迎信息
  console.log('====================================');
  console.log('Viem CLI 钱包');
  console.log('====================================\n');

  // 1. 生成私钥
  console.log('1. 生成私钥');
  // 使用 Wallet.random() 生成一个随机钱包
  // 这会创建一个新的私钥和对应的以太坊地址
  // const wallet = Wallet.random();
  // 使用 generatePrivateKey 生成随机私钥
  // const privateKey = require('viem/accounts').generatePrivateKey();
  // 从私钥创建钱包以获取地址
  // const wallet = require('viem/accounts').privateKeyToAccount(privateKey);
  // const address = wallet.address;
  // 获取私钥：用于签名交易，必须妥善保管
  // const privateKey = wallet.privateKey;
  const privateKey = "0x501fef04a34ce6f51f9d25e72b56523a6f5f808c406caf377e65d3551f44de1b";
  // // 获取地址：用于接收资金和查询余额
  // const address = wallet.address;
  const address = "0x5Ad41772bd5E89297C596d1b4f457B510030dDdE";
  const account = privateKeyToAccount(privateKey);

  // 显示生成的私钥和地址
  // console.log(`私钥: ${privateKey}`);
  console.log(`地址: ${address}`);
  console.log('\n请保存好私钥，这是访问钱包的唯一凭证！\n');

  // 2. 查询余额
  console.log('2. 查询余额');
  // 创建公共客户端：用于查询区块链数据
  // chain: 指定使用 Sepolia 测试网络
  // transport: 指定使用 HTTP 协议连接到 Infura 提供的 Sepolia 节点
  const publicClient = createPublicClient({
    chain: sepolia,
    transport: http('https://ethereum-sepolia-rpc.publicnode.com') // 使用 Infura 的 Sepolia 端点
  });

  try {
    // 查询 ETH 余额
    // getBalance: 查询指定地址的 ETH 余额
    // 返回值以 wei 为单位（1 ETH = 10^18 wei）
    const ethBalance = await publicClient.getBalance({ address });
    // 使用 formatEther 将 wei 转换为可读的 ETH 数量
    console.log(`ETH 余额: ${formatEther(ethBalance)} ETH`);

    // 提示用户如果余额不足需要先充值
    // parseEther('0.01') 将 0.01 ETH 转换为 wei
    if (ethBalance < parseEther('0.01')) {
      console.log('\n⚠️  余额不足，建议先向该地址转入一些 Sepolia ETH 用于支付 gas 费用');
      console.log('可以从 Sepolia 水龙头获取测试 ETH: https://sepoliafaucet.com/');
      // 等待用户按 Enter 键继续
      console.log('\n按 Enter 键继续...');
      await new Promise(resolve => process.stdin.once('data', resolve));
    }
  } catch (error) {
    // 捕获并显示查询余额时的错误
    console.error('查询余额失败:', error.message);
  }

  // 3. 构建 ERC20 转账交易
  console.log('\n3. 构建 ERC20 转账交易');

  // 这里使用一个常见的 Sepolia 测试网 ERC20 代币 USDC
  // USDC 是一种稳定币，价值与美元挂钩
  const tokenAddress = '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238'; // Sepolia USDC 地址

  // 创建钱包客户端：用于签名和发送交易
  // chain: 指定使用 Sepolia 测试网络
  // transport: 指定使用 HTTP 协议连接到 Infura 节点
  // account: 指定使用之前生成的地址作为账户
  const walletClient = createWalletClient({
    chain: sepolia,
    transport: http('https://ethereum-sepolia-rpc.publicnode.com'),
    account: account // 使用完整的账户对象，包含私钥
  });

  // 查询代币信息
  try {
    // 查询代币符号（如 "USDC"）
    // readContract: 读取智能合约的函数
    // address: 代币合约地址
    // abi: 合约的 ABI 定义
    // functionName: 要调用的函数名称
    const tokenSymbol = await publicClient.readContract({
      address: tokenAddress,
      abi: ERC20_ABI,
      functionName: 'symbol'
    });

    // 查询代币的小数位数（如 6 或 18）
    // 小数位数决定了代币的最小单位，如 USDC 有 6 位小数
    const tokenDecimals = await publicClient.readContract({
      address: tokenAddress,
      abi: ERC20_ABI,
      functionName: 'decimals'
    });

    // 显示代币信息
    console.log(`代币信息: ${tokenSymbol} (${tokenDecimals} 位小数)`);

    // 查询代币余额
    // args: 函数的参数数组，这里传入钱包地址
    const tokenBalance = await publicClient.readContract({
      address: tokenAddress,
      abi: ERC20_ABI,
      functionName: 'balanceOf',
      args: [address]
    });

    // 显示代币余额
    // Number(tokenBalance) 将 BigInt 转换为普通数字
    // 10 ** tokenDecimals 计算代币的最小单位（如 10^6）
    console.log(`代币余额: ${Number(tokenBalance) / (10 ** tokenDecimals)} ${tokenSymbol}`);

    // 提示用户如果代币余额不足
    if (Number(tokenBalance) === 0) {
      console.log('\n⚠️  代币余额为 0，需要先向该地址转入一些代币');
      // 等待用户按 Enter 键继续
      console.log('\n按 Enter 键继续...');
      await new Promise(resolve => process.stdin.once('data', resolve));
    }
  } catch (error) {
    // 捕获并显示查询代币信息时的错误
    console.error('查询代币信息失败:', error.message);
  }

  // 4. 构建和签名交易
  console.log('\n4. 构建和签名 ERC20 转账交易');

  // 目标地址：接收代币的地址
  // 注意：这是一个示例地址，实际使用时需要替换为真实地址
  const toAddress = '0x1F47220213E9e643c6562800AF0169D9C82f0fEA'; // 请替换为实际目标地址

  // 转账金额（这里使用 1 个代币）
  // parseEther('1') 将 1 ETH 转换为 wei，这里假设代币也是 18 位小数
  // 如果代币是 6 位小数（如 USDC），需要使用 parseUnits('1', 6)
  const amount = parseUnits('1', 6); // 假设代币是 18 位小数

  // 构建 EIP 1559 交易
  // EIP 1559 是以太坊的新交易格式，改进了 gas 费用机制
  const nonce = await publicClient.getTransactionCount({ address });  // nonce：交易序号，防止重放攻击
  const gasPrice = await publicClient.getGasPrice();  // gasPrice：当前 gas 价格

  // 构建交易数据
  // encodeFunctionData: 将函数调用编码为交易数据
  // abi: 函数的 ABI 定义
  // functionName: 要调用的函数名称
  // args: 函数的参数数组（接收方地址和转账金额）
  const data = encodeFunctionData({
    abi: ERC20_ABI,
    functionName: 'transfer',
    args: [toAddress, amount]
  });

  // 5. 发送交易
  console.log('\n5. 发送交易到 Sepolia 网络');
  console.log('交易详情:');
  console.log(`- 发送方: ${address}`);
  console.log(`- 接收方: ${toAddress}`);
  console.log(`- 代币地址: ${tokenAddress}`);
  console.log(`- 转账金额: 1 代币`);

  // 等待用户确认
  console.log('\n按 Enter 键确认发送交易...');
  await new Promise(resolve => process.stdin.once('data', resolve));

  try {
    // 1. 先估计 gas
    const gas = await publicClient.estimateGas({
      to: tokenAddress,
      data,
      account: address
    });
    console.log('发送交易gas费...', gas);
    const gasLimit = 100000n; 
    // 2. 构建交易参数
    const transaction = {
      to: tokenAddress,
      data,
      nonce,
      gas: gasLimit, // 增加 20% 的 gas 缓冲
      maxPriorityFeePerGas: gasPrice,
      maxFeePerGas: gasPrice * 3n // 增加 maxFee 以确保交易被处理
    };

    // 3. 发送交易
    console.log('发送交易...');
    console.log('交易参数:', transaction);

    const hash = await walletClient.sendTransaction(transaction);

    // 4. 检查返回值
    if (!hash) {
      console.log('交易发送失败：未返回交易哈希');
      return;
    }

    console.log('\n交易已发送!');
    console.log(`交易哈希: ${hash}`);
    console.log(`查看交易: https://sepolia.etherscan.io/tx/${hash}`);

    // 5. 等待交易确认
    console.log('\n等待交易确认...');
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    console.log(`交易确认! 区块号: ${receipt.blockNumber}`);

  } catch (error) {
    console.error('发送交易失败:', error.message);
    // 提供更详细的错误信息
    if (error.code) {
      console.log('错误代码:', error.code);
    }
    if (error.details) {
      console.log('错误详情:', error.details);
    }
  }

  // 显示操作完成信息
  console.log('\n====================================');
  console.log('操作完成');
  console.log('====================================');
}

// 运行主函数
// .catch(console.error): 捕获并显示任何未处理的错误
main().catch(console.error);
