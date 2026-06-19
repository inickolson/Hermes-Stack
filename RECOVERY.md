🚑 Hermes Stack v1.1 — План аварийного восстановления (Recovery Plan)
Этот документ описывает пошаговую процедуру полного восстановления инфраструктуры Hermes Stack с нуля на чистом сервере (или после фатального сбоя).

🛠️ Фаза 1: Подготовка нового сервера
Предполагается чистая ОС: Ubuntu 24.04 LTS

1. Обновление системы и установка базовых утилит:

Bash

apt update && apt upgrade -y
apt install -y git curl tar
2. Установка Docker (официальный скрипт):

Bash

curl -fsSL https://get.docker.com | sh
📥 Фаза 2: Клонирование архитектуры
1. Скачиваем репозиторий проекта в правильную директорию:

Bash

git clone https://github.com/inickolson/Hermes-Stack /opt/hermes-stack
cd /opt/hermes-stack
🔐 Фаза 3: Восстановление секретов
Файл .env исключен из Git в целях безопасности (.gitignore). Его необходимо восстановить вручную.

1. Скопируйте файл .env из надежного хранилища (или распакуйте из конфиг-бэкапа) в корень проекта:

Bash

# Файл должен лежать строго здесь:
/opt/hermes-stack/.env
2. Установите правильные права на чтение (защита секретов):

Bash

chmod 600 /opt/hermes-stack/.env
💾 Фаза 4: Восстановление баз данных (Backup Restore)
Если вы переносите данные со старого сервера, загрузите архив с бэкапом (например, data-20260605-120000.tar.gz) в папку /opt/hermes-backups/.

1. Создайте директорию для бэкапов (если её нет):

Bash

mkdir -p /opt/hermes-backups
2. Распакуйте архив с данными в папку проекта:

Bash

cd /opt/hermes-stack
tar -xzf /opt/hermes-backups/ИМЯ_ВАШЕГО_БЭКАПА.tar.gz
(Это восстановит папку data/, внутри которой лежат базы SurrealDB, индексы Open Notebook и сессии Hermes).

🚀 Фаза 5: Запуск стека
1. Запустите все сервисы в фоновом режиме:

Bash

cd /opt/hermes-stack
docker compose up -d
(При первом запуске Docker скачает все необходимые образы, это может занять несколько минут).

🩺 Фаза 6: Проверка работоспособности (Verification)
1. Проверьте статус контейнеров:

Bash

docker compose ps
✅ Ожидаемый результат:

text

NAME            IMAGE                            STATUS
hermes          hermes-stack-hermes              Up ... (healthy)
open‑notebook   lfnovo/open_notebook:v1‑latest   Up ... (healthy)
surrealdb       surrealdb/surrealdb:v2           Up ... 
(Примечание: статус healthy может появиться не сразу, а через 30‑40 секунд после запуска).

2. Проверьте логи на отсутствие критических ошибок:

Bash

docker compose logs --tail 50
3. Проверьте внутреннюю сеть (HTTP Probes):

Bash

curl -I http://127.0.0.1:8020  # Hermes (ожидаем 200 или 405)
curl -I http://127.0.0.1:8502  # Notebook (ожидаем 307)
4. Финальный тест:
Напишите Telegram‑боту: Сделай поиск через rag_ask по фразе "фиолетовый кактус 713". Если ответ получен — система восстановлена на 100%. 🎉

## max2tg – сервис мониторинга и управления

max2tg – это Telegram‑бот, запущенный как Docker‑контейнер. Он периодически опрашивает Telegram API и выполняет команды, но не имеет собственного health‑check. Чтобы он не «отваливался» через 30 минут, рекомендуется:

1. **Настройка автоперезапуска** – в `docker‑compose.yml` для сервиса `max2tg` уже указано `restart: unless-stopped`. Убедитесь, что в `docker‑compose.yml` также добавлен `healthcheck`:
   ```yaml
   healthcheck:
     test: ["CMD", "pgrep", "python"]
     interval: 30s
     timeout: 5s
     retries: 3
   ```

2