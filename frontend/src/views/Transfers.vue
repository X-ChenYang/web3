<template>
  <div class="transfers">
    <!-- 使用栅格布局：左右两列布局 -->
    <el-row :gutter="20">
      <!-- 左侧：统计信息卡片 -->
      <el-col :xs="24" :lg="6">
        <el-card class="stats-card">
          <!-- 卡片头部 -->
          <template #header>
            <div class="card-header">
              <el-icon><DataLine /></el-icon>
              <span>统计信息</span>
            </div>
          </template>
          
          <!-- 显示查询的地址 -->
          <div class="address-info">
            <p class="label">查询地址</p>
            <p class="address">{{ shortenAddress(address) }}</p>
          </div>
          
          <el-divider />
          
          <!-- 统计数据展示 -->
          <div class="stats">
            <!-- 转出统计 -->
            <div class="stat-item">
              <p class="stat-label">转出笔数</p>
              <p class="stat-value sent">{{ stats.sent.count }}</p>
              <p class="stat-amount">{{ formatAmount(stats.sent.total) }} MTK</p>
            </div>
            
            <el-divider />
            
            <!-- 转入统计 -->
            <div class="stat-item">
              <p class="stat-label">转入笔数</p>
              <p class="stat-value received">{{ stats.received.count }}</p>
              <p class="stat-amount">{{ formatAmount(stats.received.total) }} MTK</p>
            </div>
          </div>
        </el-card>
      </el-col>
      
      <!-- 右侧：转账记录列表卡片 -->
      <el-col :xs="24" :lg="18">
        <el-card>
          <!-- 卡片头部 -->
          <template #header>
            <div class="card-header">
              <el-icon><List /></el-icon>
              <span>转账记录</span>
              <!-- 筛选按钮组 -->
              <el-radio-group v-model="filterType" size="small" style="margin-left: auto;">
                <el-radio-button label="all">全部</el-radio-button>
                <el-radio-button label="sent">转出</el-radio-button>
                <el-radio-button label="received">转入</el-radio-button>
              </el-radio-group>
            </div>
          </template>
          
          <!-- 加载状态：显示骨架屏 -->
          <el-skeleton v-if="loading" :rows="5" animated />
          
          <!-- 转账列表表格 -->
          <el-table 
            v-else
            :data="transfers"  
            style="width: 100%"
            :default-sort="{ prop: 'block_number', order: 'descending' }"  
          >
            <!-- 类型列 -->
            <el-table-column label="类型" width="100">
              <template #default="{ row }">
                <el-tag 
                  :type="row.type === 'sent' ? 'danger' : 'success'"  
                  size="small"
                >
                  {{ row.type === 'sent' ? '转出' : '转入' }}
                </el-tag>
              </template>
            </el-table-column>
            
            <!-- 交易哈希列 -->
            <el-table-column label="交易哈希" min-width="120">
              <template #default="{ row }">
                <el-link 
                  type="primary" 
                  :href="`https://sepolia.etherscan.io/tx/${row.transaction_hash}`"  
                  target="_blank"  
                >
                  {{ shortenHash(row.transaction_hash) }}
                </el-link>
              </template>
            </el-table-column>
            
            <!-- 发送方地址列 -->
            <el-table-column label="发送方" min-width="120">
              <template #default="{ row }">
                <span :class="{ 'highlight': row.from_address === address.toLowerCase() }">
                  {{ shortenAddress(row.from_address) }}
                </span>
              </template>
            </el-table-column>
            
            <!-- 接收方地址列 -->
            <el-table-column label="接收方" min-width="120">
              <template #default="{ row }">
                <span :class="{ 'highlight': row.to_address === address.toLowerCase() }">
                  {{ shortenAddress(row.to_address) }}
                </span>
              </template>
            </el-table-column>
            
            <!-- 金额列 -->
            <el-table-column label="金额" width="150" align="right">
              <template #default="{ row }">
                <span :class="{ 'amount-sent': row.type === 'sent', 'amount-received': row.type === 'received' }">
                  {{ row.type === 'sent' ? '-' : '+' }}{{ formatAmount(row.amount) }}
                </span>
              </template>
            </el-table-column>
            
            <!-- 区块号列 -->
            <el-table-column label="区块" prop="block_number" width="100" sortable />
            
            <!-- 时间列 -->
            <el-table-column label="时间" width="180">
              <template #default="{ row }">
                {{ formatTime(row.timestamp) }}
              </template>
            </el-table-column>
          </el-table>
          
          <!-- 分页组件 -->
          <div class="pagination">
            <el-pagination
              v-model:current-page="currentPage"  
              v-model:page-size="pageSize"  
              :page-sizes="[10, 20, 50, 100]"  
              :total="pagination.total"  
              layout="total, sizes, prev, pager, next"  
              @size-change="handleSizeChange"  
              @current-change="handleCurrentChange"  
            />
          </div>
          
          <!-- 空状态：没有数据时显示 -->
          <el-empty v-if="!loading && transfers.length === 0" description="暂无转账记录" />
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
// 导入 Vue 的响应式 API：ref、computed、watch、onMounted
import { ref, computed, watch, onMounted } from 'vue';
// 导入 Vue Router 的 useRoute 钩子
import { useRoute } from 'vue-router';
// 导入 Axios：用于发送 HTTP 请求
import axios from 'axios';
// 导入 ethers.js：用于格式化金额
import { ethers } from 'ethers';

