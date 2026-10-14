#!/bin/bash
set -euo pipefail

MEMU_API="http://localhost:8001/api/v1/memory"
MEMU_AUTH="Bearer memu-local-key-2026"
LOG_FILE="/var/log/memu-auto-memorize.log"
STATE_DIR="/opt/hermes-stack/memu-state"
mkdir -p "$STATE_DIR"

# Python script for processing sessions
PY_SCRIPT="/opt/hermes-stack/scripts/process_session.py"
cat > "$PY_SCRIPT" << 'PYEOF'
import json, sys, requests

session_file, last_ts, api_url, auth = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]

# Handle Python-style booleans (False/True/None) in session files
try:
    with open(session_file) as f:
        content = f.read()
    # Replace Python booleans with JSON equivalents
    content = content.replace('False', 'false').replace('True', 'true').replace('None', 'null')
    session = json.loads(content)
except (json.JSONDecodeError, SyntaxError) as e:
    print(f"Skipping malformed session: {session_file} - {e}")
    sys.exit(0)

messages = session.get("messages", [])
conversation = []
for msg in messages:
    role = msg.get("role", "")
    content = msg.get("content", "")
    if role in ("user", "assistant") and content:
        conversation.append({"role": role, "content": content})

if not conversation:
    sys.exit(0)

agent_name = session.get("agent", "unknown")
user_id = session.get("user_id", "hermes-user")
session_date = session.get("started_at", "")

payload = {
    "user_id": f"hermes-{agent_name}",
    "user_name": f"Hermes {agent_name.title()}",
    "agent_id": agent_name,
    "agent_name": f"{agent_name.title()} Agent",
    "conversation_text": "\n".join(f"{m['role'].upper()}: {m['content']}" for m in conversation),
    "session_date": session_date
}

headers = {"Authorization": auth, "Content-Type": "application/json"}
try:
    r = requests.post(f"{api_url}/memorize", json=payload, headers=headers, timeout=30)
    print(f"Submitted: {r.json().get('task_id')}")
except Exception as e:
    print(f"Exception: {e}")
PYEOF

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

get_last_ts() {
    local source=$1
    local file="$STATE_DIR/${source}.ts"
    [[ -f "$file" ]] && cat "$file" || echo "0"
}

set_last_ts() {
    local source=$1
    local ts=$2
    echo "$ts" > "$STATE_DIR/${source}.ts"
}

process_hermes_sessions() {
    local last_ts=$(get_last_ts "hermes")
    local sessions_dir="/opt/hermes-stack/data/.hermes/sessions"
    
    [[ -d "$sessions_dir" ]] || return 0
    
    # If state file doesn't exist, process all files (first run)
    local find_args=("$sessions_dir" \( -name "session_*.json" -o -name "session_*.jsonl" \))
    if [[ -f "$STATE_DIR/hermes.ts" ]]; then
        find_args+=("-newer" "$STATE_DIR/hermes.ts")
    fi
    find "${find_args[@]}" 2>/dev/null | while read -r session_file; do
        python3 "$PY_SCRIPT" "$session_file" "$last_ts" "$MEMU_API" "$MEMU_AUTH"
    done
    
    set_last_ts "hermes" "$(date +%s)"
}

process_codex_logs() {
    local last_ts=$(get_last_ts "codex")
    local codex_dir="/opt/hermes-stack/hermes-v20-data/projects"
    
    [[ -d "$codex_dir" ]] || return 0
    
    # Placeholder - adapt to actual Codex log format
    set_last_ts "codex" "$(date +%s)"
}

log "Starting auto-memorize run"
process_hermes_sessions
process_codex_logs
log "Auto-memorize run complete"