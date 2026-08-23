

## Доступ к Dashboard

Dashboard (порт 9119) и Gateway API (порт 8642) публикуются **только на 127.0.0.1** сервера — наружу не торчат. Это осознанно: Basic Auth по HTTP без TLS небезопасен для публичного порта.

Подключение с локальной машины (MacBook / ПК):
```bash
ssh -L 9119:127.0.0.1:9119 -L 8642:127.0.0.1:8642 root@89.22.234.108
```
Затем открыть в браузере: http://127.0.0.1:9119

## Troubleshooting (v20+)

**PermissionError: /opt/data/logs/agent.log, gateway в crash-loop**
Внутри образа v20 процессы работают под non-root пользователем hermes (uid/gid 10000). Если каталог данных копировался или создавался под root — поправить права:
```bash
chown -R 10000:10000 /opt/hermes-stack/hermes-v20-data
docker compose up -d --force-recreate hermes
```

**WARN ... variable is not set для HERMES_DASH_PASSWORD / SECRET**
Устаревшие имена переменных из v14. Использовать `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` / `_SECRET` / `_USERNAME` — см. `.env.example`.
