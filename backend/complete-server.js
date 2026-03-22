// 导入 Express 框架：用于创建 Web 服务器和 API 接口
const express = require('express');
// 导入 CORS 中间件：用于处理跨域请求，允许前端访问后端 API
const cors = require('cors');
// 导入 dotenv 模块：用于从 .env 文件中加载环境变量
const dotenv = require('dotenv');
// 导入 sqlite3 模块：用于操作 SQLite 数据库
const sqlite3 = require('sqlite3');
// 导入 sqlite 模块：提供更友好的 SQLite 数据库操作接口
const { open } = require('sqlite');
// 导入 ethers.js 库：用于与以太坊区块链交互
const { ethers } = require('ethers');

// 加载环境变量：从 .env 文件中读取配置信息
dotenv.config();

// 配置参数：从环境变量中读取，如果没有则使用默认值
const PORT = process.env.PORT || 3005;  // API 服务端口号
const RPC_URL = process.env.RPC_URL || 'http://localhost:8545';  // 区块链节点 RPC 地址
const TOKEN_ADDRESS = process.env.TOKEN_ADDRESS || '';  // ERC20 代币合约地址
const START_BLOCK = parseInt(process.env.START_BLOCK || '0');  // 开始索引的区块号

// ERC20 合约 ABI（Application Binary Interface）：定义了合约的接口，包括事件和函数
// ABI 是前端/后端与智能合约交互的桥梁
const ERC20_ABI = [
  // Transfer 事件：当代币被转移时触发
  // indexed 参数表示该参数可以被过滤查询
  {
    "anonymous": false,  // 非匿名事件
    "inputs": [
      { "indexed": true, "internalType": "address", "name": "from", "type": "address" },  // 发送方地址
      { "indexed": true, "internalType": "address", "name": "to", "type": "address" },    // 接收方地址
      { "indexed": false, "internalType": "uint256", "name": "value", "type": "uint256" }   // 转账金额
    ],
    "name": "Transfer",  // 事件名称
    "type": "event"      // 类型为事件
  },
  // name 函数：获取代币名称
  {
    "inputs": [],  // 无输入参数
    "name": "name",  // 函数名称
    "outputs": [{ "internalType": "string", "name": "", "type": "string" }],  // 返回字符串类型的代币名称
    "stateMutability": "view",  // 状态可变性：只读，不修改区块链状态
    "type": "function"  // 类型为函数
  },
  // symbol 函数：获取代币符号
  {
    "inputs": [],
    "name": "symbol",
    "outputs": [{ "internalType": "string", "name": "", "type": "string" }],
    "stateMutability": "view",
    "type": "function"
  },
  // decimals 函数：获取代币小数位数
  {
    "inputs": [],
    "name": "decimals",
    "outputs": [{ "internalType": "uint8", "name": "", "type": "uint8" }],
    "stateMutability": "view",
    "type": "function"
  },
  // totalSupply 函数：获取代币总供应量
  {
    "inputs": [],
    "name": "totalSupply",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  }
];

// 数据库服务类：负责管理数据库连接和操作
class DatabaseService {
  // 构造函数：初始化数据库服务
  // 参数 dbPath：数据库文件路径，默认为 './transfers.db'
  constructor(dbPath = './transfers.db') {
    this.dbPath = dbPath;  // 保存数据库文件路径
    this.db = null;  // 数据库连接对象，初始为 null
  }

  // 初始化数据库连接
  async initialize() {
    try {
      // 打开数据库连接
      // filename: 数据库文件路径
      // driver: 使用的数据库驱动，这里使用 sqlite3
      this.db = await open({
        filename: this.dbPath,
        driver: sqlite3.Database
      });

      // 创建数据表
      await this.createTables();
      console.log('✓ 数据库连接成功');
    } catch (error) {
      console.error('✗ 数据库连接失败:', error);
      throw error;  // 抛出错误，让调用者处理
    }
  }

