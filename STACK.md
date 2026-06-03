
# Hermes Stack — Server Map

Дата актуализации: 2026-05-31

Этот файл описывает текущую структуру сервера, Docker-стек, пути, порты, модели, правила безопасности и процедуры обслуживания.

Файл предназначен для:
- владельца сервера;
- будущего AI-агента-администратора;
- восстановления контекста после перезапуска/миграции;
- безопасного расширения архитектуры.

---

## 1. Назначение сервера

Сервер используется как единый Docker-стек для:

- Hermes Agent Dashboard;
- Hermes Gateway;
- Open Notebook как база знаний / RAG;
- SurrealDB как база данных Open Notebook;
- multi-provider AI через OpenRouter, NVIDIA, Google и OpenAI-compatible endpoints;
- будущего Gateway Proxy с RAG / Cache / Guard / Router;
- будущего Hermes-Ops агента для контролируемого администрирования сервера;
- будущей Telegram-интеграции.

Принцип эксплуатации:

- без systemd-зоопарка;
- без ручных Python venv-сервисов;
- всё основное запускается через Docker Compose;
- порты наружу не открываются напрямую;
- доступ к UI через SSH LocalForward.

---

## 2. Сервер

Провайдер:

```text
Aeza
```

OS:

```text
Ubuntu 24.04.4 LTS
```

Пользователь SSH:

```text
root
```

Основная директория проекта:

```text
/opt/hermes-stack
```

Директория бэкапов:

```text
/opt/hermes-backups
```

---

## 3. SSH-доступ и LocalForward

Обычный SSH config на локальном компьютере:

```sshconfig
Host aeza
    HostName 147.45.79.76
    User root
    LocalForward 8020 127.0.0.1:8020
    LocalForward 8502 127.0.0.1:8502
```

Для доступа к Open Notebook API docs также полезно добавить:

```sshconfig
    LocalForward 5055 127.0.0.1:5055
```

После подключения:

```bash
ssh aeza
```

Локальные URL в браузере:

```text
Hermes Dashboard:
http://localhost:8020

Open Notebook UI:
http://localhost:8502

Open Notebook API docs:
http://localhost:5055/docs
```

---

## 4. Главная структура проекта

Текущая рабочая директория:

```text
/opt/hermes-stack
```

Ожидаемая структура:

```text
/opt/hermes-stack
├── docker-compose.yml
├── .env
├── STACK.md
├── AGENTS.md
├── hermes/
│   ├── Dockerfile
│   └── Dockerfile.ok
└── data/
    ├── .hermes/
    │   └── .env
    └── open-notebook/
        ├── notebook_data/
        └── surreal_data/
```

Важные пути:

```text
/opt/hermes-stack/docker-compose.yml
/opt/hermes-stack/.env
/opt/hermes-stack/hermes/Dockerfile
/opt/hermes-stack/data/.hermes/.env
/opt/hermes-stack/data/open-notebook/notebook_data
/opt/hermes-stack/data/open-notebook/surreal_data
/opt/hermes-backups
```

---

## 5. Docker Compose

Все основные сервисы управляются через:

```bash
cd /opt/hermes-stack
docker compose ps
docker compose up -d
docker compose down
docker compose restart
docker compose logs -f
```

Основной compose-файл:

```text
/opt/hermes-stack/docker-compose.yml
```

Проверка синтаксиса:

```bash
cd /opt/hermes-stack
docker compose config
```

Внимание:

```text
docker compose config может вывести секреты из .env.
Не публиковать полный вывод этой команды в чатах/логах/публичных местах.
```

---

## 6. Контейнеры

Текущие сервисы:

| Service | Container | Назначение |
|---|---|---|
| hermes | hermes | Hermes Gateway + Hermes Dashboard |
| open-notebook | open-notebook | Open Notebook UI + REST API |
| surrealdb | surrealdb | База данных Open Notebook |

Проверка:

```bash
cd /opt/hermes-stack
docker compose ps
```

---

## 7. Порты

Все опубликованные порты должны быть привязаны только к `127.0.0.1`.

| Сервис | Внутренний порт | Host binding | Назначение |
|---|---:|---|---|
| Hermes Dashboard | 8020 | 127.0.0.1:8020 | Web UI Hermes |
| Open Notebook UI | 8502 | 127.0.0.1:8502 | Web UI Open Notebook |
| Open Notebook API | 5055 | 127.0.0.1:5055 | REST API / Swagger |
| SurrealDB | 8000 | internal only | DB для Open Notebook |

