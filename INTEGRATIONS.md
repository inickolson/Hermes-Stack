# Integrations

## FreeLLMAPI (Local LLM Router)

**Path:** /opt/freellmapi/

### Ports
- 3001 — API + Web UI
- 5173 — Vite dev (optional)

### Services
systemctl status freellmapi-server freellmapi-client

### API Endpoints
- GET /v1/models — list
- POST /v1/chat/completions — proxy

### Usage (SSH)
ssh -L 3001:localhost:3001 root@89.22.234.108 -N &

### VSCode
{
  "models": [{"title":"FreeLLM","provider":"openai","model":"auto","apiBase":"http://localhost:3001/v1","apiKey":"none"}]
}
