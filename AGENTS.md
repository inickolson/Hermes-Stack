# AGENTS.md — Hermes Stack Admin Instructions

This file is for AI agents and human operators administering `/opt/hermes-stack`.

Before making changes, read:

```text
/opt/hermes-stack/STACK.md
```

---

## 1. Mission

Maintain and extend the Hermes Stack safely.

Current stack:

- Hermes Agent Dashboard
- Hermes Gateway
- Open Notebook knowledge base / RAG
- SurrealDB for Open Notebook
- Multi-provider AI through OpenRouter, NVIDIA, Google, OpenAI-compatible endpoints

Future stack:

- Gateway Proxy
- RAG bridge
- Cache
- Guard
- Router
- Call control
- Hermes-Ops
- Telegram integration

---

## 2. Critical Safety Rules

1. Do not expose services directly to the public internet.
2. Keep published ports bound to `127.0.0.1`.
3. Do not bind Hermes/Open Notebook/API to `0.0.0.0` unless a secure reverse proxy with auth/TLS is explicitly configured.
4. Do not create systemd services unless explicitly requested.
5. Use Docker Compose for services.
6. Do not create random Python venv background services.
7. Do not print secrets from `.env`.
8. Do not paste full `docker compose config` output publicly because it may include secrets.
9. Before destructive or structural changes, create a backup.
10. Do not delete `/opt/hermes-stack/data` without a verified backup.
11. Do not change `OPEN_NOTEBOOK_ENCRYPTION_KEY` after credentials are stored unless migration is planned.
12. Do not upgrade Hermes from `hermes-agent==0.14.0` without dashboard compatibility testing.
13. Prefer small incremental changes.
14. After every change, run health checks.
15. Document architecture changes in `STACK.md`.

---

## 3. Important Paths

```text
/opt/hermes-stack
/opt/hermes-stack/docker-compose.yml
/opt/hermes-stack/.env
/opt/hermes-stack/STACK.md
/opt/hermes-stack/AGENTS.md
/opt/hermes-stack/hermes/Dockerfile
/opt/hermes-stack/data/.hermes/.env
/opt/hermes-stack/data/open-notebook/
/opt/hermes-stack/data/open-notebook/notebook_data
/opt/hermes-stack/data/open-notebook/surreal_data
/opt/hermes-backups
```

Default working directory:

```bash
cd /opt/hermes-stack
```

---

## 4. Running Services

Docker Compose services:

| Service | Container | Purpose |
|---|---|---|
| hermes | hermes | Hermes Gateway + Hermes Dashboard |
| open-notebook | open-notebook | Open Notebook UI + REST API |
| surrealdb | surrealdb | Database for Open Notebook |

Check status:

```bash
cd /opt/hermes-stack
docker compose ps
```

---

## 5. Ports

All public host bindings must stay on `127.0.0.1`.

| Service | Host | Purpose |
|---|---|---|
| Hermes Dashboard | 127.0.0.1:8020 | Hermes Web UI |
| Open Notebook UI | 127.0.0.1:8502 | Open Notebook Web UI |
| Open Notebook API | 127.0.0.1:5055 | REST API / Swagger |
| SurrealDB | internal only :8000 | Open Notebook DB |

Do not expose these directly:

```text
0.0.0.0:8020
0.0.0.0:8502
0.0.0.0:5055
0.0.0.0:8000
```

Check ports:

```bash
ss -tlnp | grep -E '8020|8502|5055|8000'
```

---

## 6. Health Check

Run after every change:

```bash
cd /opt/hermes-stack && \
docker compose ps && \
curl -s -o /dev/null -w "Hermes: %{http_code}\n" http://127.0.0.1:8020 && \
curl -s -o /dev/null -w "OpenNotebook UI: %{http_code}\n" http://127.0.0.1:8502 && \
curl -s -o /dev/null -w "OpenNotebook API: %{http_code}\n" http://127.0.0.1:5055
```

Normal results:

```text
Hermes: 200
OpenNotebook UI: 200 or 307
OpenNotebook API: 200
```

Notes:

- `OpenNotebook UI: 307` is normal.
- `curl -I http://127.0.0.1:8020` may return `405`; use GET health check instead.

---

## 7. Hermes Notes

Hermes version:

```text
hermes-agent==0.14.0
```

Reason:

```text
This version matches the old working setup.
Newer 0.15.x versions previously broke dashboard behavior.
```

Hermes Dockerfile:

```text
/opt/hermes-stack/hermes/Dockerfile
```

Hermes dashboard:

```text
http://localhost:8020
```

Hermes 0.14.0 requires insecure allowlist config for dashboard binding.

Host file:

```text
/opt/hermes-stack/data/.hermes/.env
```

Inside container:

```text
/root/.hermes/.env
```

Required content:

