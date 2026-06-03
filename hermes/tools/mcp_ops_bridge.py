#!/usr/bin/env python3
"""
MCP server: ops (Variant B — no docker control, safe-only)

Tools:
  - disk_usage      df -h /
  - memory_usage    free -h
  - uptime          uptime
  - health_check    HTTP probe of stack endpoints
  - list_backups    ls /opt/hermes-backups

Protocol: MCP 2024-11-05 over stdio.
No shell injection, hard timeouts, allowlist of commands.
"""
import json
import os
import subprocess
import sys
import urllib.request
import urllib.error

SERVER_INFO = {
    "name": "hermes-ops",
    "version": "1.0.0",
}

BACKUP_DIR = os.environ.get("HERMES_BACKUP_DIR", "/opt/hermes-backups")

HEALTH_URLS = [
    ("hermes",            "http://127.0.0.1:8020"),
    ("open-notebook-ui",  "http://open-notebook:5055"),
    ("open-notebook-api", "http://open-notebook:5055/api/models/defaults"),
]


def run(cmd_list, timeout=10):
    try:
        proc = subprocess.run(
            cmd_list,
            capture_output=True,
            text=True,
            timeout=timeout,
            shell=False,
        )
        return {
            "exit_code": proc.returncode,
            "stdout": proc.stdout[-6000:],
            "stderr": proc.stderr[-1500:],
            "cmd": " ".join(cmd_list),
        }
    except subprocess.TimeoutExpired:
        return {"error": f"Timeout after {timeout}s", "cmd": " ".join(cmd_list)}
    except FileNotFoundError as e:
        return {"error": f"Command not found: {e}", "cmd": " ".join(cmd_list)}
    except Exception as e:
        return {"error": str(e), "cmd": " ".join(cmd_list)}


# ── Tool implementations ─────────────────────────────────────────────

def tool_disk_usage(_args):
    return run(["df", "-h", "/"])


def tool_memory_usage(_args):
    return run(["free", "-h"])


def tool_uptime(_args):
    return run(["uptime"])


def tool_health_check(_args):
    results = []
    for name, url in HEALTH_URLS:
        try:
            req = urllib.request.Request(url, method="GET")
            with urllib.request.urlopen(req, timeout=5) as r:
                results.append(f"{name:24s} {r.status}")
        except urllib.error.HTTPError as e:
            results.append(f"{name:24s} {e.code}")
        except Exception as e:
            results.append(f"{name:24s} ERROR: {e}")
    return {"stdout": "\n".join(results), "exit_code": 0}


def tool_list_backups(_args):
    if not os.path.isdir(BACKUP_DIR):
        return {"error": f"Backup dir not found: {BACKUP_DIR}"}
    return run(["ls", "-lhS", BACKUP_DIR])


# ── Tool registry ────────────────────────────────────────────────────

TOOLS = {
    "disk_usage": {
        "fn": tool_disk_usage,
        "description": "Show disk usage of root filesystem (df -h /).",
        "schema": {"type": "object", "properties": {}, "required": []},
    },
    "memory_usage": {
        "fn": tool_memory_usage,
        "description": "Show RAM and swap usage (free -h).",
        "schema": {"type": "object", "properties": {}, "required": []},
    },
    "uptime": {
        "fn": tool_uptime,
        "description": "Show server uptime and load average.",
        "schema": {"type": "object", "properties": {}, "required": []},
    },
    "health_check": {
        "fn": tool_health_check,
        "description": (
            "Probe HTTP health endpoints of the Hermes Stack: "
            "Hermes Dashboard, Open Notebook UI, Open Notebook API."
        ),
        "schema": {"type": "object", "properties": {}, "required": []},
    },
    "list_backups": {
        "fn": tool_list_backups,
        "description": "List backup archives in /opt/hermes-backups sorted by size.",
        "schema": {"type": "object", "properties": {}, "required": []},
    },
}


def tool_def(name, info):
    return {
        "name": name,
        "description": info["description"],
        "inputSchema": info["schema"],
    }


# ── MCP server loop ──────────────────────────────────────────────────

def send(msg):
    sys.stdout.write(json.dumps(msg, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def log(msg):
    sys.stderr.write(f"[mcp-ops] {msg}\n")
    sys.stderr.flush()


def handle(msg):
    method = msg.get("method")
    msg_id = msg.get("id")
    params = msg.get("params") or {}

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": SERVER_INFO,
            },
        }

    if method == "notifications/initialized":
        return None

    if method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": {"tools": [tool_def(n, i) for n, i in TOOLS.items()]},
        }

    if method == "tools/call":
        name = params.get("name")
        args = params.get("arguments") or {}
        if name not in TOOLS:
            return {
                "jsonrpc": "2.0",
                "id": msg_id,
                "error": {"code": -32601, "message": f"Unknown tool: {name}"},
            }
        try:
            log(f"call {name}")
            result = TOOLS[name]["fn"](args)
            text = json.dumps(result, ensure_ascii=False, indent=2)
            is_error = bool(result.get("error")) or (
                isinstance(result.get("exit_code"), int) and result["exit_code"] != 0
            )
            return {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "content": [{"type": "text", "text": text}],
                    "isError": is_error,
                },
            }
        except Exception as e:
            log(f"handler error: {e}")
            return {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "content": [{"type": "text", "text": f"Error: {e}"}],
                    "isError": True,
                },
            }

    if msg_id is not None:
        return {
            "jsonrpc": "2.0",
            "id": msg_id,
            "error": {"code": -32601, "message": f"Method not found: {method}"},
        }
    return None


def main():
    log(f"started (variant B — no docker), backup_dir={BACKUP_DIR}")
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except Exception as e:
            log(f"parse error: {e}")
            continue
        try:
            resp = handle(msg)
        except Exception as e:
            log(f"top-level error: {e}")
            resp = {
                "jsonrpc": "2.0",
                "id": msg.get("id"),
                "error": {"code": -32000, "message": str(e)},
            }
        if resp is not None:
            send(resp)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
