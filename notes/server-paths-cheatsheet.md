# Server Cheatsheet — excess-salmon (89.22.234.108)

> Сервер: excess-salmon.ptr.network (89.22.234.108) | ОС: Ubuntu | Юзер: root
> GitHub: https://github.com/inickolson/Hermes-Stack
> Этот файл — шпаргалка с путями, чтобы не искать каждый раз find / -name ...

---

## Ключевые пути (проверено 2026-08-27)

### Конфиги

| Что | Путь | Назначение |
|-----|------|------------|
| Активный config.yaml | /opt/hermes-stack/hermes-v20-data/config.yaml | То, что читает гейтвей (актуально) |
| config.yaml в data | /opt/hermes-stack/data/.hermes/config.yaml | Альтернативная копия |
| config.yaml в hermes | /opt/hermes-stack/data/.hermes/config/config.yaml | Дубликат |
| Конфиг от host | /root/.hermes/config.yaml | НЕ читается гейтвеем (ловушка) |
| .env со всеми ключами | /opt/hermes-stack/.env | Ключи API |

Ловушка двух конфигов: hermes config set на хосте пишет в /root/.hermes/config.yaml,
но гейтвей читает /opt/hermes-stack/hermes-v20-data/config.yaml. Всегда правь второй!

### Open Notebook

| Что | Путь |
|-----|------|
| Данные SurrealDB | /root/open-notebook/surreal_data |
| Backup rsync-таргет | /opt/hermes-backups (7 дней ротация) |
| Daily auth backup | /opt/hermes-backups (воскресенье 03:30) |

### Стек v20

| Что | Путь |
|-----|------|
| Репо клона | /opt/hermes-stack (inickolson/Hermes-Stack) |
| Дашборд v20 | порты 8642 и 9119 (8020 мёртв) |
| FreeLLMAPI | PM2 :3001 (API) + :5173 (vite UI) |
| Монитор | /opt/hermes-stack/scripts/iron_monitor.sh (cron */5) |

### Routing

| Что | Путь |
|-----|------|
| Routing-таблица | /opt/hermes-stack/routing/free-models-routing.yaml |

---

## Часто используемые команды

ss -tlnp              # что на каком порту
docker ps -a          # контейнеры
cat /opt/hermes-stack/hermes-v20-data/config.yaml  # конфиг гейтвея
pm2 list              # FreeLLMAPI
df -h /               # диск
ls -la /opt/hermes-backups/  # бэкапы

---

## НЕ ТРОГАТЬ (системные, иначе сломается)

- /root/.hermes/config.yaml — ловушка, гейтвей не читает
- SurrealDB root-owned — НЕ менять владельца /root/open-notebook/surreal_data
  (иначе crashloop Goodbye)

## История правок

- 2026-08-27 — создан, пути взяты из find / -name config.yaml + памяти
- TODO: добавить точные пути cronов после нахождения
- TODO: добавить имена контейнеров после docker ps
