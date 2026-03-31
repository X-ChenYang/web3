# AirdropMerkleNFTMarket 项目代码说明文档

## 1. 项目概述

本项目实现了一个基于Merkle树白名单的NFT市场合约，支持使用Permit授权和Multicall批量调用功能，允许白名单用户以50%的优惠价格购买NFT。

## 2. 核心文件说明

### 2.1 SimpleToken.sol

**功能**：实现了支持EIP-2612 Permit功能的简化ERC20代币合约

**主要功能**：
- 标准ERC20代币功能（transfer, approve, transferFrom）
- EIP-2612 Permit授权功能
- 代币铸造功能

**关键函数**：
- `permit()`: 实现EIP-2612标准的授权功能，允许用户通过签名授权代币转账
- `transfer()`: 标准转账功能
- `approve()`: 标准授权功能
- `transferFrom()`: 标准授权转账功能
- `mint()`: 代币铸造功能

### 2.2 SimpleNFT.sol

**功能**：实现了简化的ERC721 NFT合约

**主要功能**：
- NFT铸造
- NFT转移
- 批量铸造功能

**关键函数**：
- `mintNFT()`: 铸造单个NFT
- `batchMintNFT()`: 批量铸造多个NFT
- `transferFrom()`: 转移NFT所有权
- `safeTransferFrom()`: 安全转移NFT所有权

### 2.3 AirdropMerkleNFTMarket.sol

**功能**：实现了基于Merkle树白名单的NFT市场合约

**主要功能**：
- Merkle树白名单验证
- NFT上架
- NFT购买（支持白名单优惠）
- Permit预授权
- 批量操作支持

**关键函数**：
- `listNFT()`: 上架NFT
- `claimNFT()`: 领取NFT（支持白名单验证）
- `permitPrePay()`: 预授权代币
- `batchClaimNFT()`: 批量领取NFT
- `verifyWhitelist()`: 验证白名单状态
- `calculatePrice()`: 计算价格（支持白名单折扣）

### 2.4 MulticallHelper.sol

**功能**：提供批量调用合约方法的功能

**主要功能**：
- 批量调用多个合约方法
- 支持不同返回类型的批量调用

**关键函数**：
- `multicall()`: 批量调用多个合约方法
- `multicallWithUint256Return()`: 批量调用并返回uint256结果
- `multicallWithBoolReturn()`: 批量调用并返回bool结果

### 2.5 AirdropMerkleNFTMarketTest.t.sol

**功能**：AirdropMerkleNFTMarket合约的完整测试用例

**测试内容**：
- Merkle树验证
- 白名单用户购买NFT
- 非白名单用户购买NFT
- 批量购买NFT
- Permit签名验证
- 价格计算
- NFT上架
- 提取功能

### 2.6 MerkleTreeTest.t.sol

**功能**：测试Merkle树的基本功能

**测试内容**：
- Merkle树根节点计算
- 用户proof验证
- 无效proof验证

### 2.7 build-merkle-tree.js

**功能**：构建Merkle树并生成证明

**主要功能**：
- 从输入地址生成Merkle树
- 为每个地址生成证明
- 输出Merkle树根和证明

## 3. 技术实现要点

### 3.1 Merkle树白名单验证

使用Merkle树来高效验证用户是否在白名单中，相比传统的存储白名单地址列表，Merkle树验证可以：
- 节省合约存储空间
- 提高验证效率
- 支持动态更新白名单

### 3.2 Permit授权

实现EIP-2612标准的Permit功能，允许用户通过签名授权代币转账，无需预先调用approve()，提高用户体验。

### 3.3 Multicall批量调用

使用Multicall技术批量调用多个合约方法，减少交易次数和gas成本，提高操作效率。

### 3.4 安全考虑

- 实现了签名重用防护
- 验证白名单状态
- 检查NFT上架状态
- 确保价格计算正确
- 实现了已领取状态跟踪

## 4. 操作命令文档

### 4.1 环境准备

