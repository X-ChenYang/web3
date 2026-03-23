# 多签钱包合约操作指南

## 1. 合约说明

本项目实现了一个简单的多签钱包合约 `MultiSigWallet.sol`，具有以下功能：

- **proposal()**: 多签持有人可提交交易提案
- **confirm()**: 其他多签人确认交易（通过交易方式确认）
- **execute()**: 当提案达到多签门槛时，任何人都可以执行交易

## 2. 部署步骤

### 2.1 编译合约

在 `web3-erc20-project` 目录下执行：

```bash
forge build
```

### 2.2 部署多签钱包

```bash
forge script script/DeployMultiSig.s.sol --broadcast --rpc-url http://localhost:8545
```

这将部署一个具有3个持有人（地址在脚本中定义）和2个确认门槛的多签钱包。

## 3. 测试步骤

### 3.1 设置环境变量

在执行交互脚本前，需要设置私钥环境变量：

```bash
# 账户1私钥（默认账户）
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# 账户2私钥
export PRIVATE_KEY2=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d

# 账户3私钥（可选）
export PRIVATE_KEY3=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
```

### 3.2 执行交互测试

1. **首先向多签钱包存入一些ETH**：

```bash
cast send --value 0.01ether [多签钱包地址]
```

2. **执行交互脚本**：

```bash
forge script script/MultiSigInteraction.s.sol --broadcast --rpc-url http://localhost:8545
```

### 3.3 验证结果

1. **查看交易状态**：

```bash
cast call [多签钱包地址] "getTransaction(uint256)(address,uint256,bytes,bool,uint256)" 0
```

2. **检查接收地址余额**：

```bash
cast balance [接收地址]
```

3. **检查多签钱包余额**：

```bash
cast balance [多签钱包地址]
```

## 4. 核心功能说明

### 4.1 提交提案

```solidity
function proposal(address to, uint256 value, bytes calldata data) external onlyOwner returns (uint256)
```
- **参数**：
  - `to`: 交易接收地址
  - `value`: 发送的ETH数量
  - `data`: 调用数据（如果是合约调用）
- **返回值**：交易ID

### 4.2 确认交易

```solidity
function confirm(uint256 txId) external onlyOwner txExists(txId) notExecuted(txId) notConfirmed(txId)
```
- **参数**：
  - `txId`: 交易ID

### 4.3 执行交易

```solidity
function execute(uint256 txId) external txExists(txId) notExecuted(txId)
```
- **参数**：
  - `txId`: 交易ID

## 5. 事件说明

- `Deposit(address indexed sender, uint256 amount)`: 当有ETH存入时触发
- `Proposal(uint256 indexed txId, address indexed proposer, address indexed to, uint256 value, bytes data)`: 当提交交易提案时触发
- `Confirmation(uint256 indexed txId, address indexed confirmer)`: 当确认交易时触发
- `Execution(uint256 indexed txId)`: 当执行交易时触发

## 6. 注意事项

1. **多签门槛设置**：部署时设置的确认门槛必须大于0且不超过持有人数量
2. **交易执行**：只有当确认数达到门槛时才能执行交易
3. **ETH管理**：多签钱包可以接收ETH，也可以通过交易发送ETH
4. **合约调用**：可以通过 `data` 参数调用其他合约

## 7. 测试网络

如果要在测试网络上部署，请修改脚本中的RPC URL：

```bash
# Sepolia测试网
forge script script/DeployMultiSig.s.sol --broadcast --rpc-url https://sepolia.infura.io/v3/YOUR_INFURA_KEY
```
