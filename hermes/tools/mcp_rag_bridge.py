#!/usr/bin/env python3
"""
MCP server: rag_bridge
Exposes one tool: `rag_ask` — query Open Notebook RAG.

Protocol: MCP 2024-11-05 over stdio (JSON-RPC 2.0, line-delimited).
Stdlib only, no external deps.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

API = os.environ.get("OPEN_NOTEBOOK_API", "http://open-notebook:5055")

STRATEGY = [
    "model:13p5ick2928524qdcuqi",  # gemini-2.5-flash via OR (paid)
    "model:4ohhiesz518vnpmxo8eo",  # gemini-2.0-flash Google
    "model:8572t7nmbxum5dewcmhi",  # gpt-oss-120b:free
]
ANSWER = [
    "model:polbyfa2poahd3mw7gk8",  # gpt-4o-mini via OR (paid)
    "model:dljiexbw9pfzvoeft88g",  # gemini-2.5-flash Google
    "model:3c8or8ninh0chsgapcok",  # qwen3-coder-480b NVIDIA
]
FINAL = [
    "model:y6015qxyz2kjsgqeezjd",  # claude-3.5-haiku via OR (paid)
    "model:dljiexbw9pfzvoeft88g",  # gemini-2.5-flash Google
    "model:3c8or8ninh0chsgapcok",  # qwen3-coder-480b NVIDIA
]

SERVER_INFO = {
    "name": "hermes-rag-bridge",
    "version": "1.0.0",
}

TOOL_DEF = {
    "name": "rag_ask",
    "description": (
        "Ask the Open Notebook knowledge base a question using RAG. "
        "Returns an answer based on indexed documents with source citations. "
        "Use this when the user asks about anything stored in the knowledge base, "
        "project documentation, or any topic that might be in Open Notebook."
    ),
    "inputSchema": {
        "type": "object",
        "properties": {
            "question": {
                "type": "string",
                "description": "The question to ask the knowledge base.",
            },
            "timeout": {
                "type": "integer",
                "description": "Per-attempt timeout in seconds. Default 45.",
                "default": 45,
            },
        },
        "required": ["question"],
    },
}


def post_json(url, payload, timeout=45):
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, json.loads(r.read().decode("utf-8", "replace"))
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode("utf-8", "replace"))
        except Exception:
            return e.code, str(e)
    except Exception as e:
        return 0, str(e)


def rag_ask(question, timeout=45):
    tiers = min(len(STRATEGY), len(ANSWER), len(FINAL))
    url = f"{API}/api/search/ask/simple"
    last = None

    for tier in range(tiers):
        payload = {
            "question": question,
            "strategy_model": STRATEGY[tier],
            "answer_model": ANSWER[tier],
            "final_answer_model": FINAL[tier],
        }
        status, resp = post_json(url, payload, timeout)
        last = (status, resp)

        if status == 200:
            if isinstance(resp, dict):
                for k in ("answer", "final_answer", "response", "result"):
                    v = resp.get(k)
                    if isinstance(v, str) and v.strip():
                        return v
            return json.dumps(resp, ensure_ascii=False)

        body_lower = (
            json.dumps(resp).lower()
            if isinstance(resp, dict)
            else str(resp).lower()
        )
        if "rate limit" in body_lower or "quota" in body_lower or status == 429:
            time.sleep(2)

    status, resp = last if last else (0, "no attempts")
    short = (
        json.dumps(resp, ensure_ascii=False)[:300]
        if isinstance(resp, dict)
        else str(resp)[:300]
    )
    raise RuntimeError(f"All RAG tiers failed. status={status} body~={short}")


def send(msg):
    sys.stdout.write(json.dumps(msg, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def log(msg):
    sys.stderr.write(f"[mcp-rag] {msg}\n")
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
                "capabilities": {
                    "tools": {},
                },
                "serverInfo": SERVER_INFO,
            },
        }

    if method == "notifications/initialized":
        return None

    if method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": {"tools": [TOOL_DEF]},
        }

    if method == "tools/call":
        name = params.get("name")
        args = params.get("arguments") or {}
        if name != "rag_ask":
            return {
                "jsonrpc": "2.0",
                "id": msg_id,
                "error": {"code": -32601, "message": f"Unknown tool: {name}"},
            }
        try:
            question = args["question"]
            timeout = int(args.get("timeout", 45))
            answer = rag_ask(question, timeout=timeout)
            return {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "content": [{"type": "text", "text": answer}],
                    "isError": False,
                },
            }
        except Exception as e:
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
    log(f"started, API={API}")
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
            log(f"handler error: {e}")
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
