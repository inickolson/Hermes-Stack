Это твоя финальная, отшлифованная шпаргалка для **Hermes Stack v1.1**. Сохрани её в заметки или в файл `CHEATSHEET.md` прямо на сервере.

---

# 🛠️ HERMES STACK v1.1 — ADMIN CHEATSHEET

### 📂 1. ОСНОВНЫЕ ПУТИ
*   **Проект:** `cd /opt/hermes-stack`
*   **Данные:** `/opt/hermes-stack/data` (базы и сессии)
*   **Бэкапы:** `/opt/hermes-backups` (архивы)
*   **Секреты:** `/opt/hermes-stack/.env` (права 600)

---

### 🐙 2. GITHUB (СИНХРОНИЗАЦИЯ)
*Всегда делай `git pull` после правок на GitHub.*

*   `git status` — проверить локальные изменения.
*   `git pull` — забрать обновления с GitHub.
*   `git push origin main` — отправить свои правки на GitHub.
*   `git reset --hard origin/main` — **ОТКАТ:** сбросить всё и сделать как в GitHub.

---

### 🐳 3. DOCKER (УПРАВЛЕНИЕ)
*Выполнять строго внутри `/opt/hermes-stack`.*

*   `docker compose ps` — статус всех сервисов (**healthy** = норма).
*   `docker compose up -d` — запустить / применить изменения.
*   `docker compose restart` — перезагрузить все контейнеры.
*   `docker compose config > /dev/null` — **ПРОВЕРКА:** есть ли ошибки в YAML.
*   `docker logs -f hermes` — живые логи ассистента.
*   `docker stats` — нагрузка на CPU и RAM в реальном времени.

---

### 🛡️ 4. ЗДОРОВЬЕ И МОНИТОРИНГ
*   `docker inspect hermes --format '{{.State.Health.Status}}'` — пульс Гермеса.
*   `bash /opt/hermes-stack/iron_monitor.sh` — запустить монитор вручную.
*   `crontab -l` — проверить расписание (должно быть раз в 5 мин).
*   **Ручная проверка портов:**
    *   Hermes (8020): `curl -I http://127.0.0.1:8020` (ждем 200 или 405).
    *   Notebook (8502): `curl -I http://127.0.0.1:8502` (ждем 307).

---

### 💾 5. БЭКАПЫ И ОЧИСТКА
*   `bash /opt/hermes-stack/backup.sh` — сделать полный бэкап сейчас.
*   `ls -lh /opt/hermes-backups` — список всех архивов.
*   `df -h /` — сколько места на диске (алерт при >90%).
*   `free -h` — сколько свободной памяти (алерт при >90%).
*   `docker system prune -f` — **БЕЗОПАСНАЯ ОЧИСТКА** кэша и мусора Docker.

---

### 🤖 6. ПРОФИЛИ МОДЕЛЕЙ (HERMES UI)
*Настраиваются в Dashboard (Settings > Models).*

1.  **Everyday** — Llama 3.3 70B (Основной мозг).
2.  **Coding** — Qwen 2.5 Coder (Программирование).
3.  **Deep Analysis** — Gemini 2.0 Thinking (Сложные задачи).
4.  **Fallback** — Llama 3.1 8B (Cerebras / Резерв).

---

### 🚑 7. ЭКСТРЕННЫЕ СИТУАЦИИ
1.  **Бот молчит:** Проверь `docker ps`. Если `unhealthy` — делай `docker compose restart`.
2.  **Ошибка YAML:** Если после `git pull` всё сломалось — делай `git reset --hard origin/main`.
3.  **Место кончилось:** Удали старые бэкапы в `/opt/hermes-backups` и сделай `docker system prune -f`.
4.  **Всё упало:**
    *   `docker compose stop`
    *   `tar -xzf /opt/hermes-backups/LATEST_DATA.tar.gz -C /`
    *   `docker compose up -d`

---

### 📡 8. SSH ТУННЕЛИ (LocalForward)
*   **8020** — Dashboard Гермеса.
*   **8502** — Интерфейс Notebook.
*   **5055** — API Notebook.

---
**Hermes Stack v1.1** — *Стабильность. Безопасность. Автономность.* 🚀🦾