Проверка слушающих портов:

```bash
ss -tlnp | grep -E '8020|8502|5055|8000'
```

Важно:

```text
Не публиковать 8020, 8502, 5055 на 0.0.0.0 без отдельного reverse proxy, auth и TLS.
```

---

## 8. Health-check

Проверка с сервера:

```bash
curl -s -o /dev/null -w "Hermes: %{http_code}\n" http://127.0.0.1:8020 && \
curl -s -o /dev/null -w "OpenNotebook UI: %{http_code}\n" http://127.0.0.1:8502 && \
curl -s -o /dev/null -w "OpenNotebook API: %{http_code}\n" http://127.0.0.1:5055
```

Нормальные ответы:

```text
Hermes: 200
OpenNotebook UI: 200 или 307
OpenNotebook API: 200
```

Примечание:

```text
OpenNotebook UI: 307 — нормально, UI делает redirect.
```

---

## 9. Hermes

Hermes работает в Docker-контейнере:

```text
container_name: hermes
service: hermes
```

Версия Hermes:

```text
hermes-agent==0.14.0
```

Причина фиксации:

```text
Версия 0.14.0 соответствует старому рабочему systemd-стеку.
Новые версии 0.15.x ранее ломали dashboard.
Без отдельного теста Hermes не обновлять.
```

Dockerfile:

```text
/opt/hermes-stack/hermes/Dockerfile
```

Dashboard:

```text
http://localhost:8020
```

Внутри сервера:

```text
http://127.0.0.1:8020
```

---

## 10. Особенность Hermes 0.14.0

Hermes 0.14.0 отказывается bind на `0.0.0.0`, если не разрешён insecure/allow-all режим.

Ошибка, которая была решена:

```text
Refusing to bind to 0.0.0.0 — the dashboard exposes API keys
```

Рабочее решение:

на хосте:

```text
/opt/hermes-stack/data/.hermes/.env
```

внутри контейнера:

```text
/root/.hermes/.env
```

Содержимое:

```env
GATEWAY_ALLOW_ALL_USERS=true
HERMES_INSECURE=true
```

Важно:

```text
В docker-compose используется volume ./data:/root.
Поэтому /root/.hermes/.env внутри контейнера берётся из /opt/hermes-stack/data/.hermes/.env на хосте.
```

---

## 11. Hermes Dockerfile

Текущий Dockerfile находится здесь:

```text
/opt/hermes-stack/hermes/Dockerfile
```

Рабочая идея Dockerfile:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir hermes-agent==0.14.0
RUN pip install --no-cache-dir fastapi uvicorn jinja2 python-multipart

RUN mkdir -p /root/.hermes && \
    echo "GATEWAY_ALLOW_ALL_USERS=true" > /root/.hermes/.env && \
    echo "HERMES_INSECURE=true" >> /root/.hermes/.env

ENV HERMES_WEB_DIR=/usr/local/lib/python3.11/site-packages/hermes_agent/web/dist

EXPOSE 8020

CMD sh -c "hermes gateway run & sleep 3 && hermes dashboard --host 0.0.0.0 --port 8020 --insecure"
```

Важно:

```text
Даже если Dockerfile создаёт /root/.hermes/.env, volume ./data:/root перекрывает /root.
Поэтому главный рабочий файл allowlist — /opt/hermes-stack/data/.hermes/.env.
```

---

## 12. Hermes логи

Логи Hermes:

```bash
cd /opt/hermes-stack
docker compose logs -f hermes
```

Обычное предупреждение:

```text
WARNING gateway.run: No messaging platforms enabled.
```

Это нормально, пока не подключены Telegram/Slack/WhatsApp.

---

## 13. Open Notebook

Open Notebook работает без Ollama.

Контейнер:

```text
container_name: open-notebook
service: open-notebook
```

Образ:

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

Swagger/OpenAPI docs:

```text
http://localhost:5055/docs
```

OpenAPI JSON:

```text
http://localhost:5055/openapi.json
```

Данные Open Notebook:

```text
/opt/hermes-stack/data/open-notebook/notebook_data
```

---

## 14. SurrealDB

SurrealDB используется как база данных Open Notebook.

Контейнер:

```text
container_name: surrealdb
service: surrealdb
```

Образ:

```text
surrealdb/surrealdb:v2
```

Внутренний endpoint для Open Notebook:

```text
ws://surrealdb:8000/rpc
```

Данные SurrealDB:

```text
/opt/hermes-stack/data/open-notebook/surreal_data
```

SurrealDB не публикуется наружу.

В compose должен использоваться `expose`, а не public `ports`:

```yaml
expose:
  - "8000"
