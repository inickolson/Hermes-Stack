🛠️ Hermes Stack v1.1 — Admin Cheatsheet
Назначение: Быстрые команды для обслуживания сервера без долгого поиска по документации.
Рабочая директория по умолчанию: cd /opt/hermes-stack

📂 1. Основные пути и файлы
Назначение	Путь
Корень проекта	/opt/hermes-stack
Базы и сессии	/opt/hermes-stack/data
Секреты (600)	/opt/hermes-stack/.env
Скрипт бэкапа	/opt/hermes-stack/backup.sh
Скрипт мониторинга	/opt/hermes-stack/iron_monitor.sh
Папка с бэкапами	/opt/hermes-backups
max2tg проект	/root/max2tg

🐙 2. GitHub (Синхронизация)
Все команды выполняются строго из /opt/hermes-stack.

Bash

git status                  # Проверить локальные изменения
git pull                    # Получить свежие обновления с GitHub
git push                    # Отправить свои правки на GitHub
git log --oneline -10       # Посмотреть 10 последних коммитов
git reset --hard origin/main # ❗️ ОТКАТ: сбросить всё и сделать как в GitHub

🐳 3. Управление Docker
Bash

docker compose config > /dev/null  # Проверка: есть ли синтаксические ошибки в YAML
docker compose ps                  # Статус всех сервисов
docker compose up -d               # Запустить стек / применить изменения в YAML
docker compose restart             # Перезагрузить все контейнеры
docker compose down                # Полная остановка стека
Чтение логов в реальном времени:

Bash

docker compose logs -f             # Логи всего стека сразу
docker logs -f hermes              # Логи только AI-ассистента
docker logs -f open-notebook       # Логи RAG-системы
docker logs -f surrealdb           # Логи базы данных
docker logs -f max2tg-max2tg-1      # Логи max2tg

🩺 4. Здоровье сервисов (Health Checks)
Проверка внутреннего пульса контейнеров:

Bash

docker inspect hermes --format '{{.State.Health.Status}}'
docker inspect open-notebook --format '{{.State.Health.Status}}'
docker inspect max2tg-max2tg-1 --format '{{.State.Status}}'
Ожидаемый ответ: healthy / running

Ручная проверка доступности (HTTP Probe):

Bash

curl -I http://127.0.0.1:8020  # Hermes (ожидаем HTTP 200 или 405)
curl -I http://127.0.0.1:8502  # Notebook UI (ожидаем HTTP 307)
curl -I http://127.0.0.1:5055  # Notebook API (ожидаем HTTP 200)

📈 5. Мониторинг и ресурсы сервера
Bash

bash /opt/hermes-stack/iron_monitor.sh  # Ручной запуск монитора (проверка алертов)
free -h                                 # Свободная ОЗУ и Swap (алерт при >90%)
df -h /                                 # Место на диске (алерт при >90%)
uptime                                  # Нагрузка на процессор (LA) и время работы
docker stats --no-stream                # Нагрузка контейнеров (CPU/RAM) в данный момент

💾 6. Данные, Бэкапы и Очистка
Оценка размеров:

Bash

du -sh /opt/hermes-stack/data       # Размер всех рабочих данных
du -sh /opt/hermes-backups          # Размер папки с архивами
Бэкапы:

Bash

bash /opt/hermes-stack/backup.sh    # Создать бэкап прямо сейчас
ls -lh /opt/hermes-backups          # Посмотреть список всех архивов
Очистка мусора Docker:

Bash

docker system df                    # Посмотреть, сколько места занимает кэш Docker
docker builder prune                # Безопасно очистить кэш сборки
docker system prune -f              # Очистить остановленные контейнеры и висячие образы
⚠️ Осторосторожно: Команду docker system prune -a --volumes использовать только при полном понимании последствий (удалит все неиспользуемые тома данных).

🤖 7. Профили моделей (Hermes Dashboard) - это пример. ВАРИАТИВНО, не является обязательным к исполнению, модели меняются без записи в гитхаб!!!
Настраиваются в веб-интерфейсе: Settings > Models

