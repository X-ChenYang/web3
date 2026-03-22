#!/bin/bash

# 启动整个 ERC20 项目（后端 + 前端）

echo "========================================="
echo "启动 ERC20 代币项目"
echo "========================================="
echo "时间: $(date)"
echo ""

# 进入项目根目录
cd /mnt/d/Trae_code/My_foundry/web3-erc20-project

echo "启动后端服务..."
cd backend

# 构建并启动后端
if [ -f "package.json" ]; then
    echo "构建后端..."
    npm run build 2>&1 | head -10
    
    echo "启动后端服务..."
    ./start-service.sh
    
    # 等待后端启动
    sleep 5
    
    echo "检查后端服务状态..."
    if curl -s http://localhost:3001/api/health > /dev/null 2>&1; then
        echo "✓ 后端服务启动成功"
    else
        echo "✗ 后端服务启动失败"
        echo "查看日志: cat server.log"
    fi
else
    echo "错误: 后端目录不存在 package.json"
fi

echo ""
echo "启动前端服务..."
cd ../frontend

if [ -f "package.json" ]; then
    echo "启动前端开发服务器..."
    nohup npm run dev > frontend.log 2>&1 &
    FRONTEND_PID=$!
    disown $FRONTEND_PID
    
    echo "前端服务 PID: $FRONTEND_PID"
    echo $FRONTEND_PID > frontend.pid
    
    # 等待前端启动
    sleep 3
    
    echo "检查前端服务状态..."
    if curl -s http://localhost:5173 > /dev/null 2>&1; then
        echo "✓ 前端服务启动成功"
    else
        echo "✗ 前端服务启动失败"
        echo "查看日志: cat frontend.log"
    fi
else
    echo "错误: 前端目录不存在 package.json"
fi

echo ""
echo "========================================="
echo "服务启动完成！"
echo "========================================="
echo "服务信息:"
echo "  - 后端服务: http://localhost:3001"
echo "  - 前端服务: http://localhost:5173"
echo "  - 后端 API: http://localhost:3001/api/health"
echo ""
echo "管理命令:"
echo "  - 查看后端日志: tail -f backend/server.log"
echo "  - 查看前端日志: tail -f frontend/frontend.log"
echo "  - 停止后端服务: kill $(cat backend/server.pid 2>/dev/null)"
echo "  - 停止前端服务: kill $(cat frontend/frontend.pid 2>/dev/null)"
echo ""
echo "========================================="
