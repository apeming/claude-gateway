#!/usr/bin/env python3
"""
Claude Gateway 路由管理CLI工具
用于管理动态路由配置的命令行工具
"""

import argparse
import json
import os
import sys
import platform
import requests
from pathlib import Path
from typing import List, Optional, Dict
from urllib.parse import urljoin


def get_config_dir() -> Path:
    """获取用户配置目录"""
    system = platform.system()
    home = Path.home()

    if system == "Darwin":  # macOS
        config_dir = home / "Library" / "Application Support" / "claude-gateway"
    elif system == "Windows":
        config_dir = Path(os.environ.get("APPDATA", home / "AppData" / "Roaming")) / "claude-gateway"
    else:  # Linux and other Unix-like systems
        config_dir = home / ".config" / "claude-gateway"

    # 确保目录存在
    config_dir.mkdir(parents=True, exist_ok=True)
    return config_dir


class RoutesManager:
    """路由管理器"""

    def __init__(self, config_file: Optional[str] = None):
        if config_file:
            self.config_file = config_file
        else:
            config_dir = get_config_dir()
            self.config_file = str(config_dir / "config.json")

        self.config = self.load_config()

    def load_config(self) -> dict:
        """加载配置文件"""
        default_config = {
            "api_base_url": "http://localhost",
            "api_token": "default-secret-token-please-change-me"
        }

        if os.path.exists(self.config_file):
            try:
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    config = json.load(f)
                    # 合并默认配置
                    default_config.update(config)
                    return default_config
            except Exception as e:
                print(f"❌ 读取配置文件失败: {e}")
                print(f"📄 使用默认配置并创建新文件")
                self._create_default_config(default_config)
                return default_config
        else:
            # 配置文件不存在，创建默认配置
            self._create_default_config(default_config)
            return default_config

    def _create_default_config(self, config: dict):
        """创建默认配置文件"""
        try:
            # 确保目录存在
            os.makedirs(os.path.dirname(self.config_file), exist_ok=True)
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(config, f, indent=2, ensure_ascii=False)
            print(f"✅ 已创建配置文件: {self.config_file}")
        except Exception as e:
            print(f"❌ 创建配置文件失败: {e}")

    def save_config(self):
        """保存配置文件"""
        try:
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, indent=2, ensure_ascii=False)
            print(f"✅ 配置已保存到 {self.config_file}")
        except Exception as e:
            print(f"❌ 保存配置失败: {e}")

    def _get_headers(self) -> dict:
        """获取请求头"""
        return {
            "X-API-Key": self.config["api_token"],
            "Content-Type": "application/json"
        }

    def _make_request(self, method: str, endpoint: str, **kwargs) -> Optional[requests.Response]:
        """发送HTTP请求"""
        url = urljoin(self.config["api_base_url"], endpoint)
        headers = self._get_headers()

        try:
            response = requests.request(method, url, headers=headers, timeout=10, **kwargs)
            return response
        except requests.exceptions.RequestException as e:
            print(f"❌ 请求失败: {e}")
            return None

    def add_route(self, token: str, url: str) -> bool:
        """添加路由"""
        data = {
            "token": token,
            "url": url
        }
        response = self._make_request("POST", "/route/add", json=data)

        if response is None:
            return False

        if response.status_code == 200:
            try:
                result = response.json()
                if result.get("success"):
                    print(f"✅ 路由 '{token}' -> '{url}' 添加成功")
                    return True
                else:
                    print(f"❌ 添加失败: {result.get('message', 'Unknown error')}")
                    return False
            except json.JSONDecodeError:
                print(f"✅ 路由添加成功（响应格式异常）")
                return True
        elif response.status_code == 401:
            print("❌ API Token 无效，请检查配置")
            return False
        else:
            print(f"❌ 添加失败: {response.text}")
            return False

    def delete_route(self, token: str) -> bool:
        """删除路由"""
        data = {
            "token": token
        }
        response = self._make_request("POST", "/route/del", json=data)

        if response is None:
            return False

        if response.status_code == 200:
            try:
                result = response.json()
                if result.get("success"):
                    print(f"✅ 路由 '{token}' 删除成功")
                    return True
                else:
                    print(f"❌ 删除失败: {result.get('message', 'Unknown error')}")
                    return False
            except json.JSONDecodeError:
                print(f"✅ 路由删除成功（响应格式异常）")
                return True
        elif response.status_code == 401:
            print("❌ API Token 无效，请检查配置")
            return False
        else:
            print(f"❌ 删除失败: {response.text}")
            return False

    def update_route(self, token: str, url: str) -> bool:
        """更新路由"""
        data = {
            "token": token,
            "url": url
        }
        response = self._make_request("POST", "/route/update", json=data)

        if response is None:
            return False

        if response.status_code == 200:
            try:
                result = response.json()
                if result.get("success"):
                    print(f"✅ 路由 '{token}' 更新为 '{url}'")
                    return True
                else:
                    print(f"❌ 更新失败: {result.get('message', 'Unknown error')}")
                    return False
            except json.JSONDecodeError:
                print(f"✅ 路由更新成功（响应格式异常）")
                return True
        elif response.status_code == 401:
            print("❌ API Token 无效，请检查配置")
            return False
        else:
            print(f"❌ 更新失败: {response.text}")
            return False

    def list_routes(self) -> List[Dict[str, str]]:
        """列出所有路由"""
        response = self._make_request("GET", "/route/list")

        if response is None:
            return []

        if response.status_code == 200:
            try:
                result = response.json()
                routes = result.get("routes", [])
                return routes
            except json.JSONDecodeError:
                print(f"❌ 解析响应失败: {response.text}")
                return []
        elif response.status_code == 401:
            print("❌ API Token 无效，请检查配置")
            return []
        else:
            print(f"❌ 获取路由列表失败: {response.text}")
            return []

    def reload_routes(self) -> bool:
        """重新加载路由配置"""
        response = self._make_request("POST", "/route/reload")

        if response is None:
            return False

        if response.status_code == 200:
            try:
                result = response.json()
                if result.get("success"):
                    loaded = result.get("loaded", 0)
                    errors = result.get("errors", 0)
                    print(f"✅ 路由配置重新加载成功")
                    print(f"📊 加载: {loaded} 个, 错误: {errors} 个")
                    return True
                else:
                    print(f"❌ 重新加载失败: {result.get('message', 'Unknown error')}")
                    return False
            except json.JSONDecodeError:
                print(f"✅ 路由配置重新加载成功（响应格式异常）")
                return True
        elif response.status_code == 401:
            print("❌ API Token 无效，请检查配置")
            return False
        else:
            print(f"❌ 重新加载失败: {response.text}")
            return False

    def check_status(self) -> bool:
        """检查服务状态"""
        response = self._make_request("GET", "/health")

        if response is None:
            return False

        if response.status_code == 200:
            try:
                health_data = response.json()
                print("✅ 服务状态正常")
                print(f"📊 服务信息:")
                print(f"   状态: {health_data.get('status', 'unknown')}")
                print(f"   服务: {health_data.get('service', 'unknown')}")
                print(f"   动态路由: {health_data.get('routing_enabled', 'unknown')}")
                print(f"   路由数量: {health_data.get('routes_loaded', 0)}")
                print(f"   认证配置: {health_data.get('auth_configured', 'unknown')}")
                return True
            except json.JSONDecodeError:
                print("✅ 服务运行中（响应格式异常）")
                return True
        else:
            print(f"❌ 服务异常: HTTP {response.status_code}")
            return False

    def import_from_file(self, filename: str) -> bool:
        """从文件导入路由"""
        if not os.path.exists(filename):
            print(f"❌ 文件不存在: {filename}")
            return False

        try:
            with open(filename, 'r', encoding='utf-8') as f:
                lines = [line.strip() for line in f.readlines()]
                # 过滤空行和注释
                lines = [line for line in lines if line and not line.startswith('#')]

            if not lines:
                print("⚠️  文件中没有找到有效的路由")
                return False

            routes = []
            for i, line in enumerate(lines, 1):
                parts = line.split()
                if len(parts) != 2:
                    print(f"⚠️  第 {i} 行格式错误，跳过: {line}")
                    continue
                token, url = parts
                routes.append((token, url))

            if not routes:
                print("⚠️  文件中没有找到有效的路由")
                return False

            success_count = 0
            fail_count = 0

            print(f"📥 开始导入 {len(routes)} 个路由...")

            for token, url in routes:
                if self.add_route(token, url):
                    success_count += 1
                else:
                    fail_count += 1

            print(f"\n📊 导入完成: 成功 {success_count}, 失败 {fail_count}")
            return fail_count == 0

        except Exception as e:
            print(f"❌ 读取文件失败: {e}")
            return False

    def export_to_file(self, filename: str) -> bool:
        """导出路由到文件"""
        routes = self.list_routes()

        if not routes:
            print("⚠️  没有路由可导出")
            return False

        try:
            with open(filename, 'w', encoding='utf-8') as f:
                f.write("# 路由配置列表\n")
                f.write("# 格式: <token> <upstream_url>\n")
                f.write("# 每行一个路由\n\n")

                for route in routes:
                    token = route.get("token", "")
                    url = route.get("url", "")
                    if token and url:
                        f.write(f"{token} {url}\n")

            print(f"✅ 已导出 {len(routes)} 个路由到 {filename}")
            return True

        except Exception as e:
            print(f"❌ 写入文件失败: {e}")
            return False


