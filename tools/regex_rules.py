#!/usr/bin/env python3
"""Claude Gateway 锚点正则规则管理工具。"""

import argparse
from typing import Optional

from keywords import KeywordsManager


class RegexRulesManager(KeywordsManager):
    def _request_rules(self, method: str, payload: Optional[dict] = None):
        return self._make_request(method, "/regex-rules", json=payload)

    def add_rule(self, rule_id: str, anchor: str, expression: str) -> bool:
        response = self._request_rules("POST", {
            "id": rule_id,
            "anchor": anchor,
            "expression": expression,
        })
        if response is None:
            return False
        if response.status_code == 200:
            print(f"✅ 正则规则 '{rule_id}' 添加成功")
            return True
        if self._handle_auth_error(response):
            return False
        print(f"❌ 添加失败: {response.text}")
        return False

    def delete_rule(self, rule_id: str) -> bool:
        response = self._request_rules("DELETE", {"id": rule_id})
        if response is None:
            return False
        if response.status_code == 200:
            print(f"✅ 正则规则 '{rule_id}' 删除成功")
            return True
        if self._handle_auth_error(response):
            return False
        print(f"❌ 删除失败: {response.text}")
        return False

    def get_metadata(self) -> Optional[dict]:
        response = self._request_rules("GET")
        if response is None:
            return None
        if response.status_code == 200:
            try:
                payload = response.json()
            except ValueError:
                print(f"❌ 解析响应失败: {response.text}")
                return None
            return payload if isinstance(payload, dict) else None
        if not self._handle_auth_error(response):
            print(f"❌ 获取正则规则元数据失败: {response.text}")
        return None

    def show_metadata(self) -> bool:
        metadata = self.get_metadata()
        if metadata is None:
            return False
        print("📋 正则规则元数据:")
        print(f"   数量: {metadata.get('regex_rules_loaded', 0)}")
        print(f"   版本: {metadata.get('regex_rules_version', 'unknown')}")
        print(f"   状态: {metadata.get('regex_rules_status', 'unknown')}")
        print(f"   最近加载: {metadata.get('regex_rules_last_loaded_at', '') or 'N/A'}")
        print(f"   组合表达式大小: {metadata.get('regex_pattern_bytes', 0)} bytes")
        print(f"   加载错误: {metadata.get('regex_rules_load_error', '') or '无'}")
        return True

    def check_status(self) -> bool:
        response = self._make_request("GET", "/health")
        if response is None:
            return False
        if response.status_code != 200:
            print(f"❌ 服务异常: HTTP {response.status_code}")
            return False
        try:
            health = response.json()
        except ValueError:
            print("✅ 服务运行中（响应格式异常）")
            return True
        print("✅ 服务状态正常")
        print("📊 正则规则状态:")
        print(f"   数量: {health.get('regex_rules_loaded', 0)}")
        print(f"   版本: {health.get('regex_rules_version', 'unknown')}")
        print(f"   状态: {health.get('regex_rules_status', 'unknown')}")
        print(f"   最近加载: {health.get('regex_rules_last_loaded_at', '') or 'N/A'}")
        print(f"   组合表达式大小: {health.get('regex_pattern_bytes', 0)} bytes")
        print(f"   加载错误: {health.get('regex_rules_load_error', '') or '无'}")
        return True


def configure(manager: RegexRulesManager) -> None:
    print("🔧 配置API设置")
    print(f"配置文件位置: {manager.config_file}")
    print("\n请输入新的配置 (直接回车保持不变):")
    url = input(f"API地址 [{manager.config['api_base_url']}]: ").strip()
    token = input(f"API Token [{manager.config['api_token'][:10]}...]: ").strip()
    if url:
        manager.config['api_base_url'] = url
    if token:
        manager.config['api_token'] = token
    manager.save_config()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Claude Gateway 锚点正则规则管理工具",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  %(prog)s add contract-price 服务总价 '{{anchor}}[[:space:]]*[:：][[:space:]]*[￥¥][0-9]+'
  %(prog)s del contract-price
  %(prog)s list
  %(prog)s config
  %(prog)s status
        """,
    )
    commands = parser.add_subparsers(dest="command", help="可用命令")
    add = commands.add_parser("add", help="添加正则规则")
    add.add_argument("id", help="规则唯一标识")
    add.add_argument("anchor", help="触发正则检查的固定字符串")
    add.add_argument("expression", help="包含 {{anchor}} 的正则表达式")
    delete = commands.add_parser("del", help="删除正则规则")
    delete.add_argument("id", help="要删除的规则标识")
    commands.add_parser("list", help="查看正则规则元数据")
    commands.add_parser("config", help="配置API设置")
    commands.add_parser("status", help="检查正则规则状态")
    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        return
    manager = RegexRulesManager()
    if args.command == "add":
        manager.add_rule(args.id, args.anchor, args.expression)
    elif args.command == "del":
        manager.delete_rule(args.id)
    elif args.command == "list":
        manager.show_metadata()
    elif args.command == "config":
        configure(manager)
    else:
        manager.check_status()


if __name__ == "__main__":
    main()