```env
GATEWAY_ALLOW_ALL_USERS=true
HERMES_INSECURE=true
```

Important:

```text
docker-compose mounts ./data:/root, so /root/.hermes/.env inside the container comes from /opt/hermes-stack/data/.hermes/.env on the host.
```

Normal Hermes warning:

```text
WARNING gateway.run: No messaging platforms enabled.
```

This is not an error until Telegram/Slack/WhatsApp are configured.

---

## 8. Open Notebook Notes

Open Notebook runs without Ollama.

Container:

```text
open-notebook
```

Image:

```text
lfnovo/open_notebook:v1-latest
```

UI:

```text
http://localhost:8502
```

API:

```text
http://localhost:5055
```

Swagger:

```text
http://localhost:5055/docs
```

OpenAPI:

```text
http://localhost:5055/openapi.json
```

Data:

```text
/opt/hermes-stack/data/open-notebook/notebook_data
```

SurrealDB data:

```text
/opt/hermes-stack/data/open-notebook/surreal_data
```

SurrealDB internal URL:

```text
ws://surrealdb:8000/rpc
```

---

## 9. Model Assignments

Current working Open Notebook model assignments:

```text
Chat              openai/gpt-oss-120b:free via OpenRouter/OpenAI Compatible
Embeddings        gemini-embedding-2 via Google
Transformations   qwen/qwen3-coder-480b-a35b-instruct via NVIDIA/OpenAI Compatible
Large Context     qwen/qwen3-coder-480b-a35b-instruct via NVIDIA/OpenAI Compatible
Tools             gemini-2.0-flash via Google
TTS               not configured
STT               not configured
```

Do not use OpenRouter for embeddings unless explicitly tested.

Use Google embeddings for RAG:

```text
gemini-embedding-2
```

OpenRouter should be configured as:

```text
Provider type: OpenAI Compatible
Base URL: https://openrouter.ai/api/v1
```

NVIDIA should be configured as OpenAI Compatible.

---

## 10. Check Open Notebook Models

Use this command to inspect model state without exposing secrets:

```bash
python3 - <<'PY'
import json, urllib.request
from collections import Counter

base = "http://127.0.0.1:5055"
models = json.load(urllib.request.urlopen(base + "/api/models"))
defaults = json.load(urllib.request.urlopen(base + "/api/models/defaults"))
by_id = {m["id"]: m for m in models}

print("=== COUNTS BY PROVIDER/TYPE ===")
for k, v in sorted(Counter((m.get("provider"), m.get("type")) for m in models).items()):
    print(k, v)

print()
print("=== DEFAULTS ===")
for role, mid in defaults.items():
    m = by_id.get(mid)
    if not m:
        print(role, "=", mid)
    else:
        print(role, "=", m.get("provider"), "|", m.get("type"), "|", m.get("name"))
PY
```

Expected known-good state:

```text
('google', 'embedding') 21
('google', 'language') 21
('openai_compatible', 'language') 31

default_chat_model = openai_compatible | language | openai/gpt-oss-120b:free
default_transformation_model = openai_compatible | language | qwen/qwen3-coder-480b-a35b-instruct
large_context_model = openai_compatible | language | qwen/qwen3-coder-480b-a35b-instruct
default_embedding_model = google | embedding | gemini-embedding-2
default_tools_model = google | language | gemini-2.0-flash
```

---

## 11. RAG Test

Known test notebook:

```text
Hermes RAG Test
```

Known test source:

```text
hermes_rag_test.md
```

Control phrase:

```text
фиолетовый кактус 713
```

Expected answers:

```text
Question: Какая контрольная фраза указана в документе?
Answer: фиолетовый кактус 713

Question: На каком порту работает Hermes Dashboard?
Answer: 8020

Question: Используется ли Ollama в этой установке?
Answer: Нет, Ollama не используется.
```

If these fail, check:

1. Open Notebook logs.
2. Embedding model.
3. Source processing status.
4. Notebook/source relation.
5. API health.

---

## 12. Logs

Hermes logs:

```bash
cd /opt/hermes-stack
docker compose logs -f hermes
```

Open Notebook logs:

```bash
cd /opt/hermes-stack
docker compose logs -f open-notebook
```

SurrealDB logs:

```bash
cd /opt/hermes-stack
docker compose logs -f surrealdb
```

Last logs:

```bash
cd /opt/hermes-stack
docker compose logs --tail=120 hermes
docker compose logs --tail=120 open-notebook
docker compose logs --tail=120 surrealdb
```

---

## 13. Backups

Backup directory:

```text
/opt/hermes-backups
```

Create config backup:

```bash
cd /opt/hermes-stack && \
mkdir -p /opt/hermes-backups && \
chmod 700 /opt/hermes-backups && \
tar -czf /opt/hermes-backups/hermes-stack-config-$(date +%Y%m%d-%H%M%S).tar.gz \
  docker-compose.yml \
  .env \
  hermes/Dockerfile \
  data/.hermes/.env \
  STACK.md \
  AGENTS.md
```

Create consistent Open Notebook data backup:

```bash
cd /opt/hermes-stack && \
docker compose stop open-notebook surrealdb && \
tar -czf /opt/hermes-backups/open-notebook-data-$(date +%Y%m%d-%H%M%S).tar.gz \
  data/open-notebook && \
docker compose up -d open-notebook surrealdb && \
sleep 5 && \
docker compose ps
```

Verify backups:

```bash
ls -lh /opt/hermes-backups
```

---

## 14. Safe Change Procedure

Before modifying stack:

1. `cd /opt/hermes-stack`
2. Read `STACK.md`.
3. Run `docker compose ps`.
4. Run health check.
5. Create backup.
6. Edit one thing only.
7. Run `docker compose up -d`.
8. Run health check again.
9. Check logs.
10. Update `STACK.md` if architecture changed.

---

## 15. Routine Commands

Status:

```bash
cd /opt/hermes-stack
docker compose ps
```

Start/update stack:

```bash
cd /opt/hermes-stack
docker compose up -d
```

Restart all:

```bash
cd /opt/hermes-stack
docker compose restart
```

Restart Hermes:

```bash
cd /opt/hermes-stack
docker compose restart hermes
```

Restart Open Notebook and DB:

```bash
cd /opt/hermes-stack
docker compose restart open-notebook surrealdb
```

Stop stack:

```bash
cd /opt/hermes-stack
docker compose down
```

---

## 16. Dangerous Commands

Do not run without explicit confirmation and backup:

```bash
rm -rf /opt/hermes-stack/data
docker compose down -v
docker system prune -a --volumes
docker volume prune
docker image prune -a
```

Be careful with:

```bash
cat .env
docker compose config
```

because these can expose secrets.

---

## 17. Disk / Resource Diagnostics

Safe diagnostics:

```bash
free -h
df -h /
docker stats --no-stream
docker system df
du -h -d 1 /opt 2>/dev/null | sort -h
```

Careful cleanup:

```bash
docker builder prune
docker image prune
apt autoremove -y
apt clean
journalctl --vacuum-time=3d
```

Do not delete Docker volumes blindly.

---

## 18. Future Work

Target architecture:

```text
Hermes Dashboard
    ↓
Gateway Proxy
    ↓
RAG + Cache + Guard + Router + Call Control
    ↓
OpenRouter / NVIDIA / Google / other providers
    ↓
Open Notebook API / SurrealDB
```

Planned additions:

- Open Notebook API bridge for Hermes
- Gateway Proxy
- RAG lookup service
- Cache layer
- Guard layer
- Router
- Call limits / cost control
- Controlled server operations
- Hermes-Ops
- Telegram integration

---

## 19. Final Reminder

The stack is currently working.

Do not break working services while adding new features.

Current known-good health:

```text
Hermes: 200
OpenNotebook UI: 307
OpenNotebook API: 200
```

If unsure, stop and ask before changing architecture.

---

## 21. Safe Config Inspection

Never paste full `docker compose config` output publicly — it contains secrets from `.env`.

Safe alternatives:

    # Just validate
    docker compose config > /dev/null && echo "valid"

    # Show only services
    docker compose config --services

    # Show only specific keys (no secrets)
    docker compose config 2>&1 | grep -E "container_name|volumes:|networks:"

    # Show only volumes mapping
    docker compose config --volumes

---

## 24. Hermes agent runtime configuration

Default model: openai/gpt-oss-120b:free (via OpenRouter)
Provider auth: OPENROUTER_API_KEY (passed via .env)

Test agent:

    docker exec -it hermes hermes -z "Что хранится в моей базе знаний?"

Change model interactively:

    docker exec -it hermes hermes model

Or edit directly:

    docker exec hermes sed -i "s|^model:.*|model: 'NEW_MODEL_NAME'|" /root/.hermes/config.yaml
    docker compose restart hermes


---

## 25. Hermes-Ops MCP server

Hermes has access to safe-only server admin tools via MCP server "ops".

Tools (read-only, no docker control):
- disk_usage
- memory_usage
- uptime
- health_check
- list_backups

Path in container: /opt/hermes-tools/mcp_ops_bridge.py

Variant B principles:
- No shell injection (args passed as list)
- 10s timeout per command
- Allowlist of commands
- No docker socket, no service restart capability

Test:

    docker exec -it hermes hermes -z "Как там сервер?"

Hermes should automatically call ops:* tools without explicit hints.

If after rebuild the ops server is missing, re-register with the same procedure
as rag (see section 23).

