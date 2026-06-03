#!/usr/bin/env python3
"""
Hermes Stack — RAG ask tool.

Запрос вопроса к Open Notebook через /api/search/ask/simple
с поддержкой fallback-моделей.

Использование:
    rag_ask.py "Какая контрольная фраза указана в документе?"
    rag_ask.py --json "вопрос"
    rag_ask.py --debug "вопрос"

Конфигурация:
    /opt/hermes-stack/bin/rag_ask.env

Возвращает в stdout текстовый ответ.
Код возврата:
    0  — успех
    1  — ошибка конфигурации/аргументов
    2  — Open Notebook API недоступен
    3  — все модели в fallback цепочке упали
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ENV_FILE = Path("/opt/hermes-stack/bin/rag_ask.env")


def load_env(path: Path) -> dict:
    if not path.exists():
        return {}
    data = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        k, v = line.split("=", 1)
        data[k.strip()] = v.strip()
    return data


def split_models(val: str) -> list[str]:
    return [x.strip() for x in val.split(",") if x.strip()]


def http_post_json(url: str, payload: dict, timeout: int) -> tuple[int, dict | str]:
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8", "replace")
            status = resp.status
            try:
                return status, json.loads(raw)
            except json.JSONDecodeError:
                return status, raw
    except urllib.error.HTTPError as e:
        try:
            raw = e.read().decode("utf-8", "replace")
        except Exception:
            raw = str(e)
        try:
            return e.code, json.loads(raw)
        except json.JSONDecodeError:
            return e.code, raw
    except urllib.error.URLError as e:
        return 0, f"URLError: {e}"
    except TimeoutError as e:
        return 0, f"Timeout: {e}"
    except Exception as e:
        return 0, f"Exception: {e}"


def extract_answer(resp) -> str | None:
    if isinstance(resp, dict):
        for key in ("final_answer", "answer", "response", "result", "output", "text"):
            v = resp.get(key)
            if isinstance(v, str) and v.strip():
                return v
        data = resp.get("data")
        if isinstance(data, dict):
            for key in ("final_answer", "answer", "response", "result"):
                v = data.get(key)
                if isinstance(v, str) and v.strip():
                    return v
    if isinstance(resp, str) and resp.strip():
        return resp
    return None


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Ask Open Notebook RAG with fallback models.",
    )
    parser.add_argument("question", help="Question to ask the knowledge base")
    parser.add_argument("--json", action="store_true", help="Print full JSON response")
    parser.add_argument("--debug", action="store_true", help="Verbose debug output to stderr")
    args = parser.parse_args()

    env = {}
    env.update(load_env(ENV_FILE))
    env.update({k: v for k, v in os.environ.items() if k in {
        "OPEN_NOTEBOOK_API",
        "STRATEGY_MODELS",
        "ANSWER_MODELS",
        "FINAL_ANSWER_MODELS",
        "TIMEOUT",
    }})

    api = env.get("OPEN_NOTEBOOK_API", "http://127.0.0.1:5055").rstrip("/")
    strategy = split_models(env.get("STRATEGY_MODELS", ""))
    answer = split_models(env.get("ANSWER_MODELS", ""))
    final = split_models(env.get("FINAL_ANSWER_MODELS", ""))
    try:
        timeout = int(env.get("TIMEOUT", "120"))
    except ValueError:
        timeout = 120

    if not strategy or not answer or not final:
        print("Config error: STRATEGY_MODELS / ANSWER_MODELS / FINAL_ANSWER_MODELS are required",
              file=sys.stderr)
        return 1

    if args.debug:
        print(f"[debug] API={api}", file=sys.stderr)
        print(f"[debug] strategy={strategy}", file=sys.stderr)
        print(f"[debug] answer={answer}", file=sys.stderr)
        print(f"[debug] final={final}", file=sys.stderr)
        print(f"[debug] timeout={timeout}", file=sys.stderr)

    health_url = f"{api}/api/models/defaults"
    try:
        with urllib.request.urlopen(health_url, timeout=10) as r:
            r.read()
    except Exception as e:
        print(f"Open Notebook API not reachable at {api}: {e}", file=sys.stderr)
        return 2

    url = f"{api}/api/search/ask/simple"

    attempts = []
    for sm in strategy:
        for am in answer:
            for fm in final:
                attempts.append((sm, am, fm))

    last_error = None
    for sm, am, fm in attempts:
        payload = {
            "question": args.question,
            "strategy_model": sm,
            "answer_model": am,
            "final_answer_model": fm,
        }
        if args.debug:
            print(f"[debug] try {sm} / {am} / {fm}", file=sys.stderr)

        t0 = time.time()
        status, resp = http_post_json(url, payload, timeout=timeout)
        dt = time.time() - t0

        if args.debug:
            short = json.dumps(resp)[:300] if not isinstance(resp, str) else resp[:300]
            print(f"[debug] status={status} time={dt:.1f}s body~={short}", file=sys.stderr)

        if status == 200:
            if args.json:
                if isinstance(resp, dict):
                    print(json.dumps(resp, ensure_ascii=False, indent=2))
                else:
                    print(resp)
                return 0
            ans = extract_answer(resp)
            if ans:
                print(ans)
                return 0
            print(json.dumps(resp, ensure_ascii=False))
            return 0

        last_error = (status, resp, sm, am, fm)

    print("All model combinations failed.", file=sys.stderr)
    if last_error:
        status, resp, sm, am, fm = last_error
        short = json.dumps(resp)[:500] if not isinstance(resp, str) else resp[:500]
        print(f"Last status={status} sm={sm} am={am} fm={fm} body~={short}",
              file=sys.stderr)
    return 3


if __name__ == "__main__":
    sys.exit(main())