```

---

## 15. .env и секреты

Основной env-файл:

```text
/opt/hermes-stack/.env
```

В нём хранятся секреты.

Известные переменные:

```env
OPENROUTER_API_KEY=...
NVIDIA_API_KEY=...
OPEN_NOTEBOOK_ENCRYPTION_KEY=...
```

Также могут быть добавлены:

```env
GOOGLE_API_KEY=...
CEREBRAS_API_KEY=...
GITHUB_TOKEN=...
XAI_API_KEY=...
GROQ_API_KEY=...
```

Правила:

```text
Не публиковать .env.
Не делать cat .env в публичный чат.
Не публиковать полный docker compose config.
При компрометации ключей — перевыпустить ключи у провайдера.
```

Примечание:

```text
OPEN_NOTEBOOK_ENCRYPTION_KEY используется Open Notebook для шифрования credentials в базе.
Не менять его после сохранения API-ключей без плана миграции.
```

---

## 16. AI-провайдеры

Текущие провайдеры:

| Провайдер | Статус | Как подключён |
|---|---|---|
| Google AI | работает | напрямую в Open Notebook |
| NVIDIA | работает | OpenAI Compatible |
| OpenRouter | работает | OpenAI Compatible |
| Grok/xAI | частично/необязательно | OpenAI Compatible, может давать 400 на discovery |
| Cerebras | потенциально | OpenAI Compatible |
| GitHub Models | потенциально | OpenAI Compatible |
| FreeLLMAPI | потенциально | OpenAI Compatible |

Важно:

```text
OpenRouter надёжнее добавлять как OpenAI Compatible:
Base URL: https://openrouter.ai/api/v1
```

Встроенный провайдер OpenRouter в Open Notebook может показывать "настроено", но не всегда корректно добавляет модели в /api/models.

---

## 17. Текущая модельная схема Open Notebook

Финальная рабочая схема:

| Роль | Провайдер | Модель |
|---|---|---|
| Chat | OpenRouter через OpenAI Compatible | openai/gpt-oss-120b:free |
| Embeddings | Google | gemini-embedding-2 |
| Transformations | NVIDIA/OpenAI Compatible | qwen/qwen3-coder-480b-a35b-instruct |
| Large Context | NVIDIA/OpenAI Compatible | qwen/qwen3-coder-480b-a35b-instruct |
| Tools | Google | gemini-2.0-flash |
| TTS | none | не настроено |
| STT | none | не настроено |

Проверка моделей:

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

Последнее подтверждённое состояние:

```text
=== COUNTS BY PROVIDER/TYPE ===
('google', 'embedding') 21
('google', 'language') 21
('openai_compatible', 'language') 31

=== DEFAULTS ===
default_chat_model = openai_compatible | language | openai/gpt-oss-120b:free
default_transformation_model = openai_compatible | language | qwen/qwen3-coder-480b-a35b-instruct
large_context_model = openai_compatible | language | qwen/qwen3-coder-480b-a35b-instruct
default_text_to_speech_model = None
default_speech_to_text_model = None
default_embedding_model = google | embedding | gemini-embedding-2
default_tools_model = google | language | gemini-2.0-flash
```

---

## 18. RAG test

Создан тестовый блокнот:

```text
Hermes RAG Test
```

Тестовый источник:

```text
hermes_rag_test.md
```

Контрольная фраза:

```text
фиолетовый кактус 713
```

Содержание тестового документа включает факты:

```text
Hermes Dashboard работает на порту 8020.
Open Notebook работает на порту 8502.
Open Notebook API работает на порту 5055.
SurrealDB используется как база данных для Open Notebook.
Open Notebook был добавлен без Ollama.
```

Проверочные вопросы:

```text
Какая контрольная фраза указана в документе?
На каком порту работает Hermes Dashboard?
Используется ли Ollama в этой установке?
```

Ожидаемые ответы:

```text
фиолетовый кактус 713
8020
Нет, Ollama не используется.
```

Факт:

```text
RAG был проверен через чат с блокнотом.
Ответы по документу получены.
Ссылки на source отображались.
```

---

## 19. Open Notebook API

API доступен локально:

```text
http://127.0.0.1:5055
```

Swagger:

```text
http://localhost:5055/docs
```

OpenAPI JSON:

```bash
curl -s http://127.0.0.1:5055/openapi.json | python3 -m json.tool | head -120
```

Вывести релевантные endpoints:

```bash
python3 - <<'PY'
import json, urllib.request

