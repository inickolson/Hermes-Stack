# FreeLLMAPI Integration

## Что это
LLM-роутер: агрегирует бесплатные модели через OpenRouter, Hermes Gateway использует его как fallback.

## Порты и доступ
- API: `http://localhost:3001/v1` (OpenAI-compatible)
- Web UI: `http://localhost:3001` (или :5173 dev)
- Доступ с Mac: `ssh aeza` (проброс 3001)
- Снаружи порт 3001 закрыт хостером

## Файлы
- Код: `/opt/freellmapi`
- Сервис: `/etc/systemd/system/freellmapi-server.service`

## Команды
- Статус сервера: `status-agent`
- Тест API: `freellm`
- Перезапуск: `systemctl restart freellmapi-server`

## Continue.dev
- apiBase: `http://localhost:3001/v1`
- apiKey: реальный ключ `freellmapi-...` (не any/none/123 — иначе 401)

Updated: 2026-08-10
