#!/usr/bin/env bash
# =============================================================================
# backup-to-mac.sh
#
# Инкрементальный бэкап excess-salmon → домашний MacBook (HDD 'Home').
#
# Запускается ВРУЧНУЮ на СЕРВЕРЕ перед снятием образа/снапшота, НЕ через cron
# (Mac выключается). По кнопке: bash /opt/hermes-stack/scripts/backup-to-mac.sh
#
# Что копирует (3 цели):
#   1. /opt/hermes-stack            (git+compose+env+скрипты+docs, ~2.2G)
#   2. /opt/data                    (профили агентов, сессии, навыки, auth.json)
#   3. /root/open-notebook/surreal_data  (RAG-база SurrealDB, 1-3G)
#
# Куда: <MAC_USER>@<MAC_HOST>:/Volumes/Home/Backups/hermes/<YYYY-MM-DD>/{stack,data,rag}/
#
# Метод: rsync -a --delete --link-dest=<предыдущая копия>.
#   - новые/изменённые файлы копируются,
#   - неизменённые — hardlink на предыдущую копию (экономит место).
#
# Лог: /var/log/hermes-backup-mac.log
# Ротация: 7 последних копий (запускается rotate-mac-backups.sh в конце).
#
# Зависимости: bash >=4, rsync, ssh, date, find, sort, tail, sshpass нет — ключ.
# Требования: SSH-ключ /root/.ssh/mac_backup_key добавлен в
#             <MAC_USER>@<MAC_HOST>:~/.ssh/authorized_keys.
# =============================================================================

set -euo pipefail

# ---------- конфигурация ------------------------------------------------------
MAC_USER="${HERMES_BACKUP_MAC_USER:-igor}"
MAC_HOST="${HERMES_BACKUP_MAC_HOST:-mac.local}"
MAC_DEST_BASE="${HERMES_BACKUP_MAC_DEST:-/Volumes/Home/Backups/hermes}"
SSH_PORT="${HERMES_BACKUP_SSH_PORT:-22}"
SSH_KEY="${HERMES_BACKUP_SSH_KEY:-/root/.ssh/mac_backup_key}"
LOG_FILE="/var/log/hermes-backup-mac.log"
KEEP_DAYS=7

STACK_SRC="/opt/hermes-stack"
DATA_SRC="/opt/hermes-stack/hermes-v20-data"
RAG_SRC="/root/open-notebook/surreal_data"

# что исключать (через --exclude)
STACK_EXCLUDES=(
  "--exclude=data/"
  "--exclude=*.log"
  "--exclude=.git/objects/pack/*.tmp"
)
DATA_EXCLUDES=(
  "--exclude=.cache/"
  "--exclude=patchright-browsers/"
  "--exclude=logs/"
  "--exclude=.npm/_logs/"
  "--exclude=audio_cache/"
  "--exclude=image_cache/"
  "--exclude=**/__pycache__/"
)