def main():
    """主函数"""
    parser = argparse.ArgumentParser(
        description="Claude Gateway 路由管理工具",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  %(prog)s add cr_1 http://backend1.example.com/api    # 添加路由
  %(prog)s del cr_1                                     # 删除路由
  %(prog)s update cr_1 http://new-backend.com/api      # 更新路由
  %(prog)s list                                         # 列出所有路由
  %(prog)s import routes.txt                            # 从文件导入
  %(prog)s export backup.txt                            # 导出到文件
  %(prog)s reload                                       # 重新加载配置文件
  %(prog)s config                                       # 配置API设置
  %(prog)s status                                       # 检查服务状态
        """
    )

    subparsers = parser.add_subparsers(dest='command', help='可用命令')

    # add 命令
    add_parser = subparsers.add_parser('add', help='添加路由')
    add_parser.add_argument('token', help='授权 token')
    add_parser.add_argument('url', help='上游服务 URL')

    # del 命令
    del_parser = subparsers.add_parser('del', help='删除路由')
    del_parser.add_argument('token', help='要删除的 token')

    # update 命令
    update_parser = subparsers.add_parser('update', help='更新路由')
    update_parser.add_argument('token', help='要更新的 token')
    update_parser.add_argument('url', help='新的上游服务 URL')

    # list 命令
    subparsers.add_parser('list', help='列出所有路由')

    # import 命令
    import_parser = subparsers.add_parser('import', help='从文件导入路由')
    import_parser.add_argument('file', help='包含路由配置的文件路径')

    # export 命令
    export_parser = subparsers.add_parser('export', help='导出路由到文件')
    export_parser.add_argument('file', help='导出文件路径')

    # reload 命令
    subparsers.add_parser('reload', help='重新加载路由配置文件')

    # config 命令
    subparsers.add_parser('config', help='配置API设置')

    # status 命令
    subparsers.add_parser('status', help='检查服务状态')

    # 解析参数
    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return

    # 创建管理器实例
    manager = RoutesManager()

    # 执行命令
    if args.command == 'add':
        manager.add_route(args.token, args.url)

    elif args.command == 'del':
        manager.delete_route(args.token)

    elif args.command == 'update':
        manager.update_route(args.token, args.url)

    elif args.command == 'list':
        routes = manager.list_routes()
        if routes:
            print(f"📋 共 {len(routes)} 个路由:")
            for i, route in enumerate(routes, 1):
                token = route.get("token", "")
                url = route.get("url", "")
                print(f"  {i:2d}. {token:20s} -> {url}")
        else:
            print("📋 暂无路由配置")

    elif args.command == 'import':
        manager.import_from_file(args.file)

    elif args.command == 'export':
        manager.export_to_file(args.file)

    elif args.command == 'reload':
        manager.reload_routes()

    elif args.command == 'config':
        print("🔧 配置API设置")
        print(f"配置文件位置: {manager.config_file}")
        print(f"当前配置:")
        print(f"  API地址: {manager.config['api_base_url']}")
        print(f"  API Token: {manager.config['api_token'][:10]}...")

        print("\n请输入新的配置 (直接回车保持不变):")

        new_url = input(f"API地址 [{manager.config['api_base_url']}]: ").strip()
        if new_url:
            manager.config['api_base_url'] = new_url

        new_token = input(f"API Token [{manager.config['api_token'][:10]}...]: ").strip()
        if new_token:
            manager.config['api_token'] = new_token

        manager.save_config()

    elif args.command == 'status':
        manager.check_status()


if __name__ == '__main__':
    main()
