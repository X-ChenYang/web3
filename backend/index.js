// ERC20 代币后端服务
// 使用 ethers.js 索引链上 ERC20 转账数据

const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const sqlite3 = require('sqlite3');
const { open } = require('sqlite');
const { ethers } = require('ethers');

// 加载环境变量
dotenv.config();

// 配置
const PORT = process.env.PORT || 3001;
const RPC_URL = process.env.RPC_URL || 'http://localhost:8545';
const TOKEN_ADDRESS = process.env.TOKEN_ADDRESS || '';
const START_BLOCK = parseInt(process.env.START_BLOCK || '0');

// ERC20 合约 ABI
const ERC20_ABI = [
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "address", "name": "from", "type": "address" },
      { "indexed": true, "internalType": "address", "name": "to", "type": "address" },
      { "indexed": false, "internalType": "uint256", "name": "value", "type": "uint256" }
    ],
    "name": "Transfer",
    "type": "event"
  },
  {
    "inputs": [],
    "name": "name",
    "outputs": [{ "internalType": "string", "name": "", "type": "string" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "symbol",
    "outputs": [{ "internalType": "string", "name": "", "type": "string" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "decimals",
    "outputs": [{ "internalType": "uint8", "name": "", "type": "uint8" }],
    "stateMutability": "view",
    "type": "function"
  }
];

// 数据库服务类
class DatabaseService {
  constructor(dbPath = './transfers.db') {
    this.dbPath = dbPath;
    this.db = null;
  }

  async initialize() {
    try {
      this.db = await open({
        filename: this.dbPath,
        driver: sqlite3.Database
      });

      await this.createTables();
      console.log('✓ 数据库连接成功');
    } catch (error) {
      console.error('✗ 数据库连接失败:', error);
      throw error;
    }
  }

  async createTables() {
    if (!this.db) return;

    await this.db.exec(`
      CREATE TABLE IF NOT EXISTS transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_hash TEXT UNIQUE NOT NULL,
        block_number INTEGER NOT NULL,
        from_address TEXT NOT NULL,
        to_address TEXT NOT NULL,
        amount TEXT NOT NULL,
        token_address TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );

      CREATE INDEX IF NOT EXISTS idx_from_address ON transfers(from_address);
      CREATE INDEX IF NOT EXISTS idx_to_address ON transfers(to_address);
      CREATE INDEX IF NOT EXISTS idx_block_number ON transfers(block_number);
      CREATE INDEX IF NOT EXISTS idx_token_address ON transfers(token_address);
    `);
  }

  async saveTransfer(event, tokenAddress, timestamp) {
    if (!this.db) {
      throw new Error('数据库未初始化');
    }

    try {
      await this.db.run(
        `INSERT OR IGNORE INTO transfers 
         (transaction_hash, block_number, from_address, to_address, amount, token_address, timestamp)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          event.transactionHash,
          event.blockNumber,
          event.from.toLowerCase(),
          event.to.toLowerCase(),
          event.value.toString(),
          tokenAddress.toLowerCase(),
          timestamp
        ]
      );
    } catch (error) {
      console.error('保存转账记录失败:', error);
      throw error;
    }
  }

  async getTransfersByAddress(address, limit = 20) {
    if (!this.db) {
      throw new Error('数据库未初始化');
    }

    const lowerAddress = address.toLowerCase();
    
    return await this.db.all(
      `SELECT * FROM transfers 
       WHERE LOWER(from_address) = ? OR LOWER(to_address) = ? 
       ORDER BY block_number DESC 
       LIMIT ?`,
      [lowerAddress, lowerAddress, limit]
    );
  }

  async getTransferStats(address) {
    if (!this.db) {
      throw new Error('数据库未初始化');
    }

    const lowerAddress = address.toLowerCase();

    const sentResult = await this.db.get(
      `SELECT COUNT(*) as count, COALESCE(SUM(CAST(amount AS REAL)), 0) as total 
       FROM transfers 
       WHERE LOWER(from_address) = ?`,
      [lowerAddress]
    );

    const receivedResult = await this.db.get(
      `SELECT COUNT(*) as count, COALESCE(SUM(CAST(amount AS REAL)), 0) as total 
       FROM transfers 
       WHERE LOWER(to_address) = ?`,
      [lowerAddress]
    );

    return {
      sent: {
        count: sentResult?.count || 0,
        total: sentResult?.total || '0'
      },
      received: {
        count: receivedResult?.count || 0,
        total: receivedResult?.total || '0'
      }
    };
  }

  async getLatestBlockNumber() {
    if (!this.db) {
      throw new Error('数据库未初始化');
    }

    const result = await this.db.get(
      'SELECT MAX(block_number) as maxBlock FROM transfers'
    );

    return result?.maxBlock || START_BLOCK;
  }

  async close() {
    if (this.db) {
      await this.db.close();
      this.db = null;
      console.log('数据库连接已关闭');
    }
  }
}

// 区块链索引服务类
class BlockchainIndexer {
  constructor(rpcUrl, tokenAddress, db) {
    this.provider = new ethers.JsonRpcProvider(rpcUrl);
    this.tokenAddress = tokenAddress;
    this.db = db;
    this.isRunning = false;
    this.lastProcessedBlock = START_BLOCK;
    this.pollInterval = null;
  }

  async start() {
    if (this.isRunning) {
      console.log('索引服务已在运行');
      return;
    }

    this.isRunning = true;
    console.log('========================================');
    console.log('启动区块链索引服务 (ethers.js)');
    console.log('========================================');
    console.log(`代币合约: ${this.tokenAddress}`);

    try {
      // 获取代币信息
      const tokenContract = new ethers.Contract(this.tokenAddress, ERC20_ABI, this.provider);
      const [name, symbol, decimals] = await Promise.all([
        tokenContract.name(),
        tokenContract.symbol(),
        tokenContract.decimals()
      ]);
      console.log(`代币名称: ${name} (${symbol})`);
      console.log(`小数位: ${decimals}`);
    } catch (error) {
      console.warn('获取代币信息失败 (区块链节点可能未启动):', error);
    }

    // 获取最新区块号
    try {
      this.lastProcessedBlock = await this.db.getLatestBlockNumber();
      console.log(`上次处理区块: ${this.lastProcessedBlock}`);
    } catch (error) {
      console.error('获取最新区块号失败:', error);
      this.lastProcessedBlock = START_BLOCK;
    }

    // 扫描历史区块
    await this.scanHistoricalBlocks();

    // 开始监听新事件
    this.listenToEvents();

    console.log('========================================');
    console.log('索引服务已启动');
    console.log('========================================');
  }

  stop() {
    this.isRunning = false;
    if (this.pollInterval) {
      clearInterval(this.pollInterval);
      this.pollInterval = null;
    }
    console.log('索引服务已停止');
  }

  async scanHistoricalBlocks() {
    try {
      const currentBlock = await this.provider.getBlockNumber();
      const fromBlock = Math.max(this.lastProcessedBlock + 1, START_BLOCK);

      if (fromBlock >= currentBlock) {
        console.log('没有历史区块需要扫描');
        return;
      }

      console.log(`扫描历史区块: ${fromBlock} - ${currentBlock}`);

      const tokenContract = new ethers.Contract(this.tokenAddress, ERC20_ABI, this.provider);
      const logs = await tokenContract.queryFilter('Transfer', fromBlock, currentBlock);

      console.log(`找到 ${logs.length} 个历史转账事件`);

      for (const log of logs) {
        await this.processLog(log);
      }

      console.log(`✓ 历史区块扫描完成`);
    } catch (error) {
      console.warn('扫描历史区块失败 (区块链节点可能未启动):', error);
    }
  }

  listenToEvents() {
    console.log('开始监听新的转账事件...');
    
    // 使用轮询方式监听事件
    this.pollInterval = setInterval(async () => {
      if (!this.isRunning) {
        if (this.pollInterval) {
          clearInterval(this.pollInterval);
          this.pollInterval = null;
        }
        return;
      }

      try {
        const currentBlock = await this.provider.getBlockNumber();
        const fromBlock = this.lastProcessedBlock + 1;

        if (fromBlock <= currentBlock) {
          const tokenContract = new ethers.Contract(this.tokenAddress, ERC20_ABI, this.provider);
          const logs = await tokenContract.queryFilter('Transfer', fromBlock, currentBlock);

          for (const log of logs) {
            await this.processLog(log);
          }
        }
      } catch (error) {
        // 静默处理连接错误，等待下一次轮询
        // console.error('监听事件失败:', error);
      }
    }, 5000); // 每5秒轮询一次
  }

  async processLog(log) {
    try {
      const block = await this.provider.getBlock(log.blockNumber);
      
      const transferEvent = {
        transactionHash: log.transactionHash,
        blockNumber: log.blockNumber,
        from: log.args.from,
        to: log.args.to,
        value: log.args.value
      };

      await this.db.saveTransfer(transferEvent, this.tokenAddress, block.timestamp);

      console.log(`[区块 ${log.blockNumber}] 转账: ${transferEvent.from.slice(0, 10)}... -> ${transferEvent.to.slice(0, 10)}... 金额: ${ethers.formatEther(transferEvent.value)}`);

      if (log.blockNumber > this.lastProcessedBlock) {
        this.lastProcessedBlock = log.blockNumber;
      }
    } catch (error) {
      console.error('处理事件失败:', error);
    }
  }
}

// API 服务类
class ApiService {
  constructor(db, port = 3001) {
    this.app = express();
    this.db = db;
    this.port = port;
    this.setupMiddleware();
    this.setupRoutes();
  }

  setupMiddleware() {
    this.app.use(cors());
    this.app.use(express.json());
  }

  setupRoutes() {
    // 健康检查
    this.app.get('/api/health', (req, res) => {
      res.json({
        success: true,
        data: {
          status: 'ok',
          timestamp: new Date().toISOString()
        }
      });
    });

    // 测试接口
    this.app.get('/api/test', (req, res) => {
      res.json({
        success: true,
        data: { message: '服务正常运行' }
      });
    });

    // 获取转账记录
    this.app.get('/api/transfers/:address', async (req, res) => {
      try {
        const address = req.params.address.toLowerCase();
        const limit = parseInt(req.query.limit) || 20;

        const records = await this.db.getTransfersByAddress(address, limit);

        const transfers = records.map(record => ({
          id: record.id,
          transaction_hash: record.transaction_hash,
          block_number: record.block_number,
          from_address: record.from_address,
          to_address: record.to_address,
          amount: record.amount,
          amountFormatted: ethers.formatEther(BigInt(record.amount)),
          token_address: record.token_address,
          timestamp: record.timestamp,
          created_at: record.created_at,
          type: record.from_address.toLowerCase() === address ? 'sent' : 'received'
        }));

        res.json({
          success: true,
          data: {
            transfers,
            pagination: {
              total: transfers.length,
              totalPages: 1,
              currentPage: 1,
              pageSize: limit
            }
          }
        });
      } catch (error) {
        console.error('获取转账记录失败:', error);
        res.status(500).json({
          success: false,
          error: '获取转账记录失败',
          message: error instanceof Error ? error.message : '未知错误'
        });
      }
    });

    // 获取统计信息
    this.app.get('/api/stats/:address', async (req, res) => {
      try {
        const address = req.params.address.toLowerCase();
        const stats = await this.db.getTransferStats(address);

        res.json({
          success: true,
          data: {
            sent: {
              count: stats.sent.count,
              total: stats.sent.total ? ethers.formatEther(BigInt(stats.sent.total.toString())) : '0'
            },
            received: {
              count: stats.received.count,
              total: stats.received.total ? ethers.formatEther(BigInt(stats.received.total.toString())) : '0'
            }
          }
        });
      } catch (error) {
        console.error('获取统计信息失败:', error);
        res.status(500).json({
          success: false,
          error: '获取统计信息失败',
          message: error instanceof Error ? error.message : '未知错误'
        });
      }
    });

    // 错误处理中间件
    this.app.use((err, req, res, next) => {
      console.error('API 错误:', err);
      res.status(500).json({
        success: false,
        error: '服务器内部错误',
        message: err.message
      });
    });
  }

  start() {
    return new Promise((resolve, reject) => {
      const server = this.app.listen(this.port, '127.0.0.1', () => {
        console.log('========================================');
        console.log('✓ API 服务已启动');
        console.log(`✓ 地址: http://localhost:${this.port}`);
        console.log('========================================');
        console.log('API 端点:');
        console.log(`  - GET http://localhost:${this.port}/api/health`);
        console.log(`  - GET http://localhost:${this.port}/api/test`);
        console.log(`  - GET http://localhost:${this.port}/api/transfers/:address`);
        console.log(`  - GET http://localhost:${this.port}/api/stats/:address`);
        console.log('========================================');
        resolve();
      });

      server.on('error', (error) => {
        console.error('服务器启动失败:', error);
        reject(error);
      });
    });
  }
}

// 主函数
async function main() {
  console.log('========================================');
  console.log('启动 ERC20 代币后端服务');
  console.log('========================================');
  console.log(`时间: ${new Date().toISOString()}`);
  console.log(`RPC URL: ${RPC_URL}`);
  console.log(`代币地址: ${TOKEN_ADDRESS || '未设置'}`);
  console.log(`API 端口: ${PORT}`);
  console.log('========================================');

  if (!TOKEN_ADDRESS) {
    console.error('错误: 未设置 TOKEN_ADDRESS 环境变量');
    console.error('请在 .env 文件中设置 TOKEN_ADDRESS');
    process.exit(1);
  }

  // 初始化数据库
  const db = new DatabaseService('./transfers.db');
  await db.initialize();

  // 启动 API 服务
  const api = new ApiService(db, PORT);
  await api.start();

  // 启动区块链索引服务（即使失败也不影响 API 服务）
  try {
    console.log('尝试启动区块链索引服务...');
    const indexer = new BlockchainIndexer(RPC_URL, TOKEN_ADDRESS, db);
    await indexer.start();
  } catch (error) {
    console.error('索引服务启动失败（API 服务仍会运行）:', error.message);
    console.log('提示: 请确保 Anvil 节点正在运行，并且 RPC URL 正确');
  }

  // 保持进程运行
  console.log('========================================');
  console.log('服务已启动，保持运行中...');
  console.log('========================================');
  
  // 防止进程退出
  process.stdin.resume();

  // 优雅关闭
  process.on('SIGINT', async () => {
    console.log('\n========================================');
    console.log('正在关闭服务...');
    console.log('========================================');
    
    await db.close();
    
    console.log('✓ 服务已安全关闭');
    process.exit(0);
  });

  process.on('SIGTERM', async () => {
    console.log('\n收到 SIGTERM 信号，正在关闭...');
    
    await db.close();
    
    process.exit(0);
  });
}

// 启动服务
main().catch((error) => {
  console.error('启动失败:', error);
  process.exit(1);
});