Everyday: Llama 3.3 70B (Основной мозг, баланс скорости и ума)
Coding: Qwen 2.5 Coder (Строгое программирование)
Deep Analysis: Gemini 2.0 Thinking / Flash (Сложные задачи и RAG)
Fallback: Llama 3.1 8B (Cerebras / Быстрый бесплатный резерв)

🔌 8. SSH ТУННЕЛИ (LocalForward)
Подключение: ssh aeza
Проброшенные порты на localhost (127.0.0.1):

8020 → Hermes Dashboard
8502 → Open Notebook UI
5055 → Open Notebook API

🚑 9. Экстренные ситуации
Бот молчит: Проверь docker compose ps. Если статус unhealthy — делай docker compose restart.
Ошибка YAML после Git Pull: Делай git reset --hard origin/main для отката.
Закончилось место на диске (No space left on device): Удали старые архивы из /opt/hermes-backups и сделай docker system prune -f.
Полный крах (восстановление из бэкапа):

Bash

docker compose stop
tar -xzf /opt/hermes-backups/ИМЯ_АРХИВА.tar.gz -C /
docker compose up -d

🏗️ 10. Текущая архитектура
text

Browser 
   ↓ (SSH Tunnel)
Hermes Gateway (Port 8020)
   ↓ (MCP stdio)
Open Notebook RAG (Port 8502 / 5055)
   ↓ (WebSocket)
SurrealDB (Port 8000, internal)

Monitoring Layer:
Iron Monitor (Cron) → Telegram Bot API

max2tg (Docker) → Telegram Bot API

Hermes Stack v1.1 — Стабильность. Безопасность. Автономность. 🚀🦾

🛠 HERMES STACK v1.1 — ADMIN CHEATSHEET
Назначение:
Быстрые команды для обслуживания сервера без поиска по документации.

Статус: Production Ready
Версия: v1.1

━━━━━━━━━━━━━━━━━━

📂 1. Основные пути
━━━━━━━━━━━━━━━━━━

Проект:

Bash

cd /opt/hermes-stack
Данные:

text

/opt/hermes-stack/data
Бэкапы:

text

/opt/hermes-backups
Переменные окружения:

text

/opt/hermes-stack/.env
(права должны быть 600)
max2tg:

text

/root/max2tg

Проверить текущую папку:

Bash

pwd
Ожидается:

text

/opt/hermes-stack
━━━━━━━━━━━━━━━━━━

🐙 2. GitHub
━━━━━━━━━━━━━━━━━━

Проверить состояние:

Bash

git status
Получить обновления:

Bash

git pull
Отправить изменения:

Bash

git push origin main
Посмотреть последние коммиты:

Bash

git log --oneline -10
Текущая ветка:

Bash

git branch
⚠ Откат к GitHub (полный сброс):

Bash

git reset --hard origin/main
Проверка compose перед запуском:

Bash

docker compose config > /dev/null
Если ошибок нет:

Bash

docker compose up -d
━━━━━━━━━━━━━━━━━━

🐳 3. Docker
━━━━━━━━━━━━━━━━━━

Статус сервисов:

Bash

docker compose ps
Статус контейнеров:

Bash

docker ps
Запуск / применение изменений:

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
Логи max2tg:

Bash

docker logs -f max2tg-max2tg-1
Нагрузка:

Bash

docker stats --no-stream
━━━━━━━━━━━━━━━━━━

🛡 4. Health Check
━━━━━━━━━━━━━━━━━━

Статус Hermes:

Bash

docker inspect hermes --format '{{.State.Health.Status}}'
Статус Open Notebook:

Bash

docker inspect open-notebook --format '{{.State.Health.Status}}'
Статус max2tg:

Bash

docker inspect max2tg-max2tg-1 --format '{{.State.Status}}'
Полная проверка:

Bash

docker compose ps
Ожидается:

text

hermes          healthy
open-notebook   healthy
surrealdb       Up
max2tg          running
━━━━━━━━━━━━━━━━━━

🌐 5. Проверка сервисов (HTTP)
━━━━━━━━━━━━━━━━━━

Hermes:

Bash

curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8020
Notebook UI:

Bash

curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8502
Notebook API:

Bash

curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:5055
Нормально:

text

200
307
200
━━━━━━━━━━━━━━━━━━

🛡 6. Мониторинг
━━━━━━━━━━━━━━━━━━

Файл мониторинга:

text

/opt/hermes-stack/iron_monitor.sh
Ручной запуск:

Bash

bash /opt/hermes-stack/iron_monitor.sh
Проверка cron:

Bash

crontab -l
Файл состояния:

text

/opt/hermes-stack/.monitor_state
━━━━━━━━━━━━━━━━━━

💾 7. Бэкапы
━━━━━━━━━━━━━━━━━━

Создать бэкап:

Bash

bash /opt/hermes-stack/backup.sh
Посмотреть архивы:

Bash

ls -lh /opt/hermes-backups
Размер архива:

Bash

du -sh /opt/hermes-backups
Восстановление:

Bash

docker compose stop
tar -xzf /opt/hermes-backups/ИМЯ_АРХИВА.tar.gz -C /
docker compose up -d
━━━━━━━━━━━━━━━━━━

🧠 8. Ресурсы сервера
━━━━━━━━━━━━━━━━━━

Память:

Bash

free -h
Диск:

Bash

df -h /
Аптайм:

Bash

uptime
Текущие рабочие значения (июнь 2026):

text

Disk: ~31%
Memory: ~32%
Алерт при:

text

>90% disk
>90% memory
━━━━━━━━━━━━━━━━━━

🗄 9. Данные
━━━━━━━━━━━━━━━━━━

Размер всех данных:

Bash

du -sh /opt/hermes-stack/data
Подробно:

Bash

du -h --max-depth=2 /opt/hermes-stack/data | sort -h
Основные каталоги:

text

/opt/hermes-stack/data/.hermes
/opt/hermes-stack/data/open-notebook
━━━━━━━━━━━━━━━━━━

🧹 10. Очистка Docker
━━━━━━━━━━━━━━━━━━

Размеры:

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
⚠ Опасная команда:

Bash

docker system prune -a --volumes
Использовать только при полном понимании последствий.
━━━━━━━━━━━━━━━━━━

🔐 11. Важные файлы
━━━━━━━━━━━━━━━━━━

Docker Compose:

text

/opt/hermes-stack/docker-compose.yml
Документация:

text

/opt/hermes-stack/STACK.md
Политика агента:

text

/opt/hermes-stack/AGENTS.md
Recovery план:

text

/opt/hermes-stack/RECOVERY.md
Монитор:

text

/opt/hermes-stack/iron_monitor.sh
Backup script:

text

/opt/hermes-stack/backup.sh
max2tg compose:

text

/root/max2tg/docker-compose.yml
━━━━━━━━━━━━━━━━━━

🔌 12. SSH Туннели
━━━━━━━━━━━━━━━━━━

Подключение:

Bash

ssh aeza
LocalForward:

text

8020 → Hermes Dashboard
8502 → Open Notebook UI
5055 → Open Notebook API
━━━━━━━━━━━━━━━━━━

🚑 13. Если что-то сломалось
━━━━━━━━━━━━━━━━━━

Проверить контейнеры:

Bash

docker compose ps
Проверить здоровье:

Bash

docker inspect hermes --format '{{.State.Health.Status}}'
Посмотреть логи:

Bash

docker logs --tail 100 hermes
Проверить ресурсы:

Bash

free -h
df -h /
Проверить Git:

Bash

git status
Проверить YAML:

Bash

docker compose config
Если совсем плохо:

text

Смотреть RECOVERY.md
Восстанавливаться из последнего бэкапа
━━━━━━━━━━━━━━━━━━

🏗 14. Архитектура
━━━━━━━━━━━━━━━━━━

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

max2tg
   ↓
Telegram
━━━━━━━━━━━━━━━━━━

✅ Текущий статус
text

Hermes Stack v1.1
Production Ready
Health Checks Enabled
Docker Auto-Restart Enabled
LLM-Independent Monitoring Enabled
Git Versioned
