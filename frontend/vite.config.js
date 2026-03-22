// 导入 Vite 的 defineConfig 函数：用于定义 Vite 配置
import { defineConfig } from 'vite';
// 导入 Vue 插件：用于支持 Vue 单文件组件（.vue 文件）
import vue from '@vitejs/plugin-vue';

// 导出 Vite 配置对象
export default defineConfig({
  plugins: [vue()],  // 插件配置：使用 Vue 插件
  server: {
    port: 5173,  // 开发服务器端口号：前端服务运行在 5173 端口
    proxy: {
      // 代理配置：将 /api 开头的请求代理到后端服务器
      // 这样前端就可以使用相对路径（如 /api/transfers/xxx）访问后端 API
      // 而不需要写完整的后端地址（如 http://localhost:3005/api/transfers/xxx）
      '/api': {
        target: 'http://localhost:3005',  // 代理目标：后端服务器地址
        changeOrigin: true  // 修改请求头中的 Origin 字段，避免跨域问题
      }
    }
  }
});
