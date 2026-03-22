# Viem CLI 钱包

一个基于 Viem.js 构建的命令行钱包，用于生成私钥、查询余额、构建 ERC20 转账交易、签名和发送到 Sepolia 网络。

## 功能特性

- ✅ 生成随机私钥和地址
- ✅ 查询 ETH 余额
- ✅ 查询 ERC20 代币余额
- ✅ 构建 EIP 1559 标准的 ERC20 转账交易
- ✅ 签名交易
- ✅ 发送交易到 Sepolia 测试网络

## 快速开始

### 1. 安装依赖

```bash
# 进入 contracts 目录
cd contracts

# 安装 Viem 依赖
npm install
```

### 2. 运行钱包

```bash
npm run wallet
```

## 使用指南

### 1. 生成私钥

运行脚本后，系统会自动生成一个随机私钥和对应的地址。请务必保存好私钥，这是访问钱包的唯一凭证。

### 2. 查询余额

系统会查询当前地址的 ETH 余额。如果余额不足，建议先向该地址转入一些 Sepolia ETH 用于支付 gas 费用。

可以从 Sepolia 水龙头获取测试 ETH：
- https://sepoliafaucet.com/
- https://faucet.sepolia.dev/

### 3. 构建 ERC20 转账交易

系统会查询默认 ERC20 代币（Sepolia USDC）的余额。如果代币余额为 0，需要先向该地址转入一些代币。

### 4. 发送交易

系统会构建一个 EIP 1559 标准的交易，转账 1 个代币到指定地址。确认后，交易将被发送到 Sepolia 网络。

## 配置说明

### 网络配置

默认使用 Sepolia 测试网络，通过 Infura 提供的端点连接：
- `https://sepolia.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161`

### 代币配置

默认使用 Sepolia 网络上的 USDC 代币：
- 代币地址: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`

## 注意事项

1. **安全警告**：私钥是访问钱包的唯一凭证，请妥善保管，不要分享给他人。
2. **测试网络**：本工具使用 Sepolia 测试网络，不会涉及真实资金。
3. **Gas 费用**：确保钱包中有足够的 ETH 用于支付交易 gas 费用。
4. **代币余额**：确保钱包中有足够的代币用于转账。

## 自定义修改

### 修改目标地址

在 `viem-cli-wallet.js` 文件中，找到以下代码并修改为目标地址：

```javascript
// 目标地址
const toAddress = '0x0000000000000000000000000000000000000000'; // 请替换为实际目标地址
```

### 修改代币地址

在 `viem-cli-wallet.js` 文件中，找到以下代码并修改为其他代币地址：

```javascript
// 这里使用一个常见的 Sepolia 测试网 ERC20 代币 USDC
const tokenAddress = '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238'; // Sepolia USDC 地址
```

### 修改转账金额

在 `viem-cli-wallet.js` 文件中，找到以下代码并修改转账金额：

```javascript
// 转账金额（这里使用 1 个代币）
const amount = parseEther('1'); // 假设代币是 18 位小数
```

## 故障排除

### 连接错误

如果遇到网络连接错误，请检查：
- 网络连接是否正常
- Infura 端点是否可用
- Sepolia 网络是否正常运行

### 余额不足

如果遇到余额不足的错误：
- 确保钱包中有足够的 ETH 用于支付 gas 费用
- 确保钱包中有足够的代币用于转账

### 交易失败

如果交易失败，请检查：
- 目标地址是否正确
- 代币余额是否充足
- Gas 费用是否设置合理

## 技术栈

- **Viem.js**：用于与以太坊网络交互
- **Node.js**：运行环境

## 许可证

MIT