// 获取当前路由信息
const route = useRoute();

// 接收父组件传递的属性
const props = defineProps({
  account: String,      // 当前连接的钱包地址
  isConnected: Boolean // 钱包是否已连接
});

// 响应式变量
const loading = ref(false);  // 加载状态：true 表示正在加载数据
const transfers = ref([]);   // 转账记录列表
const filterType = ref('all'); // 筛选类型：all（全部）、sent（转出）、received（转入）
const currentPage = ref(1);    // 当前页码
const pageSize = ref(20);       // 每页显示数量
const pagination = ref({ total: 0, totalPages: 0 }); // 分页信息
const stats = ref({  // 统计信息
  sent: { count: 0, total: '0' },      // 转出统计
  received: { count: 0, total: '0' }   // 转入统计
});

// 计算属性：当前查询的地址
// 优先使用路由参数中的地址，否则使用连接的钱包地址
const address = computed(() => {
  return route.query.address || props.account || '';
});

// 获取转账记录
async function fetchTransfers() {
  // 如果没有地址，不执行查询
  if (!address.value) return;
  
  // 设置加载状态
  loading.value = true;
  try {
    // 发送 GET 请求获取转账记录
    const response = await axios.get(`/api/transfers/${address.value}`, {
      params: {
        type: filterType.value,  // 筛选类型
        page: currentPage.value,   // 页码
        limit: pageSize.value      // 每页数量
      }
    });
    
    // 如果请求成功
    if (response.data.success) {
      // 保存转账记录
      transfers.value = response.data.data.transfers;
      // 保存分页信息
      pagination.value = response.data.data.pagination;
    }
  } catch (error) {
    // 捕获错误
    console.error('获取转账记录失败:', error);
    alert('获取转账记录失败');
  } finally {
    // 无论成功失败，都关闭加载状态
    loading.value = false;
  }
}

// 获取统计信息
async function fetchStats() {
  // 如果没有地址，不执行查询
  if (!address.value) return;
  
  try {
    // 发送 GET 请求获取统计信息
    const response = await axios.get(`/api/stats/${address.value}`);
    // 如果请求成功
    if (response.data.success) {
      // 保存统计信息
      stats.value = response.data.data;
    }
  } catch (error) {
    // 捕获错误
    console.error('获取统计信息失败:', error);
  }
}

// 监听筛选条件变化
// 当筛选类型、页码或每页数量变化时，重新获取数据
watch([filterType, currentPage, pageSize], () => {
  fetchTransfers();
});

// 监听地址变化
// 当查询的地址变化时，重新获取数据和统计
watch(address, () => {
  currentPage.value = 1;  // 重置到第一页
  fetchTransfers();   // 获取转账记录
  fetchStats();       // 获取统计信息
});

// 组件挂载时执行
onMounted(() => {
  fetchTransfers();  // 获取转账记录
  fetchStats();       // 获取统计信息
});

