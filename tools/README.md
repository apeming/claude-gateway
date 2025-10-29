# 关键字管理CLI工具

Claude Gateway 关键字管理命令行工具，用于管理关键字过滤列表。

## 🚀 快速开始

### 1. 安装依赖

```bash
# 确保已安装Python 3
python3 --version

# 安装依赖包
pip3 install -r requirements.txt
```

### 2. 配置工具

```bash
# 首次运行会自动创建配置文件
./keywords config
```

配置文件位置（自动创建）：
- **Linux**: `~/.config/claude-gateway/config.json`
- **macOS**: `~/Library/Application Support/claude-gateway/config.json`
- **Windows**: `%APPDATA%/claude-gateway/config.json`

配置文件示例：
```json
{
  "api_base_url": "http://localhost",
  "api_token": "your-api-token-here"
}
```

### 3. 检查服务状态

```bash
./keywords status
```

## 📋 命令参考

### 基本操作

#### 添加关键字
```bash
./keywords add "sensitive-word"
./keywords add "bad-content"
```

#### 删除关键字
```bash
./keywords del "sensitive-word"
```

#### 列出所有关键字
```bash
./keywords list
```

### 批量操作

#### 从文件导入关键字
```bash
# 使用示例文件
./keywords import sample-keywords.txt

# 使用自定义文件
./keywords import /path/to/your/keywords.txt
```

关键字文件格式：
```
# 这是注释行，会被忽略
sensitive-word
bad-content
spam
# 另一个注释
malware
```

#### 导出关键字到文件
```bash
# 导出所有关键字
./keywords export backup.txt

# 导出到指定路径
./keywords export /backup/keywords-$(date +%Y%m%d).txt
```

### 配置管理

#### 查看和修改配置
```bash
./keywords config
```

#### 检查服务状态
```bash
./keywords status
```

## 🛠️ 高级用法

### 脚本集成

CLI工具支持脚本自动化，所有命令都有合适的退出码：

```bash
#!/bin/bash

# 检查服务状态
if ./keywords status > /dev/null 2>&1; then
    echo "服务运行正常"
else
    echo "服务异常，退出脚本"
    exit 1
fi

# 批量添加关键字
for word in "spam" "malware" "phishing"; do
    ./keywords add "$word"
done

# 导出备份
./keywords export "backup-$(date +%Y%m%d-%H%M%S).txt"
```

### 批量管理示例

```bash
# 1. 导出现有关键字作为备份
./keywords export backup-before-update.txt

# 2. 导入新的关键字列表
./keywords import new-keywords.txt

# 3. 检查导入结果
./keywords list

# 4. 如果有问题，可以从备份恢复
# 首先清空现有关键字（需要手动删除）
# 然后重新导入备份
./keywords import backup-before-update.txt
```

## 📁 文件结构

```
tools/
├── keywords                    # 主执行脚本
├── keywords.py                 # Python CLI实现
├── requirements.txt            # 依赖包列表
├── sample-keywords.txt         # 示例关键字文件
├── install.sh                  # 安装脚本
└── README.md                   # 本文档

用户数据目录（自动创建）：
├── ~/.config/claude-gateway/   # Linux配置目录
│   └── config.json             # 实际配置文件
├── ~/Library/Application Support/claude-gateway/  # macOS配置目录
│   └── config.json
└── %APPDATA%/claude-gateway/   # Windows配置目录
    └── config.json
```

## 🐛 常见问题

### 1. API Token 认证失败
```
❌ API Token 无效，请检查配置
```

**解决方法：**
- 运行 `./keywords config` 重新配置API Token
- 确保Token与服务端配置的 `API_TOKEN` 环境变量一致
- 配置文件位置：
  - Linux: `~/.config/claude-gateway/config.json`
  - macOS: `~/Library/Application Support/claude-gateway/config.json`
  - Windows: `%APPDATA%/claude-gateway/config.json`

### 2. 配置文件权限问题
```
❌ 配置文件无法写入
```

**解决方法：**
```bash
# 检查配置目录权限
ls -la ~/.config/claude-gateway/

# 修复权限（Linux/macOS）
chmod 755 ~/.config/claude-gateway/
chmod 644 ~/.config/claude-gateway/config.json
```

### 3. 连接服务失败
```
❌ 请求失败: Connection refused
```

**解决方法：**
- 检查服务是否运行：`docker compose ps`
- 检查API地址配置是否正确
- 确保防火墙设置允许连接

### 4. Python依赖包缺失
```
❌ 错误: 未找到 python3，请先安装Python 3
```

**解决方法：**
```bash
# Ubuntu/Debian
sudo apt install python3 python3-pip

# CentOS/RHEL
sudo yum install python3 python3-pip

# macOS
brew install python3
```

### 5. 权限问题
```
./keywords: Permission denied
```

**解决方法：**
```bash
chmod +x keywords
```

## 🔧 开发说明

### 扩展功能

如需添加新功能，可以修改 `keywords.py`：

1. 在 `KeywordsManager` 类中添加新方法
2. 在 `main()` 函数中添加新的子命令解析
3. 更新帮助文档

### API接口

工具调用的API接口：
- `GET /keyword/add?kw=<keyword>` - 添加关键字
- `GET /keyword/del?kw=<keyword>` - 删除关键字
- `GET /keyword/list` - 列出关键字
- `GET /health` - 服务状态

## 📝 更新日志

### v1.0.0
- ✅ 基本的CRUD操作（添加、删除、列表）
- ✅ 批量导入导出功能
- ✅ 配置文件管理
- ✅ 服务状态检查
- ✅ 脚本友好的命令行界面

## 📄 许可证

本工具遵循与主项目相同的许可证。