  // 创建数据表和索引
  async createTables() {
    if (!this.db) return;  // 如果数据库未连接，直接返回

    // 执行 SQL 语句创建表和索引
    // 创建转账记录表
      // id: 主键，自增
      // transaction_hash: 交易哈希，唯一标识一笔交易
      // block_number: 区块号
      // from_address: 发送方地址
      // to_address: 接收方地址
      // amount: 转账金额（字符串格式，避免精度丢失）
      // token_address: 代币合约地址
      // timestamp: 时间戳
      // created_at: 记录创建时间
            // 创建索引：提高查询性能
      // 索引可以加速 WHERE 子句的查询
    await this.db.exec(`
        CREATE TABLE IF NOT EXISTS transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_hash TEXT UNIQUE NOT NULL,
        block_number INTEGER NOT NULL,
        from_address TEXT NOT NULL,
        to_address TEXT TEXT NOT NULL,
        amount TEXT NOT NULL,
        token_address TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );
      DELETE FROM transfers;
      CREATE INDEX IF NOT EXISTS idx_from_address ON transfers(from_address);
      CREATE INDEX IF NOT EXISTS idx_to_address ON transfers(to_address);
      CREATE INDEX IF NOT EXISTS idx_block_number ON transfers(block_number);
      CREATE INDEX IF NOT EXISTS idx_token_address ON transfers(token_address);
    `);
    // await this.db.exec(`
    //     truncate TABLE  transfers
    // `);
  }

