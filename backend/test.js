// 简单的测试脚本
console.log('Node.js 版本:', process.version);
console.log('当前目录:', process.cwd());
console.log('Hello World!');

// 尝试加载一些依赖
try {
  const express = require('express');
  console.log('✓ express 加载成功');
} catch (error) {
  console.error('✗ express 加载失败:', error);
}

try {
  const cors = require('cors');
  console.log('✓ cors 加载成功');
} catch (error) {
  console.error('✗ cors 加载失败:', error);
}

try {
  const dotenv = require('dotenv');
  console.log('✓ dotenv 加载成功');
} catch (error) {
  console.error('✗ dotenv 加载失败:', error);
}

try {
  const sqlite3 = require('sqlite3');
  console.log('✓ sqlite3 加载成功');
} catch (error) {
  console.error('✗ sqlite3 加载失败:', error);
}

try {
  const { open } = require('sqlite');
  console.log('✓ sqlite 加载成功');
} catch (error) {
  console.error('✗ sqlite 加载失败:', error);
}

try {
  const { ethers } = require('ethers');
  console.log('✓ ethers 加载成功');
} catch (error) {
  console.error('✗ ethers 加载失败:', error);
}

console.log('测试完成');
