#!/bin/bash

source /opt/hermes-stack/.env.monitor
STATE_FILE="/opt/hermes-stack/.monitor_state"

FAILED=""

check_container () {
    if ! docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null | grep -q true; then
        FAILED+="❌ $1 не запущен%0A"
    fi
}

check_container hermes
check_container open-notebook
check_container surrealdb

[ -f "$STATE_FILE" ] && LAST_STATE=$(cat "$STATE_FILE") || LAST_STATE="OK"

if [ -n "$FAILED" ]; then
    if [ "$LAST_STATE" != "DOWN" ]; then
        curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID&text=🚨 СБОЙ КОНТЕЙНЕРОВ:%0A$FAILED" > /dev/null
        echo "DOWN" > "$STATE_FILE"
    fi
else
    if [ "$LAST_STATE" == "DOWN" ]; then
        curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID&text=✅ ВСЕ КОНТЕЙНЕРЫ РАБОТАЮТ" > /dev/null
        echo "OK" > "$STATE_FILE"
    fi
fi