1. **启动本地Anvil节点**
   ```bash
   wsl bash -c "~/.foundry/bin/anvil"
   ```

2. **安装依赖**
   ```bash
   wsl bash -c "cd /mnt/d/Trae_code/My_foundry/web3-erc20-project/contracts && npm install"
   ```

### 4.2 编译合约

```bash
wsl bash -c "cd /mnt/d/Trae_code/My_foundry/web3-erc20-project/contracts && ~/.foundry/bin/forge build"
```

### 4.3 运行测试

```bash
wsl bash -c "cd /mnt/d/Trae_code/My_foundry/web3-erc20-project/contracts && ~/.foundry/bin/forge test"
```

### 4.4 构建Merkle树

```bash
wsl bash -c "cd /mnt/d/Trae_code/My_foundry/web3-erc20-project/contracts && node scripts/build-merkle-tree.js"
```

### 4.5 部署合约

1. **部署Token合约**
   ```bash
   wsl bash -c "cd /mnt/d/Trae_code/My_foundry/web3-erc20-project/contracts && ~/.foundry/bin/forge create --private-key <private-key> src/SimpleToken.sol:SimpleToken --constructor-args \"Airdrop Token\" \"ADT\" 1000000000000000000000000"
   ```

2. **部署NFT合约**
   ```bash
   wsl bash -c "cd /mnt/d/Trae_code/My_foundry/web3-erc20-project/contracts && ~/.foundry/bin/forge create --private-key <private-key> src/SimpleNFT.sol:SimpleNFT --constructor-args \"Airdrop NFT\" \"ADN\""
   ```

3. **部署市场合约**
   ```bash
   wsl bash -c "cd /mnt/d/Trae_code/My_foundry/web3-erc20-project/contracts && ~/.foundry/bin/forge create --private-key <private-key> src/AirdropMerkleNFTMarket.sol:AirdropMerkleNFTMarket --constructor-args <token-address> <nft-address> 100000000000000000000 <merkle-root>"
   ```

### 4.6 交互操作

1. **铸造NFT**
   ```bash
   wsl bash -c "cd /mnt/d/Trae_code/My_foundry/web3-erc20-project/contracts && ~/.foundry/bin/cast send <nft-address> 'batchMintNFT(address,string[])((uint256[]))' <market-address> '[]' --private-key <private-key>"
   ```

2. **上架NFT**
   ```bash
   wsl bash -c "cd /mnt/d/Trae_code/My_foundry/web3-erc20-project/contracts && ~/.foundry/bin/cast send <market-address> 'listNFT(uint256,uint256)' 0 100000000000000000000 --private-key <private-key>"
   ```

3. **使用Multicall购买NFT（白名单用户）**
   - 首先生成Permit签名
   - 然后执行Multicall调用

## 5. 项目结构

```
contracts/
├── src/
│   ├── SimpleToken.sol          # 支持Permit的ERC20代币合约
│   ├── SimpleNFT.sol            # NFT合约
│   ├── AirdropMerkleNFTMarket.sol  # 主市场合约
│   └── MulticallHelper.sol      # Multicall辅助合约
├── test/
│   ├── AirdropMerkleNFTMarketTest.t.sol  # 主测试文件
│   └── MerkleTreeTest.t.sol     # Merkle树测试
└── scripts/
    └── build-merkle-tree.js     # Merkle树构建脚本
```

## 6. 总结

本项目成功实现了一个功能完整的AirdropMerkleNFTMarket合约，结合了Merkle树白名单验证、Permit授权和Multicall批量调用等先进技术，为用户提供了一种高效、安全的NFT购买体验。

主要实现了以下功能：
- 基于Merkle树的白名单验证系统
- 支持EIP-2612 Permit授权的代币支付
- 使用Multicall批量执行操作
- 白名单用户享受50%的购买折扣
- 完整的测试用例覆盖

该实现充分考虑了安全性和用户体验，为NFT市场的运营提供了一个灵活、高效的解决方案。