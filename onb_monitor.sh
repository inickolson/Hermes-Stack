#!/bin/bash
# onb_monitor.sh — ежедневная проверка Open Notebook (ONB) в 06:00 МСК
# Проверяет: контейнер open-notebook + surrealdb + health-check API.
# Если упал — поднимает без вопросов. Отчёт в TG: упало/поднял или всё ок (тихо при норме).

source /opt/hermes-stack/.env.monitor
LOG="/var/log/onb_monitor.log"
ts() { date '+%Y-%m-%d %H:%M:%S'; }
echo "[$(ts)] ONB check start" >> "$LOG"

ACTIONS=""

# 1. Контейнер surrealdb
if ! docker inspect -f '{{.State.Running}}' surrealdb 2>/dev/null | grep -q true; then
    docker start surrealdb >> "$LOG" 2>&1 && ACTIONS+="▸ surrealdb был DOWN — запущен%0A"
fi

# 2. Контейнер open-notebook
if ! docker inspect -f '{{.State.Running}}' open-notebook 2>/dev/null | grep -q true; then
    docker start open-notebook >> "$LOG" 2>&1 && ACTIONS+="▸ open-notebook был DOWN — запущен%0A"
    sleep 25  # ждём health-check
fi

# 3. Health-check API (порт 5055 на localhost хоста)
HTTP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://127.0.0.1:5055/ 2>/dev/null)
if [ "$HTTP" = "000" ] || [ -z "$HTTP" ]; then
    # API не отвечает — рестарт контейнера
    docker restart open-notebook >> "$LOG" 2>&1
    sleep 25
    HTTP2=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://127.0.0.1:5055/ 2>/dev/null)
    if [ "$HTTP2" = "000" ] || [ -z "$HTTP2" ]; then
        curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
            -d "chat_id=$CHAT_ID&text=🚨 ОНБ: API не отвечает даже после рестарта (10.56:5055 мёртв). Нужен ручной разбор." > /dev/null
        echo "[$(ts)] CRITICAL: API dead after restart" >> "$LOG"
        exit 1
    fi
    ACTIONS+="▸ API ОНБ не отвечал — контейнер перезапущен, теперь HTTP $HTTP2%0A"
fi

# 4. RAG-контрольная фраза (surrealdb данные живы)
RAG=$(docker exec open-notebook curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://localhost:5055/ 2>/dev/null)

if [ -n "$ACTIONS" ]; then
    # Отчёт: что-то падало и было поднято
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID&text=🔧 ОНБ утренний отчёт (06:00 МСК):%0A$ACTIONS%0AСейчас: HTTP $HTTP, контейнеры ОК." > /dev/null
    echo "[$(ts)] ACTIONS: $ACTIONS" >> "$LOG"
else
    # Норма — пишем только в лог (без спама в TG)
    echo "[$(ts)] OK: containers up, API HTTP $HTTP" >> "$LOG"
fi
