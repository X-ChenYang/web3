// 导入 Vue Router 的创建函数：用于创建路由实例
import { createRouter, createWebHistory } from 'vue-router';
// 导入首页组件
import Home from '../views/Home.vue';
// 导入转账记录页面组件
import Transfers from '../views/Transfers.vue';

// 定义路由配置数组
// 每个路由对象包含路径、名称和对应的组件
const routes = [
  {
    path: '/',        // 路径：根路径
    name: 'Home',    // 路由名称
    component: Home   // 对应的组件：首页
  },
  {
    path: '/transfers',  // 路径：转账记录页面
    name: 'Transfers',  // 路由名称
    component: Transfers // 对应的组件：转账记录页面
  }
];

// 创建路由实例
// createWebHistory: 使用 HTML5 History 模式，URL 看起来更美观（如 /transfers 而不是 /#/transfers）
const router = createRouter({
  history: createWebHistory(),  // 使用 History 模式
  routes                       // 路由配置
});

// 导出路由实例，供 main.js 使用
export default router;
