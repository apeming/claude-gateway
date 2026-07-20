#!/usr/bin/env python3
import argparse
import sys
from keywords import KeywordsManager


class RegexRulesManager(KeywordsManager):
    def request(self, method, path, payload=None):
        response = self._make_request(method, path, json=payload)
        if response is None:
            return 0, "Request failed"
        return response.status_code, response.text


def main():
    parser = argparse.ArgumentParser(description="Manage anchored regex rules")
    commands = parser.add_subparsers(dest="command", required=True)
    add = commands.add_parser("add")
    add.add_argument("id")
    add.add_argument("anchor")
    add.add_argument("expression")
    delete = commands.add_parser("del")
    delete.add_argument("id")
    commands.add_parser("list")
    commands.add_parser("status")
    args = parser.parse_args()
    manager = RegexRulesManager()
    if args.command == "add":
        status, body = manager.request("POST", "/regex-rules", {"id": args.id, "anchor": args.anchor, "expression": args.expression})
    elif args.command == "del":
        status, body = manager.request("DELETE", "/regex-rules", {"id": args.id})
    else:
        status, body = manager.request("GET", "/regex-rules")
    if status < 200 or status >= 300:
        print(body, file=sys.stderr)
        return 1
    print(body)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
