#!/bin/bash
# iron_monitor.sh v2.1 — self-healing monitor (excess-salmon)
# Источник правды: github.com/inickolson/Hermes-Stack (GitOps)
# Cron: */5. LLM-независим.
# .env.monitor: TOKEN, CHAT_ID, AUTO_FIX=0/1 (default 1)
# Тест без побочных действий:
#   DRY_RUN=1 STATE_FILE=/tmp/s INCIDENT_LOG=/tmp/i bash iron_monitor.sh

source /opt/hermes-stack/.env.monitor
AUTO_FIX="${AUTO_FIX:-1}"
DRY_RUN="${DRY_RUN:-0}"
[ "$DRY_RUN" = "1" ] && AUTO_FIX=0
STATE_FILE="${STATE_FILE:-/opt/hermes-stack/.monitor_state}"
INCIDENT_LOG="${INCIDENT_LOG:-/opt/hermes-stack/logs/iron_incidents.log}"
mkdir -p "$(dirname "$INCIDENT_LOG")"
log() { echo "$(date -Is) $*" >> "$INCIDENT_LOG"; }

FAILED=""; FIXED=""

alert() {  # $1 = текст (переносы строк как %0A)
    if [ "$DRY_RUN" = "1" ]; then echo "DRY_RUN alert: $1"; return; fi
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID&text=$1" > /dev/null
}

check_container() {
    local c="$1"
    if ! docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null | grep -q true; then
        FAILED+="❌ контейнер $c не запущен%0A"
        if [ "$AUTO_FIX" = "1" ]; then
            if docker start "$c" >/dev/null 2>&1 && sleep 5 && \
               docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null | grep -q true; then
                FIXED+="🔧 $c: docker start — поднялся%0A"; log "autofix: started $c"
            else
                FIXED+="⚠️ $c: docker start НЕ помог%0A"; log "autofix FAILED: $c"
            fi
        fi
    fi
}

check_container hermes
check_container open-notebook
check_container surrealdb

# 1) Война за TG-токен: 2 сигнала — счётчик гейтов + свежая ошибка в логах
if docker inspect -f '{{.State.Running}}' hermes 2>/dev/null | grep -q true; then
    WAR=0
    GW_COUNT=$(docker exec hermes sh -c "ps aux | grep 'gateway run' | grep -v grep | grep -vE 'rc.init|main-wrapper' | wc -l" 2>/dev/null | tr -d ' ')
    GW_COUNT=${GW_COUNT:-0}
    if [ "$GW_COUNT" -gt 1 ]; then
        FAILED+="❌ война за TG-токен: $GW_COUNT гейтов%0A"; WAR=1
    fi
    if docker logs hermes --since=10m 2>&1 | grep -q "Telegram bot token already in use"; then
        FAILED+="❌ TG-токен занят (ошибка в логах за 10 мин)%0A"; WAR=1
    fi
    if [ "$WAR" = "1" ] && [ "$AUTO_FIX" = "1" ]; then
        EXTRA=$(docker exec hermes sh -c 'ls /opt/data/profiles/ 2>/dev/null | grep -v "^default$"' 2>/dev/null)
        [ -z "$EXTRA" ] && EXTRA="server writer coder marketer seo teacher-en teacher-english"
        for p in $EXTRA; do
            if docker exec hermes hermes -p "$p" gateway stop >/dev/null 2>&1; then
                FIXED+="🔧 стоп лишнего гейта: $p%0A"; log "autofix: gateway stop $p"
            fi
        done
    fi
    # 2) API гейта: проба ИЗНУТРИ контейнера (api_server слушает только localhost
    #    в контейнере, с хоста через docker-proxy всегда RST — это НЕ сбой).
    #    Любой HTTP-код (200/401/404) = жив; 000/пусто = мёртв.
    CODE=$(docker exec hermes sh -c "curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://127.0.0.1:8642/" 2>/dev/null)
    if [ "$CODE" = "000" ] || [ -z "$CODE" ]; then
        FAILED+="❌ API гейта :8642 не отвечает (контейнер жив, гейт мёртв)%0A"
    fi
fi

# 3) Диск
DISK=$(df / | awk 'NR==2{gsub("%",""); print $5}')
[ "${DISK:-0}" -ge 85 ] && FAILED+="⚠️ диск / на ${DISK}%25 (порог 85)%0A"

# 4) Свежесть бэкапов (молчание бэкапов невидимо)
NEWEST_B=$(ls -t /opt/hermes-backups/*.tar.gz 2>/dev/null | head -1)
if [ -n "$NEWEST_B" ]; then
    AGE_D=$(( ($(date +%s) - $(stat -c %Y "$NEWEST_B")) / 86400 ))
    [ "$AGE_D" -ge 7 ] && FAILED+="⚠️ свежий бэкап старше ${AGE_D} дн.%0A"
else
    FAILED+="⚠️ в /opt/hermes-backups нет ни одного tar.gz%0A"
fi

# ---- машина состояний (анти-спам: алерт только при смене состояния) ----
[ -f "$STATE_FILE" ] && LAST_STATE=$(cat "$STATE_FILE") || LAST_STATE="OK"

if [ -n "$FAILED" ]; then
    if [ "$LAST_STATE" != "DOWN" ]; then
        alert "🚨 СБОЙ:%0A$FAILED$FIXED"
        echo "DOWN" > "$STATE_FILE"
        log "DOWN: $(echo "$FAILED$FIXED" | sed 's/%0A/; /g')"
    fi
else
    if [ -n "$FIXED" ]; then
        alert "🔧 АВТОПОЧИНКА (сбой устранён в этом же цикле):%0A$FIXED"
    fi
    if [ "$LAST_STATE" = "DOWN" ]; then
        alert "✅ ВСЁ ВОССТАНОВЛЕНО"
        log "recovered"
    fi
    echo "OK" > "$STATE_FILE"
fi
