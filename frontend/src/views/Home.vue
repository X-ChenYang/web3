<template>
  <div class="home">
    <!-- 使用栅格布局：居中显示内容 -->
    <el-row justify="center">
      <!-- 响应式列：根据屏幕宽度调整列数 -->
      <el-col :xs="24" :sm="20" :md="16" :lg="12">
        <!-- 欢迎卡片 -->
        <el-card class="welcome-card">
          <!-- 卡片头部 -->
          <template #header>
            <div class="card-header">
              <!-- 欢迎图标 -->
              <el-icon size="32"><Coin /></el-icon>
              <!-- 欢迎标题 -->
              <h1>欢迎使用 ERC20 转账查询系统</h1>
            </div>
          </template>
          
          <!-- 卡片内容 -->
          <div class="content">
            <!-- 系统介绍 -->
            <p class="description">
              本系统可以帮助您查询指定地址的 ERC20 Token 转账记录。
              请连接您的钱包或输入地址来查看转账历史。
            </p>
            
            <!-- 分割线 -->
            <el-divider />
            
            <!-- 功能特性展示 -->
            <div class="features">
              <h3>功能特性</h3>
              <!-- 栅格布局：显示三个特性 -->
              <el-row :gutter="20">
                <!-- 特性 1：链上索引 -->
                <el-col :span="8">
                  <div class="feature-item">
                    <el-icon size="40" color="#409eff"><Search /></el-icon>
                    <h4>链上索引</h4>
                    <p>使用 Viem 实时索引链上转账数据</p>
                  </div>
                </el-col>
                <!-- 特性 2：数据持久化 -->
                <el-col :span="8">
                  <div class="feature-item">
                    <el-icon size="40" color="#67c23a"><DataLine /></el-icon>
                    <h4>数据持久化</h4>
                    <p>转账记录存储在本地数据库中</p>
                  </div>
                </el-col>
                <!-- 特性 3：直观展示 -->
                <el-col :span="8">
                  <div class="feature-item">
                    <el-icon size="40" color="#e6a23c"><View /></el-icon>
                    <h4>直观展示</h4>
                    <p>清晰展示转入转出记录和统计信息</p>
                  </div>
                </el-col>
              </el-row>
            </div>
            
            <el-divider />
            
            <!-- 操作按钮区域 -->
            <div class="actions">
              <!-- 未连接钱包时显示连接按钮 -- 触发 connect 事件，让父组件处理连接钱包 -->
              <el-button 
                v-if="!isConnected"
                type="primary" 
                size="large"
                @click="$emit('connect')"  
              >
                <el-icon><Wallet /></el-icon>
                连接钱包
              </el-button>
              <!-- 已连接时显示查看记录按钮-- 跳转到转账记录页面 -->
              <el-button 
                v-else
                type="success" 
                size="large"
                @click="$router.push('/transfers')"  
              >
                <el-icon><Document /></el-icon>
                查看我的转账记录
              </el-button>
            </div>
          </div>
        </el-card>
        
        <!-- 地址查询卡片 -->
        <el-card class="query-card" style="margin-top: 20px;">
          <!-- 卡片头部 -->
          <template #header>
            <div class="card-header">
              <!-- 查询图标 -->
              <el-icon size="24"><Search /></el-icon>
              <span>查询任意地址</span>
            </div>
          </template>
          
          <!-- 地址查询表单 -->
          <el-form @submit.prevent="queryAddress">
            <el-form-item>
              <!-- 地址输入框 -- 绑定到 queryInput 响应式变量-->
              <el-input
                v-model="queryInput"  
                placeholder="请输入以太坊地址 (0x...)"
                size="large"
                clearable  
              >
                <!-- 输入框后缀：查询按钮 -->
                <template #append>
                  <el-button type="primary" @click="queryAddress">
                    查询
                  </el-button>
                </template>
              </el-input>
            </el-form-item>
          </el-form>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
// 导入 Vue 的 ref 响应式 API
import { ref } from 'vue';
// 导入 Vue Router 的 useRouter 钩子
import { useRouter } from 'vue-router';

// 创建路由实例
const router = useRouter();

// 接收父组件传递的属性
const props = defineProps({
  account: String,      // 当前连接的钱包地址
  isConnected: Boolean // 钱包是否已连接
});

// 响应式变量：存储用户输入的查询地址
const queryInput = ref('');

// 查询指定地址的转账记录
function queryAddress() {
  // 验证地址格式：必须以 0x 开头
  if (!queryInput.value || !queryInput.value.startsWith('0x')) {
    alert('请输入有效的以太坊地址');
    return;
  }
  
  // 跳转到转账记录页面，并将地址作为查询参数传递
  router.push({
    path: '/transfers',  // 目标路由
    query: { address: queryInput.value }  // 查询参数：address
  });
}
</script>

<style scoped>
/* 欢迎卡片样式 */
.welcome-card {
  text-align: center;  /* 文本居中对齐 */
}

/* 卡片头部样式 */
.card-header {
  display: flex;  /* 使用 Flex 布局 */
  align-items: center;  /* 垂直居中对齐 */
  justify-content: center;  /* 水平居中对齐 */
  gap: 10px;  /* 元素之间的间距 */
}

.card-header h1 {
  margin: 0;  /* 移除默认外边距 */
  font-size: 24px;  /* 字体大小 */
}

/* 描述文本样式 */
.description {
  font-size: 16px;  /* 字体大小 */
  color: #606266;  /* 字体颜色 */
  line-height: 1.6;  /* 行高 */
}

/* 功能特性区域样式 */
.features {
  padding: 20px 0;  /* 上下内边距 */
}

.features h3 {
  margin-bottom: 20px;  /* 底部外边距 */
  color: #303133;  /* 字体颜色 */
}

/* 单个特性项样式 */
.feature-item {
  text-align: center;  /* 文本居中对齐 */
  padding: 20px;  /* 内边距 */
}

.feature-item h4 {
  margin: 10px 0;  /* 上下外边距 */
  color: #303133;  /* 字体颜色 */
}

.feature-item p {
  color: #909399;  /* 字体颜色：灰色 */
  font-size: 14px;  /* 字体大小 */
}

/* 操作按钮区域样式 */
.actions {
  padding: 20px 0;  /* 上下内边距 */
}

/* 查询卡片样式 */
.query-card {
  background-color: #f5f7fa;  /* 背景颜色：浅灰色 */
}
</style>
