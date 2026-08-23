✅ Hermes Stack — Server Map (v2.1)
Дата актуализации: 2026‑06‑06
Версия архитектуры: Hermes Stack v1.1
Статус: Production‑ready

1️⃣ Назначение сервера
Сервер используется как единый Docker‑стек для:

Hermes Gateway + Dashboard
Open Notebook (RAG / Knowledge Base)
SurrealDB (DB layer)
Multi‑provider AITelegram AI‑бота
LLM‑independent monitoring (Iron Monitor)
Hermes‑Ops (MCP tools)
max2tg (Telegram Bot)
Принципы архитектуры
Всё через Docker ComposeНет systemd‑сервисов
Нет venv‑сервисов
Порты не открываются наружу
UI доступен только через SSH LocalForward
Критический мониторинг не зависит от LLMGitHub — источник правды

2️⃣ Сервер
Провайдер: Aeza
OS: Ubuntu 24.04.4 LTSSSH пользователь: root

Проект:

text

/opt/hermes-stack
Бэкапы:

text

/opt/hermes-backups
3️⃣ Git‑репозиторий
Репозиторий:

text

https://github.com/inickolson/Hermes-Stack
Источник правды: GitHub

Workflow:

text

Редактирование → GitHub →
cd /opt/hermes-stack
git pull
.gitignore исключает:

text

.env
data/
*.tar.gz
*.log
4️⃣ SSH доступ
text

Host aeza
    HostName 89.22.234.108
    User root
    LocalForward 8020 127.0.0.1:8020
    LocalForward 8502 127.0.0.1:8502    LocalForward 5055 127.0.0.1:5055
5️⃣ Docker стек
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
6️⃣ КонтейнерыService	Container	Назначение
hermes	hermes	Gateway + Dashboard
open-notebook	open-notebook	RAG UI + API
surrealdb	surrealdb	Database
max2tg	max2tg-max2tg-1	Telegram Bot
Проверка:

Bashdocker compose ps
7️⃣ Порты
Сервис	Binding
Hermes	127.0.0.1:8020Notebook UI	127.0.0.1:8502
Notebook API	127.0.0.1:5055
SurrealDB	internal only
max2tg	нет (только исходящие соединения)
❗ Запрещено открывать 0.0.0.0 без reverse proxy.

8️⃣ Hermes
Версия:

text

hermes-agent v2026.8.3 (GitHub-тарболл, см. hermes/Dockerfile)
Причина фиксации:
Пин 0.14.0 отменён; в v20 дашборд на basic-auth (HERMES_DASHBOARD_BASIC_AUTH_*), см. .env.example

Allowlist:

text

/opt/hermes-stack/data/.hermes/.env
Содержимое:

text

GATEWAY_ALLOW_ALL_USERS=true
HERMES_INSECURE=true
9️⃣ Open Notebook
Образ:

text

lfnovo/open_notebook:v1-latest
Embeddings:

text

google | gemini-embedding-2
RAG данные:

text

/opt/hermes-stack/data/open-notebook/notebook_data
🔟 SurrealDB
Образ:

text

surrealdb/surrealdb:v2
Endpoint:

text

ws://surrealdb:8000/rpcНаружу не публикуется.

1️⃣1️⃣ AI Providers
Роль	Провайдер	Модель
Chat	OpenRouter	openai/gpt-oss-120b:free (временно)
Embeddings	Google	gemini-embedding-2
Transform	OpenAI Compatible	qwen3-coder
Tools	Google	gemini-2.0-flash
⚠ Free модели могут давать 503 и таймауты.
✅ Рекомендуется убрать free LLM из primary.

1️⃣2️⃣ RAG
Контрольная фраза:

text

фиолетовый кактус 713
Hermes использует MCP rag_ask.

RAG подтверждён и работает.

1️⃣3️⃣ Hermes as Admin Agent
MCP ops (variant B):

Tool	Функция
disk_usage	df -h
memory_usage	free -h
uptime	uptime
health_check	HTTP probe
list_backups	ls backups
Hermes используется для анализа, не для критических алертов.

1️⃣4️⃣ 🔐 Iron Monitor (LLM‑independent)
Дата внедрения: 2026‑06‑03

Файл:

text

/opt/hermes-stack/iron_monitor.sh
Cron:

text

*/5 * * * * /opt/hermes-stack/iron_monitor.sh
Принцип:

Проверяет docker inspect
Отправляет Telegram через curl
Не использует Hermes
Не использует LLM
Работает при падении hermes
Архитектура:

text

Layer 1 — Iron Monitor
Layer 2 — Hermes MCP Ops
1️⃣5️⃣ max2tg
Telegram-бот, запущенный как отдельный Docker‑контейнер.

Путь:

text/root/max2tg
Compose файл:

text

/root/max2tg/docker-compose.yml
Перезапуск:

text

docker compose restart
Логи:

text

docker logs -f max2tg-max2tg-1
1️⃣6️⃣ Telegram
Отдельный бот:
Hermes Ops Monitor

Работает напрямую через Telegram Bot API.

1️⃣7️⃣ Health Check
Bash

curl -s -o /dev/null -w "Hermes: %{http_code}\n" http://127.0.0.1:8020
curl -s -o /dev/null -w "Notebook UI: %{http_code}\n" http://127.0.0.1:8502
curl -s -o /dev/null -w "Notebook API: %{http_code}\n" http://127.0.0.1:5055
1️⃣8️⃣ БэкапыScript:

text

/opt/hermes-stack/backup.sh
Location:

text

/opt/hermes-backups
Retention:
14 days

Содержимое:

docker-compose.yml
STACK.md
AGENTS.mdCHEATSHEET.md
RECOVERY.md
.env
data/
1️⃣9️⃣ Безопасность
Не публиковать .env
Не публиковать полный compose config
Не открывать порты наружуДелать бэкап перед изменениями
Не менять encryption key
Не обновлять Hermes без теста
SurrealDB не публиковать
1️⃣0️⃣ Очистка
Bash

docker system df
df -h /
docker builder prune
Осторожно:

text

docker system prune -a --volumes
2️⃣1️⃣ Диагностика
Bash

free -h
df -h /
docker stats --no-stream
2️⃣2️⃣ Архитектура
text

Browser
   ↓ SSH
Hermes Dashboard
   ↓
Open Notebook (RAG)
   ↓
SurrealDB

Monitoring:
Iron Monitor
   ↓
Telegram

max2tg   ↓
Telegram
2️⃣3️⃣ Следующие шаги
Auto-healing (restart container)
Disk alert >90%
Memory alert >90%
Убрать free LLM из primary
Cost control
Gateway Proxy
Cache layer
Guard layer
✅ 2️⃣4️⃣ Статус системы
Hermes Stack v1.1Production‑ready
AI‑assisted
LLM‑independent monitoring enabled
Git versioned
max2tg running

2️⃣5
## FreeLLMAPI Integration Router
- **Назначение:** Локальный эмулятор / провайдер API для подключения внешней среды разработки VS Code к моделям.
- **Особенность:** Не влияет на внутреннюю работу Hermes Agent и open-notebook.ai. Используется исключительно для изоляции и маршрутизации запросов из IDE (VS Code) к внешним провайдерам, описанным в `FreeLLMAPI.md`.
