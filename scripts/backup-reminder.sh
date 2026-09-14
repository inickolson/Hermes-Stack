#!/usr/bin/env bash
# /opt/hermes-stack/scripts/backup-reminder.sh
# Daily Telegram reminder: "сделать бэкап на Mac" в 22:00 MSK
# Запускается из crontab root: 0 22 * * * /opt/hermes-stack/scripts/backup-reminder.sh >/dev/null 2>&1
#
# Токен и chat_id берутся ТОЛЬКО из .env max2tg (там же, где у max2tg).
# Никаких хардкодов — даже chat_id. Всё в .env.

set -u
set -o pipefail

# ── пути/ зависимости ──────────────────────────────────────────────────
SCRIPT_NAME="$(basename "$0")"
LOG_FILE="/var/log/hermes-backup-reminder.log"
ENV_FILE="/root/max2tg/.env"

# curl обязателен
command -v curl >/dev/null 2>&1 || { echo "[$SCRIPT_NAME] curl не найден" >&2; exit 1; }

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

log() {
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u)"
  echo "[$ts] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log "старт"

# ── читаем .env max2tg ────────────────────────────────────────────────
if [[ ! -r "$ENV_FILE" ]]; then
  log "ОШИБКА: $ENV_FILE не читается (нет файла или прав)"
  exit 1
fi

# Подгружаем только те переменные, что нам нужны (без eval).
# Поддерживаем формат KEY=value и KEY="value", и # комментарии.
get_env_var() {
  local key="$1"
  # shellcheck disable=SC1090
  awk -F= -v k="$key" '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    $1 == k {
      sub(/^[^=]*=/, "", $0)
      gsub(/^["'\''[:space:]]+|["'\''[:space:]]+$/, "", $0)
      print
      exit
    }
  ' "$ENV_FILE"
}

TG_BOT_TOKEN="$(get_env_var TELEGRAM_BOT_TOKEN)"
TG_CHAT_ID="$(get_env_var TELEGRAM_CHAT_ID)"

if [[ -z "$TG_BOT_TOKEN" ]]; then
  log "ОШИБКА: TELEGRAM_BOT_TOKEN не найден в $ENV_FILE"
  exit 1
fi

if [[ -z "$TG_CHAT_ID" ]]; then
  # фолбэк: chat_id 1245452617 (домашний канал Игоря)
  TG_CHAT_ID="1245452617"
  log "WARN: TELEGRAM_CHAT_ID не задан в $ENV_FILE, используется дефолт 1245452617"
fi

# ── сообщение ─────────────────────────────────────────────────────────
TEXT="🔔 Напоминалка: пора сделать бэкап на Mac. Выполни: ssh aeza-ai \"/opt/hermes-stack/scripts/backup-to-mac.sh\""

# ── отправка через Telegram Bot API ───────────────────────────────────
# curl --fail-with-body: ненулевой exit на HTTP 4xx/5xx + тело в stderr.
RESPONSE="$(curl --fail-with-body --silent \
  --connect-timeout 10 --max-time 20 \
  -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
  -d chat_id="$TG_CHAT_ID" \
  --data-urlencode "text=$TEXT" \
  -d disable_web_page_preview=true \
  2>&1)" || {
  log "ОШИБКА отправки в TG: $RESPONSE"
  exit 1
}

log "OK: сообщение отправлено в chat_id=$TG_CHAT_ID"
exit 0