data = json.load(urllib.request.urlopen("http://127.0.0.1:5055/openapi.json"))

for path, methods in data.get("paths", {}).items():
    if any(x in path.lower() for x in ["search", "query", "chat", "notebook", "source"]):
        print(path, "=>", ",".join(methods.keys()))
PY
```

Будущая задача:

```text
Интегрировать Hermes с Open Notebook API, чтобы Hermes мог искать по базе знаний.
```

---

## 20. Текущий docker-compose.yml — логическая структура

Файл:

```text
/opt/hermes-stack/docker-compose.yml
```

Основные сервисы:

```yaml
services:

  hermes:
    build: ./hermes
    container_name: hermes
    restart: unless-stopped
    ports:
      - "127.0.0.1:8020:8020"
    volumes:
      - ./data:/root
    environment:
      - GATEWAY_ALLOW_ALL_USERS=true
      - HERMES_INSECURE=true
    env_file:
      - .env

  surrealdb:
    image: surrealdb/surrealdb:v2
    container_name: surrealdb
    restart: unless-stopped
    command: start --log info --user root --pass root rocksdb:/mydata/mydatabase.db
    user: root
    expose:
      - "8000"
    volumes:
      - ./data/open-notebook/surreal_data:/mydata
    environment:
      - SURREAL_EXPERIMENTAL_GRAPHQL=true

  open-notebook:
    image: lfnovo/open_notebook:v1-latest
    container_name: open-notebook
    restart: unless-stopped
    depends_on:
      - surrealdb
    ports:
      - "127.0.0.1:8502:8502"
      - "127.0.0.1:5055:5055"
    environment:
      - OPEN_NOTEBOOK_ENCRYPTION_KEY=${OPEN_NOTEBOOK_ENCRYPTION_KEY}
      - SURREAL_URL=ws://surrealdb:8000/rpc
      - SURREAL_USER=root
      - SURREAL_PASSWORD=root
      - SURREAL_NAMESPACE=open_notebook
      - SURREAL_DATABASE=open_notebook
    volumes:
      - ./data/open-notebook/notebook_data:/app/data
    env_file:
      - .env
```

Важно:

```text
Это логическое описание.
Перед правками смотреть фактический /opt/hermes-stack/docker-compose.yml.
```

---

## 21. Команды обслуживания

Перейти в стек:

```bash
cd /opt/hermes-stack
```

Статус:

```bash
docker compose ps
```

Запуск:

```bash
docker compose up -d
```

Остановка:

```bash
docker compose down
```

Перезапуск всего стека:

```bash
docker compose restart
```

Перезапуск Hermes:

```bash
docker compose restart hermes
```

Перезапуск Open Notebook и DB:

```bash
docker compose restart open-notebook surrealdb
```

Логи Hermes:

```bash
docker compose logs -f hermes
```

Логи Open Notebook:

```bash
docker compose logs -f open-notebook
```

Логи SurrealDB:

```bash
docker compose logs -f surrealdb
```

Последние логи:

```bash
docker compose logs --tail=120 hermes
docker compose logs --tail=120 open-notebook
docker compose logs --tail=120 surrealdb
```

---

## 22. Бэкапы

Директория:

```text
/opt/hermes-backups
```

Создать директорию:

```bash
mkdir -p /opt/hermes-backups
chmod 700 /opt/hermes-backups
```

Бэкап конфигов:

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

Бэкап Open Notebook data:

```bash
cd /opt/hermes-stack && \
docker compose stop open-notebook surrealdb && \
tar -czf /opt/hermes-backups/open-notebook-data-$(date +%Y%m%d-%H%M%S).tar.gz \
  data/open-notebook && \
