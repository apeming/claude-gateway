#!/bin/bash

# 关键字管理工具安装脚本

set -e

TOOL_NAME="keywords"
INSTALL_DIR="/usr/local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔧 关键字管理工具安装脚本"
echo ""

# 检查权限
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  检测到root权限，将安装到系统目录: $INSTALL_DIR"
    SYSTEM_INSTALL=true
else
    echo "📝 普通用户安装，将创建软链接到当前目录"
    SYSTEM_INSTALL=false
fi

# 检查Python
if ! command -v python3 &> /dev/null; then
    echo "❌ 错误: 未找到 python3"
    echo "请先安装Python 3:"
    echo "  Ubuntu/Debian: sudo apt install python3 python3-pip"
    echo "  CentOS/RHEL:   sudo yum install python3 python3-pip"
    echo "  macOS:         brew install python3"
    exit 1
fi

echo "✅ Python 3 已安装: $(python3 --version)"

# 安装Python依赖
echo "📦 安装Python依赖包..."
if pip3 install -r "$SCRIPT_DIR/requirements.txt" &> /dev/null; then
    echo "✅ 依赖包安装成功"
else
    echo "⚠️  依赖包安装失败，尝试使用用户目录安装..."
    if pip3 install --user -r "$SCRIPT_DIR/requirements.txt"; then
        echo "✅ 依赖包安装成功（用户目录）"
    else
        echo "❌ 依赖包安装失败"
        exit 1
    fi
fi

# 提示配置文件位置
echo "📄 配置文件将在首次运行时自动创建："
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "   macOS: ~/Library/Application Support/claude-gateway/config.json"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    echo "   Windows: %APPDATA%/claude-gateway/config.json"
else
    echo "   Linux: ~/.config/claude-gateway/config.json"
fi

# 确保脚本可执行
chmod +x "$SCRIPT_DIR/$TOOL_NAME"
chmod +x "$SCRIPT_DIR/keywords.py"

if [ "$SYSTEM_INSTALL" = true ]; then
    # 系统安装
    echo "📋 复制工具到系统目录..."
    cp "$SCRIPT_DIR/$TOOL_NAME" "$INSTALL_DIR/"
    echo "✅ 安装完成！"
    echo ""
    echo "🚀 使用方法:"
    echo "  $TOOL_NAME config    # 配置API设置"
    echo "  $TOOL_NAME status    # 检查服务状态"
    echo "  $TOOL_NAME list      # 列出关键字"
    echo "  $TOOL_NAME --help    # 查看所有命令"
else
    # 用户安装（创建软链接）
    LOCAL_BIN="$HOME/.local/bin"
    if [ -d "$LOCAL_BIN" ]; then
        echo "📋 创建软链接到 $LOCAL_BIN..."
        ln -sf "$SCRIPT_DIR/$TOOL_NAME" "$LOCAL_BIN/"
        echo "✅ 安装完成！"
        echo ""
        echo "🚀 使用方法:"
        echo "  $TOOL_NAME config    # 配置API设置"
        echo "  $TOOL_NAME status    # 检查服务状态"
        echo "  $TOOL_NAME list      # 列出关键字"
        echo "  $TOOL_NAME --help    # 查看所有命令"
        echo ""
        echo "📝 注意: 请确保 $LOCAL_BIN 在您的 PATH 中"
        echo "如果命令不可用，请将以下内容添加到 ~/.bashrc 或 ~/.zshrc:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    else
        echo "📋 直接在当前目录使用..."
        echo "✅ 安装完成！"
        echo ""
        echo "🚀 使用方法:"
        echo "  ./$TOOL_NAME config    # 配置API设置"
        echo "  ./$TOOL_NAME status    # 检查服务状态"
        echo "  ./$TOOL_NAME list      # 列出关键字"
        echo "  ./$TOOL_NAME --help    # 查看所有命令"
    fi
fi

echo ""
echo "📚 更多使用说明请查看: $SCRIPT_DIR/README.md"