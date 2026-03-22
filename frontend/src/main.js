// 导入 Vue 的 createApp 函数：用于创建 Vue 应用实例
import { createApp } from 'vue';
// 导入根组件 App.vue：应用的主组件
import App from './App.vue';
// 导入路由配置：用于管理页面导航
import router from './router';
// 导入 Element Plus UI 组件库：提供丰富的 UI 组件
import ElementPlus from 'element-plus';
// 导入 Element Plus 的样式文件
import 'element-plus/dist/index.css';
// 导入 Element Plus 的所有图标组件
import * as ElementPlusIconsVue from '@element-plus/icons-vue';

// 创建 Vue 应用实例
const app = createApp(App);

// 注册所有图标组件
// 遍历 ElementPlusIconsVue 中的所有图标，并注册到应用中
// 这样就可以在任何组件中使用 <el-icon><Coin /></el-icon> 这样的语法
for (const [key, component] of Object.entries(ElementPlusIconsVue)) {
  app.component(key, component);
}

// 使用路由插件：启用页面导航功能
app.use(router);
// 使用 Element Plus UI 组件库：启用所有 Element Plus 组件
app.use(ElementPlus);
// 将应用挂载到 DOM 中的 #app 元素上
app.mount('#app');
