// 调试后端服务
const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');

// 加载环境变量
dotenv.config();

// 配置
const PORT = process.env.PORT || 3004;

// 创建 Express 应用
const app = express();

// 中间件
app.use(cors());
app.use(express.json());

// 健康检查
app.get('/api/health', (req, res) => {
  res.json({
    success: true,
    data: {
      status: 'ok',
      timestamp: new Date().toISOString()
    }
  });
});

// 测试接口
app.get('/api/test', (req, res) => {
  res.json({
    success: true,
    data: {
      message: '服务正常运行',
      port: PORT,
      environment: process.env.NODE_ENV || 'development'
    }
  });
});

// 启动服务器
console.log('服务器启动中...');
console.log(`端口: ${PORT}`);

const server = app.listen(PORT, '127.0.0.1', () => {
  console.log('========================================');
  console.log('✓ 后端服务已启动');
  console.log(`✓ 地址: http://localhost:${PORT}`);
  console.log('========================================');
  console.log('API 端点:');
  console.log(`  - GET http://localhost:${PORT}/api/health`);
  console.log(`  - GET http://localhost:${PORT}/api/test`);
  console.log('========================================');
});

// 错误处理
server.on('error', (error) => {
  console.error('服务器启动失败:', error);
  process.exit(1);
});

// 防止进程退出
process.stdin.resume();

// 优雅关闭
process.on('SIGINT', () => {
  console.log('\n========================================');
  console.log('正在关闭服务...');
  console.log('========================================');
  
  server.close(() => {
    console.log('✓ 服务已安全关闭');
    process.exit(0);
  });
});

process.on('SIGTERM', () => {
  console.log('\n收到 SIGTERM 信号，正在关闭...');
  
  server.close(() => {
    process.exit(0);
  });
});
