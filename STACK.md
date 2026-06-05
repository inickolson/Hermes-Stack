✅ Hermes Stack — Server Map (v2.0)
Дата актуализации: 2026‑06‑03
Версия архитектуры: Hermes Stack v1.0 (Production-ready)

1. Назначение сервера
Сервер используется как единый Docker‑стек для:

Hermes Gateway + Dashboard
Open Notebook (RAG / Knowledge Base)
SurrealDB (DB layer)
Multi-provider AI
Telegram AI-бота
LLM-independent monitoring (Iron Monitor)
Hermes-Ops (MCP tools)
Принципы:

Всё через Docker Compose
Нет systemd-сервисов
Нет venv-сервисов
Порты не открываются наружу
UI только через SSH LocalForward
Критический мониторинг не зависит от LLM
2. Сервер
Провайдер:

text

Aeza
OS:

text

Ubuntu 24.04.4 LTS
SSH пользователь:

text

root
Проект:

text

/opt/hermes-stack
Бэкапы:

text

/opt/hermes-backups
3. Git‑репозиторий
Репозиторий:

text

https://github.com/inickolson/Hermes-Stack
Источник правды: GitHub.

Workflow:

Редактирование → GitHub →
На сервере:

Bash

cd /opt/hermes-stack
git pull
.gitignore исключает:

text

.env
data/
*.tar.gz
*.log
4. SSH доступ
SSH config:

sshconfig

Host aeza
    HostName 147.45.79.76
    User root
    LocalForward 8020 127.0.0.1:8020
    LocalForward 8502 127.0.0.1:8502
    LocalForward 5055 127.0.0.1:5055
5. Docker стек
Управление:

Bash

cd /opt/hermes-stack
docker compose ps
docker compose up -d
docker compose down
docker compose restart
docker compose logs -f
Compose файл:

text

/opt/hermes-stack/docker-compose.yml
6. Контейнеры
Service	Container	Назначение
hermes	hermes	Gateway + Dashboard
open-notebook	open-notebook	RAG UI + API
surrealdb	surrealdb	Database
Проверка:

Bash

docker compose ps
7. Порты
Сервис	Binding
Hermes	127.0.0.1:8020
Notebook UI	127.0.0.1:8502
Notebook API	127.0.0.1:5055
SurrealDB	internal only
Запрещено открывать 0.0.0.0 без reverse proxy.

8. Hermes
Версия:

text

hermes-agent==0.14.0
Причина фиксации:
0.15.x ломала dashboard.

Allowlist:

text

/opt/hermes-stack/data/.hermes/.env
Содержимое:

text

GATEWAY_ALLOW_ALL_USERS=true
HERMES_INSECURE=true
9. Open Notebook
Образ:

text

lfnovo/open_notebook:v1-latest
Embeddings:

text

google | gemini-embedding-2
RAG хранится в:

text

data/open-notebook/notebook_data
10. SurrealDB
Образ:

text

surrealdb/surrealdb:v2
Endpoint:

text

ws://surrealdb:8000/rpc
Наружу не публикуется.

11. AI Providers
Роль	Провайдер	Модель
Chat	OpenRouter	openai/gpt-oss-120b:free
Embeddings	Google	gemini-embedding-2
Transform	OpenAI Compatible	qwen3-coder
Tools	Google	gemini-2.0-flash
⚠ Free модели могут давать 503.

12. RAG
Контрольная фраза:

text

фиолетовый кактус 713
Hermes использует MCP rag.

RAG подтверждён и работает.

13. Hermes as Full AI Admin Agent
MCP ops (variant B):

Tool	Функция
disk_usage	df -h
memory_usage	free -h
uptime	uptime
health_check	HTTP probe
list_backups	ls backups
Hermes используется для анализа, не для критических алертов.

14. 🔐 Iron Monitor (LLM-independent)
Дата внедрения: 2026‑06‑03

Файл:

text

/opt/hermes-stack/iron_monitor.sh
Cron:

text

* * * * * /opt/hermes-stack/iron_monitor.sh
Принцип:

Проверяет docker inspect
Отправляет Telegram через curl
Не использует Hermes
Не использует LLM
Работает при падении hermes
Архитектура:

Layer 1 — Iron Monitor
Layer 2 — Hermes MCP Ops

15. Telegram
Отдельный бот:
Hermes Ops Monitor

Используется напрямую через Telegram Bot API.

16. Health Check
Bash

curl -s -o /dev/null -w "Hermes: %{http_code}\n" http://127.0.0.1:8020
curl -s -o /dev/null -w "Notebook UI: %{http_code}\n" http://127.0.0.1:8502
curl -s -o /dev/null -w "Notebook API: %{http_code}\n" http://127.0.0.1:5055

17. Бэкапы
Конфиги:

Bash

tar -czf /opt/hermes-backups/config-$(date +%Y%m%d-%H%M%S).tar.gz \
docker-compose.yml .env STACK.md AGENTS.md
Данные:

Bash

docker compose stop open-notebook surrealdb
tar -czf /opt/hermes-backups/data-$(date +%Y%m%d-%H%M%S).tar.gz data/open-notebook
docker compose up -d

18. Безопасность
Не публиковать .env
Не публиковать docker compose config
Не открывать порты наружу
Делать бэкап перед изменениями
Не менять encryption key
Не обновлять Hermes без теста
SurrealDB не публиковать

19. Очистка
Bash

docker system df
df -h /
docker builder prune
Осторожно:

text

docker system prune -a --volumes

20. Диагностика
Bash

free -h
df -h /
docker stats --no-stream

21. Архитектура (v1.0)
text

Browser
   ↓ SSH
Hermes Dashboard
   ↓
Open Notebook (RAG)
   ↓
SurrealDB
Monitoring:

text

Iron Monitor
   ↓
Telegram

22. Следующие шаги
Auto-healing (restart container)
Disk usage alert >90%
Memory alert >90%
Убрать free LLM из primary
Cost control
Gateway Proxy
Cache layer
Guard layer

23. Статус системы
Hermes Stack v1.0
Production-ready
AI-assisted
LLM-independent monitoring enabled
Git versioned

24. Backup


Script:
/opt/hermes-stack/backup.sh

Location:
/opt/hermes-backups

Retention:
14 days

Contents:
docker-compose.yml
STACK.md
AGENTS.md
CHEATSHEET.md
RECOVERY.md
.env
data/


25. Recovery


Recovery document:

/opt/hermes-stack/RECOVERY.md

Recovery procedure:

1. Install Docker
2. Clone Hermes-Stack
3. Restore .env
4. Restore latest backup
5. docker compose up -d
6. Verify health status


26. Cheatsheet


Admin reference:

/opt/hermes-stack/CHEATSHEET.md

Contains:
Docker
GitHub
Monitoring
Backup
Recovery
Diagnostics