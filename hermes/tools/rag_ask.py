#!/usr/bin/env python3
"""Hermes RAG tool — calls Open Notebook ask/simple with tiered fallback."""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request

API = os.environ.get("OPEN_NOTEBOOK_API", "http://open-notebook:5055")

STRATEGY = [
    "model:13p5ick2928524qdcuqi",
    "model:4ohhiesz518vnpmxo8eo",
    "model:8572t7nmbxum5dewcmhi",
]
ANSWER = [
    "model:polbyfa2poahd3mw7gk8",
    "model:dljiexbw9pfzvoeft88g",
    "model:3c8or8ninh0chsgapcok",
]
FINAL = [
    "model:y6015qxyz2kjsgqeezjd",
    "model:dljiexbw9pfzvoeft88g",
    "model:3c8or8ninh0chsgapcok",
]


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


def main():
    p = argparse.ArgumentParser(description="Hermes RAG ask tool")
    p.add_argument("question")
    p.add_argument("--json", action="store_true")
    p.add_argument("--timeout", type=int, default=45)
    p.add_argument("--debug", action="store_true")
    args = p.parse_args()

    tiers = min(len(STRATEGY), len(ANSWER), len(FINAL))
    url = f"{API}/api/search/ask/simple"
    last = None

    if args.debug:
        print(f"[debug] API={API} tiers={tiers}", file=sys.stderr)

    for tier in range(tiers):
        payload = {
            "question": args.question,
            "strategy_model": STRATEGY[tier],
            "answer_model": ANSWER[tier],
            "final_answer_model": FINAL[tier],
        }
        if args.debug:
            print(f"[debug] tier={tier+1}/{tiers}", file=sys.stderr)

        status, resp = post_json(url, payload, args.timeout)
        last = (status, resp)

        if args.debug:
            short = json.dumps(resp, ensure_ascii=False)[:200] if isinstance(resp, dict) else str(resp)[:200]
            print(f"[debug] status={status} body~={short}", file=sys.stderr)

        if status == 200:
            if args.json:
                print(json.dumps(resp, ensure_ascii=False, indent=2))
                return 0
            ans = None
            if isinstance(resp, dict):
                for k in ("answer", "final_answer", "response", "result"):
                    v = resp.get(k)
                    if isinstance(v, str) and v.strip():
                        ans = v
                        break
            print(ans if ans else json.dumps(resp, ensure_ascii=False))
            return 0

        body_lower = json.dumps(resp).lower() if isinstance(resp, dict) else str(resp).lower()
        if "rate limit" in body_lower or "quota" in body_lower or status == 429:
            time.sleep(2)

    status, resp = last if last else (0, "no attempts")
    print(f"All RAG tiers failed. Last status={status}", file=sys.stderr)
    short = json.dumps(resp, ensure_ascii=False)[:300] if isinstance(resp, dict) else str(resp)[:300]
    print(f"Last response: {short}", file=sys.stderr)
    return 3


if __name__ == "__main__":
    sys.exit(main())
