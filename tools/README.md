# Claude Gateway 管理工具

Claude Gateway 命令行管理工具集，包括关键字过滤和动态路由管理。

## 📦 工具列表

- **keywords** - 关键字过滤管理工具
- **routes** - 动态路由配置管理工具

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
# 首次运行会自动创建配置文件（两个工具共享同一配置）
./keywords config
# 或
./routes config
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
# 或
./routes status
```

## 📋 命令参考

---

## 🔑 关键字管理工具 (keywords)

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
├── keywords                    # 关键字管理执行脚本
├── keywords.py                 # 关键字管理 Python 实现
├── routes                      # 路由管理执行脚本
├── routes.py                   # 路由管理 Python 实现
├── requirements.txt            # 依赖包列表
├── sample-keywords.txt         # 示例关键字文件
├── sample-routes.txt           # 示例路由配置文件
├── install.sh                  # 安装脚本
└── README.md                   # 本文档

用户数据目录（自动创建）：
├── ~/.config/claude-gateway/   # Linux配置目录
│   └── config.json             # 实际配置文件（两个工具共享）
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

关键字管理工具调用的API接口：
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

---

## 🔀 路由管理工具 (routes)

路由管理工具用于管理动态路由配置，支持基于 Authorization token 的请求路由。

### 基本操作

#### 添加路由
```bash
./routes add <token> <upstream_url>

# 示例
./routes add cr_1 http://backend1.example.com/api
./routes add cr_2 http://backend2.example.com/claude-api
```

#### 删除路由
```bash
./routes del <token>

# 示例
./routes del cr_1
```

#### 更新路由
```bash
./routes update <token> <new_upstream_url>

# 示例
./routes update cr_1 http://new-backend.example.com/api
```

#### 列出所有路由
```bash
./routes list
```

输出示例：
```
📋 共 3 个路由:
   1. cr_1                 -> http://backend1.example.com/api
   2. cr_2                 -> http://backend2.example.com/claude-api
   3. cr_3                 -> http://backend3.example.com
```

### 批量操作

#### 从文件导入路由
```bash
# 使用示例文件
./routes import sample-routes.txt

# 使用自定义文件
./routes import /path/to/your/routes.txt
```

路由配置文件格式：
```
# 这是注释行，会被忽略
# 格式: <token> <upstream_url>

cr_1 http://backend1.example.com/api
cr_2 http://backend2.example.com/claude-api
cr_3 http://backend3.example.com

# 每行一个路由，token 和 URL 之间用空格分隔
```

#### 导出路由到文件
```bash
# 导出所有路由
./routes export backup.txt

# 导出到指定路径
./routes export /backup/routes-$(date +%Y%m%d).txt
```

#### 重新加载配置文件
```bash
# 从服务器端的 routes.txt 文件重新加载路由配置
./routes reload
```

**使用场景：**
- 直接修改了服务器上的 `routes.txt` 文件
- 需要从文件恢复路由配置
- 批量更新路由后统一加载

### 配置管理

#### 查看和修改配置
```bash
./routes config
```

#### 检查服务状态
```bash
./routes status
```

输出示例：
```
✅ 服务状态正常
📊 服务信息:
   状态: healthy
   服务: claude-gateway
   动态路由: true
   路由数量: 3
   认证配置: true
```

### 高级用法

#### 脚本集成

```bash
#!/bin/bash

# 检查服务状态
if ./routes status > /dev/null 2>&1; then
    echo "服务运行正常"
else
    echo "服务异常，退出脚本"
    exit 1
fi

# 批量添加路由
./routes add tenant1_token http://tenant1.example.com/api
./routes add tenant2_token http://tenant2.example.com/api
./routes add tenant3_token http://tenant3.example.com/api

# 列出所有路由
./routes list

# 导出备份
./routes export "routes-backup-$(date +%Y%m%d-%H%M%S).txt"
```

#### 路由迁移示例

```bash
# 1. 从旧环境导出路由
./routes export routes-old-env.txt

# 2. 修改配置指向新环境
./routes config
# 输入新环境的 API 地址和 Token

# 3. 导入路由到新环境
./routes import routes-old-env.txt

# 4. 验证导入结果
./routes list
```

#### 批量更新示例

```bash
# 1. 导出当前配置作为备份
./routes export backup-before-update.txt

# 2. 准备新的路由配置文件
cat > new-routes.txt << 'EOF'
cr_1 http://new-backend1.example.com/api
cr_2 http://new-backend2.example.com/api
cr_3 http://new-backend3.example.com/api
EOF

# 3. 删除旧路由
./routes del cr_1
./routes del cr_2
./routes del cr_3

# 4. 导入新路由
./routes import new-routes.txt

# 5. 验证更新结果
./routes list
```

### API接口

路由管理工具调用的API接口：
- `POST /route/add` - 添加路由（JSON: `{"token": "...", "url": "..."}`）
- `POST /route/del` - 删除路由（JSON: `{"token": "..."}`）
- `POST /route/update` - 更新路由（JSON: `{"token": "...", "url": "..."}`）
- `GET /route/list` - 列出路由
- `POST /route/reload` - 重新加载配置文件
- `GET /health` - 服务状态

### 常见使用场景

#### 场景 1: 多租户管理
```bash
# 为每个租户创建独立的路由
./routes add tenant_a_token http://tenant-a-backend.com/api
./routes add tenant_b_token http://tenant-b-backend.com/api
./routes add tenant_c_token http://tenant-c-backend.com/api

# 查看所有租户路由
./routes list
```

#### 场景 2: 环境切换
```bash
# 将某个 token 从测试环境切换到生产环境
./routes update test_token http://prod-backend.example.com/api
```

#### 场景 3: 负载均衡调整
```bash
# 将部分流量迁移到新服务器
./routes add user_group_1 http://server1.example.com/api
./routes add user_group_2 http://server2.example.com/api
./routes add user_group_3 http://server2.example.com/api
```

#### 场景 4: 灰度发布
```bash
# 为特定用户组配置新版本后端
./routes add beta_users http://beta-backend.example.com/api
./routes add stable_users http://stable-backend.example.com/api
```

### 故障排查

#### 路由未生效
```bash
# 1. 检查路由是否已添加
./routes list

# 2. 检查服务是否启用动态路由
./routes status

# 3. 如果配置文件已修改，执行重新加载
./routes reload
```

#### 导入失败
```
❌ 第 5 行格式错误，跳过: invalid-line-content
```

**解决方法：**
- 确保文件格式正确：每行 `<token> <url>` 用空格分隔
- 检查是否有多余的字段
- 确保 URL 格式正确（包含协议，如 `http://` 或 `https://`）

### 更新日志

#### v1.0.0
- ✅ 基本的CRUD操作（添加、删除、更新、列表）
- ✅ 批量导入导出功能
- ✅ 配置文件重新加载
- ✅ 与关键字工具共享配置
- ✅ 服务状态检查
- ✅ 脚本友好的命令行界面