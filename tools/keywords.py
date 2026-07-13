#!/usr/bin/env python3
"""
Claude Gateway 关键字管理CLI工具
用于管理关键字过滤列表的命令行工具
"""

import argparse
import json
import os
import sys
import platform
import requests
from pathlib import Path
from typing import Dict, Optional
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


class KeywordsManager:
    """关键字管理器"""

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

    def _handle_auth_error(self, response: requests.Response) -> bool:
        if response.status_code == 401:
            print("❌ API Token 无效，请检查配置")
            return True
        return False

    def add_keyword(self, keyword: str) -> bool:
        """添加关键字"""
        response = self._make_request("POST", "/keywords", json={"keyword": keyword})

        if response is None:
            return False

        if response.status_code == 200:
            print(f"✅ 关键字 '{keyword}' 添加成功")
            return True
        elif self._handle_auth_error(response):
            return False
        else:
            print(f"❌ 添加失败: {response.text}")
            return False

    def delete_keyword(self, keyword: str) -> bool:
        """删除关键字"""
        response = self._make_request("DELETE", "/keywords", json={"keyword": keyword})

        if response is None:
            return False

        if response.status_code == 200:
            print(f"✅ 关键字 '{keyword}' 删除成功")
            return True
        elif self._handle_auth_error(response):
            return False
        else:
            print(f"❌ 删除失败: {response.text}")
            return False

    def get_keyword_metadata(self) -> Optional[Dict[str, object]]:
        """获取关键字元数据"""
        response = self._make_request("GET", "/keywords")

        if response is None:
            return None

        if response.status_code == 200:
            try:
                payload = response.json()
            except json.JSONDecodeError:
                print(f"❌ 解析响应失败: {response.text}")
                return None

            if not isinstance(payload, dict):
                print(f"❌ 响应格式异常: {payload}")
                return None

            return payload
        elif self._handle_auth_error(response):
            return None
        else:
            print(f"❌ 获取关键字元数据失败: {response.text}")
            return None

    def show_keyword_metadata(self) -> bool:
        """显示关键字元数据"""
        metadata = self.get_keyword_metadata()
        if metadata is None:
            return False

        print("📋 关键字元数据:")
        print(f"   数量: {metadata.get('keywords_loaded', 0)}")
        print(f"   版本: {metadata.get('keyword_version', 'unknown')}")
        print(f"   状态: {metadata.get('keywords_status', 'unknown')}")
        print(f"   最近加载: {metadata.get('keywords_last_loaded_at', '') or 'N/A'}")
        load_error = metadata.get('keywords_load_error', '') or '无'
        print(f"   加载错误: {load_error}")
        return True

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
                print(f"   关键字数量: {health_data.get('keywords_loaded', 0)}")
                print(f"   关键字版本: {health_data.get('keyword_version', 'unknown')}")
                print(f"   关键字状态: {health_data.get('keywords_status', 'unknown')}")
                print(f"   最近加载: {health_data.get('keywords_last_loaded_at', '') or 'N/A'}")
                load_error = health_data.get('keywords_load_error', '') or '无'
                print(f"   加载错误: {load_error}")
                print(f"   认证配置: {health_data.get('auth_configured', 'unknown')}")
                print(f"   上游地址: {health_data.get('upstream_url', 'unknown')}")
                return True
            except json.JSONDecodeError:
                print("✅ 服务运行中（响应格式异常）")
                return True
        else:
            print(f"❌ 服务异常: HTTP {response.status_code}")
            return False


def main():
    """主函数"""
    parser = argparse.ArgumentParser(
        description="Claude Gateway 关键字管理工具",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  %(prog)s add sensitive-word          # 添加关键字
  %(prog)s del sensitive-word          # 删除关键字
  %(prog)s list                        # 查看关键字元数据
  %(prog)s config                      # 配置API设置
  %(prog)s status                      # 检查服务状态
        """
    )

    subparsers = parser.add_subparsers(dest='command', help='可用命令')

    # add 命令
    add_parser = subparsers.add_parser('add', help='添加关键字')
    add_parser.add_argument('keyword', help='要添加的关键字')

    # del 命令
    del_parser = subparsers.add_parser('del', help='删除关键字')
    del_parser.add_argument('keyword', help='要删除的关键字')

    # list 命令
    subparsers.add_parser('list', help='查看关键字元数据')

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
    manager = KeywordsManager()

    # 执行命令
    if args.command == 'add':
        manager.add_keyword(args.keyword)

    elif args.command == 'del':
        manager.delete_keyword(args.keyword)

    elif args.command == 'list':
        manager.show_keyword_metadata()

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