Hermes Stack v1.1 — Admin Cheatsheet
Назначение: быстрые команды для обслуживания сервера без поиска по документации.
━━━━━━━━━━━━━━━━━━
Проект
━━━━━━━━━━━━━━━━━━
Перейти в проект:
Bash
cd /opt/hermes-stack
Проверить текущую папку:
Bash
pwd
Ожидается:
text
/opt/hermes-stack
━━━━━━━━━━━━━━━━━━
2. GitHub
━━━━━━━━━━━━━━━━━━
Проверить состояние репозитория:
Bash
git status
Получить изменения из GitHub:
Bash
git pull
Посмотреть последние коммиты:
Bash
git log --oneline -10
Текущая ветка:
Bash
git branch
Перед запуском после изменения compose:
Bash
docker compose config > /dev/null
Если ошибок нет:
Bash
docker compose up -d
━━━━━━━━━━━━━━━━━━
3. Docker
━━━━━━━━━━━━━━━━━━
Статус сервисов:
Bash
docker compose ps
Статус контейнеров:
Bash
docker ps
Запуск:
Bash
docker compose up -d
Перезапуск:
Bash
docker compose restart
Остановка:
Bash
docker compose down
Логи всех сервисов:
Bash
docker compose logs -f
Логи Hermes:
Bash
docker logs -f hermes
Логи Open Notebook:
Bash
docker logs -f open-notebook
Логи SurrealDB:
Bash
docker logs -f surrealdb
━━━━━━━━━━━━━━━━━━
4. Health Check
━━━━━━━━━━━━━━━━━━
Статус Hermes:
Bash
docker inspect hermes --format '{{.State.Health.Status}}'
Статус Open Notebook:
Bash
docker inspect open-notebook --format '{{.State.Health.Status}}'
Полная проверка:
Bash
docker compose ps
Ожидается:
text
hermes          healthy
open-notebook   healthy
surrealdb       Up
━━━━━━━━━━━━━━━━━━
5. Проверка сервисов
━━━━━━━━━━━━━━━━━━
Hermes:
Bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8020
Open Notebook UI:
Bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8502
Open Notebook API:
Bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:5055
Нормальный результат:
text
200
307
200
━━━━━━━━━━━━━━━━━━
6. Мониторинг
━━━━━━━━━━━━━━━━━━
Монитор:
text
/opt/hermes-stack/iron_monitor.sh
Ручной запуск:
Bash
bash /opt/hermes-stack/iron_monitor.sh
Проверка скорости:
Bash
time bash /opt/hermes-stack/iron_monitor.sh
Файл состояния:
text
/opt/hermes-stack/.monitor_state
━━━━━━━━━━━━━━━━━━
7. Ресурсы сервера
━━━━━━━━━━━━━━━━━━
Память:
Bash
free -h
Диск:
Bash
df -h /
Нагрузка контейнеров:
Bash
docker stats --no-stream
Аптайм:
Bash
uptime
Текущие рабочие значения (июнь 2026):
text
Disk:   ~31%
Memory: ~32%
━━━━━━━━━━━━━━━━━━
8. Данные
━━━━━━━━━━━━━━━━━━
Размер всех данных:
Bash
du -sh /opt/hermes-stack/data
Подробно:
Bash
du -h --max-depth=2 /opt/hermes-stack/data | sort -h
Основные данные:
text
/opt/hermes-stack/data/.hermes
/opt/hermes-stack/data/open-notebook
━━━━━━━━━━━━━━━━━━
9. Бэкапы
━━━━━━━━━━━━━━━━━━
Каталог:
text
/opt/hermes-backups
Посмотреть архивы:
Bash
ls -lh /opt/hermes-backups
Размер архива:
Bash
du -sh /opt/hermes-backups
Создать вручную:
Bash
bash /opt/hermes-stack/backup.sh
Восстановление:
Bash
docker compose stop
tar -xzf /opt/hermes-backups/ИМЯ_АРХИВА.tar.gz -C /
docker compose up -d
━━━━━━━━━━━━━━━━━━
10. Очистка Docker
━━━━━━━━━━━━━━━━━━
Посмотреть размеры:
Bash
docker system df
Подробно:
Bash
docker system df -v
Очистить build cache:
Bash
docker builder prune
Удалить неиспользуемые volumes:
Bash
docker volume prune -f
Осторожно:
Bash
docker system prune -a --volumes
Использовать только при полном понимании последствий.
━━━━━━━━━━━━━━━━━━
11. Важные файлы
━━━━━━━━━━━━━━━━━━
Docker Compose:
text
/opt/hermes-stack/docker-compose.yml
Документация:
text
/opt/hermes-stack/STACK.md
Политики агента:
text
/opt/hermes-stack/AGENTS.md
Переменные окружения:
text
/opt/hermes-stack/.env
Монитор:
text
/opt/hermes-stack/iron_monitor.sh
Бэкапы:
text
/opt/hermes-stack/backup.sh
План восстановления:
text
/opt/hermes-stack/RECOVERY.md
━━━━━━━━━━━━━━━━━━
12. SSH
━━━━━━━━━━━━━━━━━━
Подключение:
Bash
ssh aeza
Локальные форварды:
text
8020 → Hermes Dashboard
8502 → Open Notebook UI
5055 → Open Notebook API
━━━━━━━━━━━━━━━━━━
13. Если что-то сломалось
━━━━━━━━━━━━━━━━━━
Проверить контейнеры:
Bash
docker compose ps
Проверить здоровье Hermes:
Bash
docker inspect hermes --format '{{.State.Health.Status}}'
Посмотреть последние логи:
Bash
docker logs --tail 100 hermes
Проверить ресурсы:
Bash
free -h
df -h /
Проверить Git:
Bash
git status
Проверить Compose:
Bash
docker compose config
Если ситуация совсем плохая:
text
Смотреть RECOVERY.md
Восстанавливаться из последнего бэкапа
━━━━━━━━━━━━━━━━━━
14. Текущая архитектура
━━━━━━━━━━━━━━━━━━
text
Browser
   ↓ SSH Tunnel
Hermes Dashboard
   ↓
Open Notebook (RAG)
   ↓
SurrealDB

Monitoring:
Iron Monitor
   ↓
Telegram
Статус:
text
Hermes Stack v1.1
Production Ready
Health Checks Enabled
Docker Auto-Restart Enabled
LLM-Independent Monitoring Enabled
Git Versioned

