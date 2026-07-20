#!/usr/bin/env python3
import argparse
import json
import os
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def request(method, path, payload=None):
    base = os.environ.get("GATEWAY_URL", "http://127.0.0.1:18888").rstrip("/")
    token = os.environ.get("API_TOKEN", "default-secret-token-please-change-me")
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8") if payload else None
    req = Request(base + path, data=data, method=method, headers={"X-API-Key": token, "Content-Type": "application/json"})
    try:
        with urlopen(req) as response:
            return response.status, response.read().decode("utf-8")
    except HTTPError as error:
        return error.code, error.read().decode("utf-8")
    except URLError as error:
        return 0, str(error)


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
    if args.command == "add":
        status, body = request("POST", "/regex-rules", {"id": args.id, "anchor": args.anchor, "expression": args.expression})
    elif args.command == "del":
        status, body = request("DELETE", "/regex-rules", {"id": args.id})
    else:
        status, body = request("GET", "/regex-rules")
    if status < 200 or status >= 300:
        print(body, file=sys.stderr)
        return 1
    print(body)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