docker compose up -d open-notebook surrealdb && \
sleep 5 && \
docker compose ps
```

Проверка бэкапов:

```bash
ls -lh /opt/hermes-backups
```

---

## 23. Безопасность

Критические правила:

1. Не публиковать `.env`.
2. Не публиковать полный `docker compose config`.
3. Не открывать 8020/8502/5055 на `0.0.0.0`.
4. Не создавать systemd-сервисы без явной причины.
5. Новые сервисы добавлять через Docker Compose.
6. Перед опасными изменениями делать бэкап.
7. Не удалять `/opt/hermes-stack/data`, если нет актуального бэкапа.
8. Не менять `OPEN_NOTEBOOK_ENCRYPTION_KEY` без плана миграции.
9. Не обновлять Hermes с `0.14.0` без отдельного теста dashboard.
10. Не использовать OpenRouter для embeddings, пока это явно не протестировано.
11. Для RAG использовать Google embeddings, сейчас `gemini-embedding-2`.
12. SurrealDB не публиковать наружу.
13. Доступ к UI — через SSH LocalForward или будущий защищённый reverse proxy.

---

## 24. Известные особенности и диагностика

### Hermes HEAD-запрос

Команда:

```bash
curl -I http://127.0.0.1:8020
```

может вернуть:

```text
405 Method Not Allowed
```

Это нормально, если GET работает:

```bash
curl -s http://127.0.0.1:8020 | head
```

---

### Open Notebook UI 307

Проверка:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8502
```

может вернуть:

```text
307
```

Это нормально.

---

### OpenRouter

Если встроенный OpenRouter provider в Open Notebook не сохраняет модели в `/api/models`, использовать:

```text
Provider type: OpenAI Compatible
Base URL: https://openrouter.ai/api/v1
```

---

### xAI/Grok

Может быть ошибка:

```text
Failed to discover xai models: Client error '400 Bad Request' for url 'https://api.x.ai/v1/models'
```

Это не блокирует Google/NVIDIA/OpenRouter.

---

### SurrealDB memory

SurrealDB может резервировать заметный cache, но это нормально, если сервер не уходит в OOM.

Проверка ресурсов:

```bash
free -h
df -h /
docker stats --no-stream
```

---

## 25. Очистка диска

Текущий сервер имеет достаточно места, но безопасная диагностика:

```bash
docker system df
df -h /
du -h -d 1 /opt 2>/dev/null | sort -h
```

Осторожная чистка:

```bash
docker builder prune
docker image prune
apt autoremove -y
apt clean
journalctl --vacuum-time=3d
```

Не выполнять бездумно:

```bash
docker system prune -a --volumes
```

Потому что можно удалить полезные volumes/images.

---

## 26. Текущая рабочая архитектура

```text
Mac browser
    ↓ SSH LocalForward
127.0.0.1:8020  → Hermes Dashboard
127.0.0.1:8502  → Open Notebook UI
127.0.0.1:5055  → Open Notebook API
                    ↓
                 SurrealDB internal :8000
```

AI providers:

```text
Open Notebook
    ↓
OpenRouter via OpenAI Compatible
NVIDIA via OpenAI Compatible
Google AI direct
```

RAG:

```text
Open Notebook
    ↓
Google Embeddings: gemini-embedding-2
    ↓
SurrealDB / Open Notebook data
```

---

## 27. Целевая архитектура

Желаемая финальная схема:

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

Будущие компоненты:

- Gateway Proxy;
- RAG bridge к Open Notebook API;
- Cache layer;
- Guard layer;
- routing между провайдерами;
- call limits / cost control;
- Hermes-Ops;
- Telegram integration;
- controlled server administration.

---

## 28. Следующие рекомендуемые шаги

Рекомендуемый порядок:

1. Создать `AGENTS.md` с правилами для AI-администратора.
2. Сделать бэкап `STACK.md`, `AGENTS.md`, compose и `.env`.
3. Исследовать Open Notebook API endpoints.
4. Сделать простой RAG bridge / tool для Hermes.
5. Добавить Gateway Proxy.
6. Добавить cache.
7. Добавить guard.
8. Добавить call control.
9. Добавить Hermes-Ops с allowlist-командами.
10. Добавить Telegram.

---

## 29. Минимальная команда проверки после любых изменений

```bash
cd /opt/hermes-stack && \
docker compose ps && \
curl -s -o /dev/null -w "Hermes: %{http_code}\n" http://127.0.0.1:8020 && \
curl -s -o /dev/null -w "OpenNotebook UI: %{http_code}\n" http://127.0.0.1:8502 && \
curl -s -o /dev/null -w "OpenNotebook API: %{http_code}\n" http://127.0.0.1:5055
```