# ---------- утилиты -----------------------------------------------------------
log()  { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE" ; }
fail() { log "ERROR: $*"; exit 1; }

on_exit() {
  local rc=$?
  if [[ $rc -eq 0 ]]; then
    log "OK: бэкап завершён успешно"
  else
    log "FAIL: бэкап упал с кодом $rc"
  fi
}
trap on_exit EXIT

# ---------- предисловия -------------------------------------------------------
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || \
  fail "не могу создать $(dirname "$LOG_FILE") (нужен root)"

command -v rsync >/dev/null 2>&1 || fail "rsync не найден"
command -v ssh   >/dev/null 2>&1 || fail "ssh не найден"
[[ -r "$SSH_KEY" ]] || fail "SSH-ключ $SSH_KEY не читается (сгенерируй ssh-keygen -t ed25519 -f $SSH_KEY -N '' и добавь .pub в authorized_keys на Mac)"

# Проверка исходников
[[ -d "$STACK_SRC" ]] || fail "источник $STACK_SRC не существует"
[[ -d "$DATA_SRC"   ]] || fail "источник $DATA_SRC не существует"
[[ -d "$RAG_SRC"    ]] || fail "источник $RAG_SRC не существует (SurrealDB RAG)"

# Проверка места назначения: Mac должен быть доступен и держать том.
SSH_TARGET="${MAC_USER}@${MAC_HOST}"
SSH_OPTS=(-i "$SSH_KEY" -p "$SSH_PORT" \
  -o BatchMode=yes -o ConnectTimeout=10 \
  -o StrictHostKeyChecking=accept-new)

log "Проверяю доступность $SSH_TARGET (порт $SSH_PORT)..."
if ! ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "test -d '$MAC_DEST_BASE' || mkdir -p '$MAC_DEST_BASE'" 2>>"$LOG_FILE"; then
  fail "не удалось подключиться по SSH к $SSH_TARGET или создать $MAC_DEST_BASE. Проверь ключ, сеть и монтирование /Volumes/Home на Mac."
fi
log "OK: $SSH_TARGET доступен, $MAC_DEST_BASE готов"

# ---------- расчёт даты и предыдущей копии -----------------------------------
TODAY="$(date +%Y-%m-%d)"
DEST_ROOT="${MAC_DEST_BASE}"
DEST_TODAY="${DEST_ROOT}/${TODAY}"

# Найти предыдущую (самую свежую до сегодня) копию для --link-dest
PREV_COPY="$(ssh "${SSH_OPTS[@]}" "$SSH_TARGET" \
  "find '$DEST_ROOT' -maxdepth 1 -mindepth 1 -type d -name '20*' | sort | tail -n 1" 2>/dev/null || true)"
PREV_COPY="${PREV_COPY%$'\r'}"  # strip CR если есть

if [[ -n "$PREV_COPY" && "$PREV_COPY" == "$DEST_TODAY" ]]; then
  # На всякий случай: если сегодня уже бэкапили — не плодим копию
  log "WARN: копия за $TODAY уже существует ($DEST_TODAY). Пропускаю."
  exit 0
fi

LINK_DEST_ARGS=()
if [[ -n "$PREV_COPY" ]]; then
  LINK_DEST_ARGS=(--link-dest="$PREV_COPY")
  log "Предыдущая копия для hardlink: $PREV_COPY"
else
  log "Предыдущих копий не найдено — будет полная копия"
fi

# ---------- цели --------------------------------------------------------------
# Триплет: SRC | DEST_SUBDIR | EXCLUDES...
run_target() {
  local src="$1" sub="$2"
  shift 2
  local dest="${DEST_TODAY}/${sub}"
  local remote_dest="${SSH_TARGET}:${dest}"
  log "--- ${sub}: ${src} → ${remote_dest} ---"
  # создаём подпапку на Mac
  ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "mkdir -p '$dest'" 2>>"$LOG_FILE"

  # ВАЖНО: rsync с trailing-slash на src копирует содержимое, без — сам каталог.
  # Используем "${src}/" чтобы в dest попало *содержимое* исходного каталога.
  rsync -a --delete \
        "${LINK_DEST_ARGS[@]}" \
        "$@" \
        -e "ssh ${SSH_OPTS[*]}" \
        "${src}/" "${remote_dest}/" 2>>"$LOG_FILE"
  log "OK: ${sub} → ${dest}"
}

# ---------- основной цикл -----------------------------------------------------
log "============================================================"
log "Старт бэкапа excess-salmon → ${SSH_TARGET}:${DEST_TODAY}"
log "============================================================"

run_target "$STACK_SRC" "stack" "${STACK_EXCLUDES[@]}"
run_target "$DATA_SRC"   "data"  "${DATA_EXCLUDES[@]}"
run_target "$RAG_SRC"    "rag"

# ---------- отчёт по объёму ---------------------------------------------------
log "Размеры на Mac:"
ssh "${SSH_OPTS[@]}" "$SSH_TARGET" \
  "du -sh '$DEST_TODAY'/* 2>/dev/null" 2>>"$LOG_FILE" | tee -a "$LOG_FILE"

# ---------- ротация ------------------------------------------------------------
log "Запускаю ротацию (оставляю ${KEEP_DAYS} последних копий)..."
if ! bash "$(dirname "$(readlink -f "$0")")/rotate-mac-backups.sh"; then
  log "WARN: rotate-mac-backups.sh вернул ошибку, бэкап всё равно считаем успешным"
fi

log "Готово. Папка: ${DEST_TODAY}"
exit 0
