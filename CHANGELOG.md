## [2026-08-20] Миграция Hermes Agent v14 → v20

### Изменено
- Образ обновлён на nousresearch/hermes-agent:latest (v20).
- docker-compose.yml: исправлен дублирующийся ключ YAML (отступ hermes приведен к 2 пробелам).
- .env: переменные авторизации дашборда переименованы под новую схему v20 (HERMES_DASHBOARD_BASIC_AUTH_*).
- docker-compose.yml: обновлены ссылки на переменные окружения дашборда.
- Права на bind-mount /opt/hermes-stack/hermes-v20-data/logs приведены к 10000:10000 (non-root hermes user).
- Порты 8642 (API) и 9119 (dashboard) забинжены на 127.0.0.1 (доступ только через SSH-туннель).

### Известные ограничения
- config.yaml: структура обновлена до v34 через hermes doctor --fix.

