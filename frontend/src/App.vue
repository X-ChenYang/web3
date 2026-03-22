<template>
  <div class="app">
    <!-- Element Plus 的容器组件：用于布局 -->
    <el-container>
      <!-- 顶部导航栏 -->
      <el-header class="header">
        <!-- Logo 和标题区域 -->
        <div class="logo">
          <!-- 代币图标 -->
          <el-icon size="24"><Coin /></el-icon>
          <!-- 应用标题 -->
          <span>ERC20 转账查询</span>
        </div>
        
        <!-- 导航菜单：水平模式，支持路由跳转 -->
        <el-menu
          :default-active="$route.path"  
          class="nav-menu"
          mode="horizontal"  
          router  
        >
          <!-- 首页菜单项 -->
          <el-menu-item index="/">首页</el-menu-item>
          <!-- 转账记录菜单项 -->
          <el-menu-item index="/transfers">转账记录</el-menu-item>
        </el-menu>
        
        <!-- 钱包连接按钮或地址显示区域 -->
        <div class="wallet">
          <!-- 未连接时显示连接按钮 -->
          <el-button 
            v-if="!isConnected"  
            type="primary" 
            @click="connectWallet"  
          >
            连接钱包
          </el-button>
          <!-- 已连接时显示地址标签 -->
          <el-tag v-else type="success" size="large">
            <!-- 显示缩短后的地址（只显示前 6 位和后 4 位） -->
            {{ shortenedAddress }}
          </el-tag>
        </div>
      </el-header>
      
      <!-- 主内容区域 -->
      <el-main class="main">
        <!-- 路由视图：根据当前路由显示不同页面 -->
        <!-- 将 account 和 isConnected 作为属性传递给子组件 -->
        <!-- @connect: 监听子组件的 connect 事件，调用 connectWallet 函数 -->
        <router-view 
          :account="account"
          :is-connected="isConnected"
          @connect="connectWallet"
        />
      </el-main>
      
      <!-- 底部页脚 -->
      <el-footer class="footer">
        <p>Web3 ERC20 转账记录查询系统 © 2024</p>
      </el-footer>
    </el-container>
  </div>
</template>

<script setup>
// 导入 Vue 的响应式 API：ref、computed、onMounted
import { ref, computed, onMounted } from 'vue';
// 导入 Ethers.js 库：用于与以太坊区块链交互
import { ethers } from 'ethers';

// 响应式变量：存储当前连接的钱包地址
const account = ref('');
// 响应式变量：标识钱包是否已连接
const isConnected = ref(false);

// 计算属性：缩短地址显示
// 只显示前 6 位和后 4 位，例如：0x1234...5678
const shortenedAddress = computed(() => {
  if (!account.value) return '';  // 如果没有地址，返回空字符串
  return `${account.value.slice(0, 6)}...${account.value.slice(-4)}`;  // 截取前 6 位和后 4 位
});

// 连接钱包函数：用于连接用户的 MetaMask 钱包
async function connectWallet() {
  try {
    // 检查浏览器是否安装了 MetaMask
    // window.ethereum 是 MetaMask 注入的全局对象
    if (typeof window.ethereum === 'undefined') {
      alert('请安装 MetaMask 钱包!');
      return;
    }
    
    // 创建 Ethers 的浏览器提供者
    // BrowserProvider 是 ethers.js 提供的用于与浏览器钱包交互的提供者
    const provider = new ethers.BrowserProvider(window.ethereum);
    // 请求用户授权访问钱包账户
    // eth_requestAccounts 是 MetaMask 提供的方法，用于请求账户访问权限
    const accounts = await provider.send('eth_requestAccounts', []);
    
    // 保存连接的账户地址
    account.value = accounts[0];
    isConnected.value = true;
    
    // 监听账户变化事件
    // accountsChanged: 当用户在 MetaMask 中切换账户时触发
    window.ethereum.on('accountsChanged', (accounts) => {
      // 如果没有账户（用户断开连接）
      if (accounts.length === 0) {
        account.value = '';  // 清空地址
        isConnected.value = false;  // 标记为未连接
      } else {
        // 更新为当前选中的账户
        account.value = accounts[0];
      }
    });
  } catch (error) {
    // 捕获连接错误
    console.error('连接钱包失败:', error);
    alert('连接钱包失败: ' + error.message);
  }
}

// 组件挂载时执行的生命周期钩子
onMounted(async () => {
  // 检查是否已经连接了钱包
  if (typeof window.ethereum !== 'undefined') {
    try {
      // 创建提供者
      const provider = new ethers.BrowserProvider(window.ethereum);
      // 获取已授权的账户列表
      // listAccounts: 获取当前已授权的账户，不需要用户再次授权
      const accounts = await provider.listAccounts();
      
      // 如果有已授权的账户，自动连接
      if (accounts.length > 0) {
        account.value = accounts[0].address;  // 保存第一个账户的地址
        isConnected.value = true;  // 标记为已连接
      }
    } catch (error) {
      // 检查钱包连接状态失败
      console.error('检查钱包连接失败:', error);
    }
  }
});
</script>

<style scoped>
/* 应用容器：最小高度为 100vh，占满整个屏幕 */
.app {
  min-height: 100vh;
}

/* 顶部导航栏样式 */
.header {
  display: flex;  /* 使用 Flex 布局 */
  align-items: center;  /* 垂直居中对齐 */
  justify-content: space-between;  /* 水平两端对齐 */
  background-color: #fff;  /* 背景颜色：白色 */
  border-bottom: 1px solid #dcdfe6;  /* 底部边框 */
  padding: 0 20px;  /* 内边距 */
}

/* Logo 和标题样式 */
.logo {
  display: flex;  /* 使用 Flex 布局 */
  align-items: center;  /* 垂直居中对齐 */
  gap: 10px;  /* 元素之间的间距 */
  font-size: 20px;  /* 字体大小 */
  font-weight: bold;  /* 字体加粗 */
  color: #409eff;  /* 字体颜色：Element Plus 的主题蓝色 */
}

/* 导航菜单样式 */
.nav-menu {
  flex: 1;  /* 占据剩余空间 */
  margin: 0 40px;  /* 左右边距 */
  border-bottom: none;  /* 移除底部边框 */
}

/* 钱包区域样式 */
.wallet {
  display: flex;  /* 使用 Flex 布局 */
  align-items: center;  /* 垂直居中对齐 */
}

/* 主内容区域样式 */
.main {
  min-height: calc(100vh - 120px);  /* 最小高度：屏幕高度减去头部和底部的高度 */
  background-color: #f5f7fa;  /* 背景颜色：浅灰色 */
  padding: 20px;  /* 内边距 */
}

/* 底部页脚样式 */
.footer {
  text-align: center;  /* 文本居中对齐 */
  background-color: #fff;  /* 背景颜色：白色 */
  border-top: 1px solid #dcdfe6;  /* 顶部边框 */
  color: #909399;  /* 字体颜色：灰色 */
}
</style>
