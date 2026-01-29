#!/bin/bash
# 启动脚本

# 设置环境变量
export PYTHONPATH=/app/backend:$PYTHONPATH

# 启动FastAPI应用
cd /app/backend
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