// 分页处理：每页数量变化
function handleSizeChange(val) {
  pageSize.value = val;
  currentPage.value = 1;  // 重置到第一页
}

// 分页处理：当前页变化
function handleCurrentChange(val) {
  currentPage.value = val;
}

// 工具函数：缩短地址显示（只显示前 6 位和后 4 位）
function shortenAddress(addr) {
  if (!addr) return '';
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

// 工具函数：缩短交易哈希显示
function shortenHash(hash) {
  if (!hash) return '';
  return `${hash.slice(0, 10)}...${hash.slice(-8)}`;
}

// 工具函数：格式化金额（将 wei 值转换为可读格式）
function formatAmount(amount) {
  if (!amount) return '0';
  try {
    // 将 wei 值转换为可读格式（假设代币有18位小数）
    const amountInEther = ethers.formatEther(amount.toString());
    const num = parseFloat(amountInEther);
    // 格式化为本地化字符串，最多保留 4 位小数
    return num.toLocaleString('zh-CN', { maximumFractionDigits: 4 });
  } catch (error) {
    console.error('格式化金额失败:', error);
    return amount.toString();
  }
}

// 工具函数：格式化时间戳为可读时间
function formatTime(timestamp) {
  if (!timestamp) return '-';
  const date = new Date(timestamp * 1000);  // 将 Unix 时间戳转换为 Date 对象
  return date.toLocaleString('zh-CN');  // 格式化为本地化时间字符串
}
</script>

<style scoped>
/* 转账记录页面样式 */
.transfers {
  padding: 20px 0;  /* 上下内边距 */
}

/* 卡片头部样式 */
.card-header {
  display: flex;  /* 使用 Flex 布局 */
  align-items: center;  /* 垂直居中对齐 */
  gap: 10px;  /* 元素之间的间距 */
  font-weight: bold;  /* 字体加粗 */
}

/* 统计卡片样式 */
.stats-card {
  height: fit-content;  /* 高度自适应内容 */
}

/* 地址信息样式 */
.address-info {
  text-align: center;  /* 文本居中对齐 */
}

.address-info .label {
  color: #909399;  /* 字体颜色：灰色 */
  font-size: 14px;  /* 字体大小 */
  margin-bottom: 5px;  /* 底部外边距 */
}

.address-info .address {
  font-weight: bold;  /* 字体加粗 */
  color: #303133;  /* 字体颜色 */
  word-break: break-all;  /* 允许在任意字符处换行 */
}

/* 统计数据样式 */
.stats {
  padding: 10px 0;  /* 上下内边距 */
}

.stat-item {
  text-align: center;  /* 文本居中对齐 */
  padding: 10px 0;  /* 上下内边距 */
}

.stat-label {
  color: #909399;  /* 字体颜色：灰色 */
  font-size: 14px;  /* 字体大小 */
}

.stat-value {
  font-size: 32px;  /* 字体大小 */
  font-weight: bold;  /* 字体加粗 */
  margin: 10px 0;  /* 上下外边距 */
}

.stat-value.sent {
  color: #f56c6c;  /* 转出数字颜色：红色 */
}

.stat-value.received {
  color: #67c23a;  /* 转入数字颜色：绿色 */
}

.stat-amount {
  color: #606266;  /* 字体颜色 */
  font-size: 14px;  /* 字体大小 */
}

/* 高亮样式：用于高亮当前查询的地址 */
.highlight {
  font-weight: bold;  /* 字体加粗 */
  color: #409eff;  /* 字体颜色：蓝色 */
}

/* 转出金额样式 */
.amount-sent {
  color: #f56c6c;  /* 字体颜色：红色 */
  font-weight: bold;  /* 字体加粗 */
}

/* 转入金额样式 */
.amount-received {
  color: #67c23a;  /* 字体颜色：绿色 */
  font-weight: bold;  /* 字体加粗 */
}

/* 分页样式 */
.pagination {
  margin-top: 20px;  /* 顶部外边距 */
  display: flex;  /* 使用 Flex 布局 */
  justify-content: center;  /* 水平居中对齐 */
}
</style>
