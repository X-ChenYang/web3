# ERC20 Token 转账记录查询系统

本项目是一个完整的 Web3 应用，包含 ERC20 Token 合约、后端索引服务和前端展示界面。

## 项目结构

```
web3-erc20-project/
├── contracts/          # Foundry 智能合约项目
│   ├── src/
│   │   └── MyToken.sol    # ERC20 Token 合约
│   ├── script/
│   │   └── DeployAndTransfer.s.sol  # 部署和转账脚本
│   ├── foundry.toml
│   └── .env
├── backend/            # Node.js 后端服务
│   ├── index.js        # Express API 服务
│   ├── indexer.js      # Viem 链上数据索引服务
│   ├── database.js     # SQLite 数据库
│   ├── abi/
│   │   └── MyToken.json
│   ├── package.json
│   └── .env
└── frontend/           # Vue 3 前端应用
    ├── src/
    │   ├── views/
    │   │   ├── Home.vue
    │   │   └── Transfers.vue
    │   ├── App.vue
    │   └── main.js
    ├── package.json
    └── vite.config.js
```

## 功能特性

1. **智能合约**
   - 基于 OpenZeppelin 的 ERC20 标准合约
   - 支持 mint/burn 功能
   - 包含所有权管理

2. **后端服务**
   - 使用 Viem 实时索引链上 Transfer 事件
   - SQLite 数据库存储转账记录
   - RESTful API 提供查询接口
   - 支持分页和筛选

3. **前端界面**
   - Vue 3 + Element Plus 构建
   - MetaMask 钱包连接
   - 转账记录列表展示
   - 统计信息可视化

## 快速开始

### 1. 部署智能合约

```bash
cd contracts

# 编译合约
forge build

# 部署合约并执行转账（本地 Anvil）
anvil
forge script script/DeployAndTransfer.s.sol --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# 或者部署到 Sepolia 测试网
forge script script/DeployAndTransfer.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

部署成功后，记录合约地址到 `token_address.txt`。

### 2. 启动后端服务

```bash
cd backend

# 安装依赖
npm install

# 配置环境变量
# 编辑 .env 文件，设置 TOKEN_ADDRESS 为部署的合约地址

# 运行索引服务（首次运行需要）
npm run index

# 启动 API 服务
npm run dev
```

后端服务将运行在 http://localhost:3005

### 3. 启动前端应用

```bash
cd frontend

# 安装依赖
npm install

# 启动开发服务器
npm run dev
```

前端应用将运行在 http://localhost:5173

## API 接口

### 健康检查
```
GET /api/health
```

### 获取地址转账记录
```
GET /api/transfers/:address?type=all|sent|received&page=1&limit=20
```

### 获取地址统计信息
```
GET /api/stats/:address
```

### 获取所有转账记录（调试）
```
GET /api/all-transfers?page=1&limit=50
```

## 环境变量

### 合约部署 (.env)
```
PRIVATE_KEY=your_private_key
SEPOLIA_RPC_URL=https://eth-sepolia.api.onfinality.io/public
ETHERSCAN_API_KEY=your_etherscan_api_key
```

### 后端服务 (backend/.env)
```
PORT=3001
RPC_URL=https://eth-sepolia.api.onfinality.io/public
TOKEN_ADDRESS=your_token_contract_address
START_BLOCK=0
```

## 技术栈

- **智能合约**: Solidity ^0.8.20, OpenZeppelin, Foundry
- **后端**: Node.js, Express, Viem, better-sqlite3
- **前端**: Vue 3, Element Plus, Ethers.js, Axios

## 注意事项

1. 请妥善保管私钥，不要在生产环境使用测试网的私钥
2. 部署到主网前请充分测试
3. 索引服务需要持续运行以保持数据同步
4. 首次索引可能需要较长时间，取决于区块数量