Ожидаемо:

```text
Hermes: 200
OpenNotebook UI: 200 или 307
OpenNotebook API: 200
```

---

## 30. Важная памятка для будущего агента

Перед любыми изменениями:

1. Прочитать этот файл.
2. Проверить `docker compose ps`.
3. Проверить health endpoints.
4. Сделать бэкап.
5. Не выводить секреты.
6. Менять только один блок за раз.
7. После изменения проверять логи.
8. Обновлять этот файл, если изменилась архитектура.

EOF

ls -lh /opt/hermes-stack/STACK.md && \
echo '--- FIRST 40 LINES ---' && \
head -40 /opt/hermes-stack/STACK.md

---

## 36. MILESTONE: Full RAG-aware Hermes agent

Дата: 2026-05-31

Hermes теперь работает как автономный AI-агент с доступом к базе знаний.

Подтверждённое поведение:
- Hermes сам понимает когда использовать rag:rag_ask
- Самостоятельно формулирует запрос к Open Notebook
- Получает ответ и форматирует красиво для пользователя
- Цитирует источники

Тестовые промпты:

    docker exec -it hermes hermes -z "Какая контрольная фраза в hermes_rag_test.md? Используй rag_ask"
    docker exec -it hermes hermes -z "Что хранится в моей базе знаний?"

Текущие default параметры агента:
- model: openai/gpt-oss-120b:free (бесплатная)

- provider: openrouter
- credential: OPENROUTER_API_KEY (env)

Скорость:
- ~5-7 секунд на запрос с RAG

---

## 36. MILESTONE: Full RAG-aware Hermes agent

Дата: 2026-05-31

Hermes теперь работает как автономный AI-агент с доступом к базе знаний.

Подтверждённое поведение:
- Hermes сам понимает когда использовать rag:rag_ask
- Самостоятельно формулирует запрос к Open Notebook
- Получает ответ и форматирует красиво для пользователя
- Цитирует источники

Тестовые промпты:

    docker exec -it hermes hermes -z "Какая контрольная фраза в hermes_rag_test.md? Используй rag_ask"
    docker exec -it hermes hermes -z "Что хранится в моей базе знаний?"

Текущие default параметры агента:
- model: openai/gpt-oss-120b:free (бесплатная)
- provider: openrouter
- credential: OPENROUTER_API_KEY (env)

Скорость:
- ~5-7 секунд на запрос с RAG

---

## 37. MILESTONE: Hermes as Full AI Admin Agent

Дата: 2026-06-01

Hermes Agent теперь имеет два MCP server'а:
- rag — доступ к базе знаний Open Notebook
- ops — administer the server (variant B: no docker control)

Подтверждённое автономное поведение:
- На вопрос "Как там сервер?" Hermes сам понимает что нужны ops tools,
  вызывает disk_usage, memory_usage, uptime, health_check
  и формирует красивый human-readable отчёт.

### ops tools (variant B — без docker socket)

| Tool             | Что делает                          |
|------------------|-------------------------------------|
| ops:disk_usage   | df -h /                             |
| ops:memory_usage | free -h                             |
| ops:uptime       | uptime                              |
| ops:health_check | HTTP probe stack endpoints          |
| ops:list_backups | ls /opt/hermes-backups              |

### Mount points

- /opt/hermes-stack/hermes/tools → /opt/hermes-tools:ro (MCP scripts)
- /opt/hermes-backups → /opt/hermes-backups:ro (для list_backups)

### Requirements в Hermes контейнере

- pip пакет: mcp (для MCP SDK)
- apt пакет: procps (для free, uptime, ps)

Оба добавлены в Dockerfile.

### Регистрация после rebuild

Если контейнер пересоздан и MCP servers пропали:

    docker exec hermes hermes mcp add ops --command python3 --args /opt/hermes-tools/mcp_ops_bridge.py
    docker exec hermes hermes tools enable "ops:disk_usage"
    docker exec hermes hermes tools enable "ops:memory_usage"
    docker exec hermes hermes tools enable "ops:uptime"
    docker exec hermes hermes tools enable "ops:health_check"
    docker exec hermes hermes tools enable "ops:list_backups"
    # Включить сам server в config.yaml: enabled: true
    docker compose restart hermes