  // 保存转账记录到数据库
  // 参数：
  //   event: 转账事件对象，包含交易哈希、区块号、发送方、接收方、金额等信息
  //   tokenAddress: 代币合约地址
  //   timestamp: 区块时间戳
  async saveTransfer(event, tokenAddress, timestamp) {
    if (!this.db) {
      throw new Error('数据库未初始化');
    }

    try {
      // 插入或忽略（如果交易哈希已存在）
      // INSERT OR IGNORE: 如果记录已存在（根据 UNIQUE 约束），则忽略插入
      await this.db.run(
        `INSERT OR IGNORE INTO transfers 
         (transaction_hash, block_number, from_address, to_address, amount, token_address, timestamp)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          event.transactionHash,  // 交易哈希
          event.blockNumber,      // 区块号
          event.from.toLowerCase(),  // 发送方地址（转为小写）
          event.to.toLowerCase(),    // 接收方地址（转为小写）
          event.value.toString(),    // 金额（转为字符串）
          tokenAddress.toLowerCase(), // 代币合约地址（转为小写）
          timestamp                 // 时间戳
        ]
      );
    } catch (error) {
      console.error('保存转账记录失败:', error);
      throw error;
    }
  }

  // 根据地址查询转账记录
  // 参数：
  //   address: 要查询的地址
  //   limit: 返回记录的最大数量，默认为 20
  // 返回：转账记录数组
  async getTransfersByAddress(address, limit = 20) {
    if (!this.db) {
      throw new Error('数据库未初始化');
    }

    const lowerAddress = address.toLowerCase();  // 转为小写，确保查询一致
    
    // 查询与该地址相关的所有转账记录（作为发送方或接收方）
    // 按区块号降序排列（最新的在前）
    return await this.db.all(
      `SELECT * FROM transfers 
       WHERE LOWER(from_address) = ? OR LOWER(to_address) = ? 
       ORDER BY block_number DESC 
       LIMIT ?`,
      [lowerAddress, lowerAddress, limit]
    );
  }

  // 获取地址的转账统计信息
  // 参数：
  //   address: 要统计的地址
  // 返回：包含转出和转入的统计信息（笔数和总金额）
  async getTransferStats(address) {
    if (!this.db) {
      throw new Error('数据库未初始化');
    }

    const lowerAddress = address.toLowerCase();

    // 查询转出统计
    // COUNT(*): 统计记录数
    // SUM(CAST(amount AS REAL)): 计算总金额（将字符串转为浮点数）
    // COALESCE(..., 0): 如果结果为 NULL，则返回 0
    const sentResult = await this.db.get(
      `SELECT COUNT(*) as count, COALESCE(SUM(CAST(amount AS REAL)), 0) as total 
       FROM transfers 
       WHERE LOWER(from_address) = ?`,
      [lowerAddress]
    );

    // 查询转入统计
    const receivedResult = await this.db.get(
      `SELECT COUNT(*) as count, COALESCE(SUM(CAST(amount AS REAL)), 0) as total 
       FROM transfers 
       WHERE LOWER(to_address) = ?`,
      [lowerAddress]
    );

    // 返回统计结果
    return {
      sent: {
        count: sentResult?.count || 0,      // 转出笔数
        total: sentResult?.total || '0'        // 转出总金额
      },
      received: {
        count: receivedResult?.count || 0,     // 转入笔数
        total: receivedResult?.total || '0'   // 转入总金额
      }
    };
  }

  // 获取数据库中已处理的最新区块号
  // 返回：最新区块号，如果没有记录则返回 START_BLOCK
  async getLatestBlockNumber() {
    if (!this.db) {
      throw new Error('数据库未初始化');
    }

    // 查询最大的区块号
    const result = await this.db.get(
      'SELECT MAX(block_number) as maxBlock FROM transfers'
    );

    return result?.maxBlock || START_BLOCK;
  }

  // 关闭数据库连接
  async close() {
    if (this.db) {
      await this.db.close();
      this.db = null;
      console.log('数据库连接已关闭');
    }
  }
}

// 区块链索引服务类：负责监听区块链上的转账事件并保存到数据库
class BlockchainIndexer {
  // 构造函数：初始化索引服务
  // 参数：
  //   rpcUrl: 区块链节点的 RPC 地址
  //   tokenAddress: ERC20 代币合约地址
  //   db: 数据库服务实例
  constructor(rpcUrl, tokenAddress, db) {
    // 创建以太坊提供者：用于与区块链节点通信
    this.provider = new ethers.JsonRpcProvider(rpcUrl);
    this.tokenAddress = tokenAddress;  // 代币合约地址
    this.db = db;  // 数据库服务实例
    this.isRunning = false;  // 索引服务运行状态
    this.lastProcessedBlock = START_BLOCK;  // 上次处理的区块号
    this.pollInterval = null;  // 轮询定时器
  }

  // 启动索引服务
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
      // 创建合约实例
      const tokenContract = new ethers.Contract(this.tokenAddress, ERC20_ABI, this.provider);
      
      // 并行获取代币信息（name、symbol、decimals）
      // Promise.all: 同时执行多个异步操作，提高效率
      const [name, symbol, decimals] = await Promise.all([
        tokenContract.name(),      // 获取代币名称
        tokenContract.symbol(),    // 获取代币符号
        tokenContract.decimals()   // 获取代币小数位数
      ]);
      console.log(`代币名称: ${name} (${symbol})`);
      console.log(`小数位: ${decimals}`);
    } catch (error) {
      console.warn('获取代币信息失败 (区块链节点可能未启动):', error.message);
    }

    // 获取数据库中已处理的最新区块号
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

  // 停止索引服务
  stop() {
    this.isRunning = false;
    if (this.pollInterval) {
      clearInterval(this.pollInterval);  // 清除定时器
      this.pollInterval = null;
    }
    console.log('索引服务已停止');
  }

  // 扫描历史区块：从上次处理的区块号到当前最新区块
  async scanHistoricalBlocks() {
    try {
      // 获取当前最新区块号
      const currentBlock = await this.provider.getBlockNumber();
      // 计算开始扫描的区块号
      const fromBlock = Math.max(this.lastProcessedBlock + 1, START_BLOCK);

      // 如果没有新区块，直接返回
      if (fromBlock >= currentBlock) {
        console.log('没有历史区块需要扫描');
        return;
      }

      console.log(`扫描历史区块: ${fromBlock} - ${currentBlock}`);

      // 创建合约实例
      const tokenContract = new ethers.Contract(this.tokenAddress, ERC20_ABI, this.provider);
      // 查询指定区块范围内的 Transfer 事件
      const logs = await tokenContract.queryFilter('Transfer', fromBlock, currentBlock);

      console.log(`找到 ${logs.length} 个历史转账事件`);

      // 处理每个事件日志
      for (const log of logs) {
        await this.processLog(log);
      }

      console.log(`✓ 历史区块扫描完成`);
    } catch (error) {
      console.warn('扫描历史区块失败 (区块链节点可能未启动):', error.message);
    }
  }

  // 监听新的转账事件：使用轮询方式
  listenToEvents() {
    console.log('开始监听新的转账事件...');
    
    // 使用 setInterval 定时轮询新事件
    // 每 5 秒检查一次是否有新的转账事件
    this.pollInterval = setInterval(async () => {
      // 如果服务已停止，清除定时器
      if (!this.isRunning) {
        if (this.pollInterval) {
          clearInterval(this.pollInterval);
          this.pollInterval = null;
        }
        return;
      }

      try {
        // 获取当前最新区块号
        const currentBlock = await this.provider.getBlockNumber();
        // 计算需要查询的区块范围
        const fromBlock = this.lastProcessedBlock + 1;

        // 如果有新区块，查询 Transfer 事件
        if (fromBlock <= currentBlock) {
          const tokenContract = new ethers.Contract(this.tokenAddress, ERC20_ABI, this.provider);
          const logs = await tokenContract.queryFilter('Transfer', fromBlock, currentBlock);

          // 处理每个事件日志
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

  // 处理事件日志：解析事件并保存到数据库
  async processLog(log) {
    try {
      // 获取区块信息（包含时间戳）
      const block = await this.provider.getBlock(log.blockNumber);
      
      // 解析转账事件
      const transferEvent = {
        transactionHash: log.transactionHash,  // 交易哈希
        blockNumber: log.blockNumber,          // 区块号
        from: log.args.from,                   // 发送方地址
        to: log.args.to,                       // 接收方地址
        value: log.args.value                   // 转账金额
      };

      // 保存转账记录到数据库
      await this.db.saveTransfer(transferEvent, this.tokenAddress, block.timestamp);

      // 打印转账信息
      console.log(`[区块 ${log.blockNumber}] 转账: ${transferEvent.from.slice(0, 10)}... -> ${transferEvent.to.slice(0, 10)}... 金额: ${ethers.formatEther(transferEvent.value)}`);

      // 更新最后处理的区块号
      if (log.blockNumber > this.lastProcessedBlock) {
        this.lastProcessedBlock = log.blockNumber;
      }
    } catch (error) {
      console.error('处理事件失败:', error);
    }
  }
}

// API 服务类：负责提供 RESTful API 接口
class ApiService {
  // 构造函数：初始化 API 服务
  // 参数：
  //   db: 数据库服务实例
  //   port: API 服务端口号，默认为 3003
  constructor(db, port = 3003) {
    this.app = express();  // 创建 Express 应用
    this.db = db;         // 数据库服务实例
    this.port = port;     // 端口号
    this.setupMiddleware();  // 设置中间件
    this.setupRoutes();      // 设置路由
  }

  // 设置中间件：在请求处理之前执行的函数
  setupMiddleware() {
    this.app.use(cors());  // 启用 CORS，允许跨域请求
    this.app.use(express.json());  // 解析 JSON 格式的请求体
  }

  // 设置路由：定义 API 端点和处理函数
  setupRoutes() {
    // 健康检查接口：用于检查服务是否正常运行
    this.app.get('/api/health', (req, res) => {
      res.json({
        success: true,
        data: {
          status: 'ok',
          timestamp: new Date().toISOString()
        }
      });
    });

    // 测试接口：用于测试服务是否正常响应
    this.app.get('/api/test', (req, res) => {
      res.json({
        success: true,
        data: { message: '服务正常运行' }
      });
    });

    // 获取转账记录接口
    // 路径参数：address - 要查询的地址
    // 查询参数：limit - 返回记录的最大数量
    this.app.get('/api/transfers/:address', async (req, res) => {
      try {
        const address = req.params.address.toLowerCase();  // 获取地址参数并转为小写
        const limit = parseInt(req.query.limit) || 20;      // 获取限制数量，默认为 20

        // 从数据库查询转账记录
        const records = await this.db.getTransfersByAddress(address, limit);

        // 格式化转账记录
        const transfers = records.map(record => ({
          id: record.id,                              // 记录 ID
          transaction_hash: record.transaction_hash,    // 交易哈希
          block_number: record.block_number,            // 区块号
          from_address: record.from_address,            // 发送方地址
          to_address: record.to_address,                // 接收方地址
          amount: record.amount,                        // 金额（原始值）
          amountFormatted: ethers.formatEther(BigInt(record.amount)),  // 金额（格式化后）
          token_address: record.token_address,          // 代币合约地址
          timestamp: record.timestamp,                    // 时间戳
          created_at: record.created_at,                 // 创建时间
          type: record.from_address.toLowerCase() === address ? 'sent' : 'received'  // 类型：转出或转入
        }));

        // 返回成功响应
        res.json({
          success: true,
          data: {
            transfers,  // 转账记录列表
            pagination: {  // 分页信息
              total: transfers.length,  // 总记录数
              totalPages: 1,           // 总页数（当前未实现分页）
              currentPage: 1,           // 当前页码
              pageSize: limit           // 每页数量
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

    // 获取统计信息接口
    // 路径参数：address - 要统计的地址
    this.app.get('/api/stats/:address', async (req, res) => {
      // 辅助函数：将科学计数法转换为普通数字字符串
      // 用于处理 SQLite 返回的大数字（如 8e+21）
      function scientificToDecimal(num) {
        if (typeof num !== 'number') return num;  // 如果不是数字，直接返回
        const n = num.toExponential().split('e');  // 将数字转换为科学计数法表示
        const sign = n[0].includes('-') ? '-' : '';  // 判断符号
        let [intPart, exp] = n[0].replace('-', '').split('.');  // 分离整数部分和指数
        const power = parseInt(exp, 10);  // 解析指数
        
        if (power >= 0) {
          // 正指数：在整数部分后面补零
          intPart = intPart.replace('.', '') + '0'.repeat(power - (intPart.split('.')[1]?.length || 0));
        } else {
          // 负指数：在前面补零并添加小数点
          intPart = '0.' + '0'.repeat(-power - 1) + intPart.replace('.', '');
        }
        return sign + intPart;
      }

      try {
        const address = req.params.address.toLowerCase();  // 获取地址参数并转为小写
        const stats = await this.db.getTransferStats(address);  // 从数据库获取统计信息
        
        // 添加日志，查看 stats.sent.total 的值和类型（用于调试）
        console.log('========================================');
        console.log('Stats sent total:', stats.sent.total);
        console.log('Type of stats.sent.total:', typeof stats.sent.total);
        console.log('Stats received total:', stats.received.total);
        console.log('Type of stats.received.total:', typeof stats.received.total);
        console.log('========================================');
        
        // 返回成功响应
        res.json({
          success: true,
          data: {
            sent: {
              count: stats.sent.count,  // 转出笔数
              // 转出总金额（格式化后）
              // 如果是数字类型，使用 toLocaleString 转换为完整字符串
              // 否则直接使用字符串值
              total: stats.sent.total ? ethers.formatEther(BigInt(typeof stats.sent.total === 'number' 
    ? stats.sent.total.toLocaleString('fullwide', { useGrouping: false }) 
    : stats.sent.total)) : '0'
            },
            received: {
              count: stats.received.count,  // 转入笔数
              // 转入总金额（格式化后）
              total: stats.received.total ? ethers.formatEther(BigInt(typeof stats.received.total === 'number' 
    ? stats.received.total.toLocaleString('fullwide', { useGrouping: false }) 
    : stats.received.total)) : '0'
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

    // 错误处理中间件：捕获所有未处理的错误
    this.app.use((err, req, res, next) => {
      console.error('API 错误:', err);
      res.status(500).json({
        success: false,
        error: '服务器内部错误',
        message: err.message
      });
    });
  }

  // 启动 API 服务
  start() {
    return new Promise((resolve, reject) => {
      // 监听指定端口
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
        resolve();  // 服务启动成功，解析 Promise
      });

      // 监听服务器错误事件
      server.on('error', (error) => {
        console.error('服务器启动失败:', error);
        reject(error);  // 服务启动失败，拒绝 Promise
      });
    });
  }
}

// 主函数：程序的入口点
async function main() {
  console.log('========================================');
  console.log('启动 ERC20 代币后端服务');
  console.log('========================================');
  console.log(`时间: ${new Date().toISOString()}`);
  console.log(`RPC URL: ${RPC_URL}`);
  console.log(`代币地址: ${TOKEN_ADDRESS || '未设置'}`);
  console.log(`API 端口: ${PORT}`);
  console.log('========================================');

  // 检查是否设置了代币合约地址
  if (!TOKEN_ADDRESS) {
    console.error('错误: 未设置 TOKEN_ADDRESS 环境变量');
    console.error('请在 .env 文件中设置 TOKEN_ADDRESS');
    process.exit(1);  // 退出程序
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
  
  // 防止进程退出：读取标准输入流
  process.stdin.resume();

  // 优雅关闭：处理 SIGINT 信号（Ctrl+C）
  process.on('SIGINT', async () => {
    console.log('\n========================================');
    console.log('正在关闭服务...');
    console.log('========================================');
    
    await db.close();  // 关闭数据库连接
    
    console.log('✓ 服务已安全关闭');
    process.exit(0);  // 退出程序
  });

  // 优雅关闭：处理 SIGTERM 信号
  process.on('SIGTERM', async () => {
    console.log('\n收到 SIGTERM 信号，正在关闭...');
    
    await db.close();  // 关闭数据库连接
    
    process.exit(0);  // 退出程序
  });
}

// 启动服务
main().catch((error) => {
  console.error('启动失败:', error);
  process.exit(1);
});
