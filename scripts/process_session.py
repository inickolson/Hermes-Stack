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
