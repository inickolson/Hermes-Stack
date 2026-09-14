#!/usr/bin/env bash
# =============================================================================
# rotate-mac-backups.sh
#
# Ротация бэкапов на Mac: оставляет 7 последних копий hermes-бэкапов,
# удаляет всё старше 7 дней.
#
# Запускается из backup-to-mac.sh в конце, либо вручную:
#   bash /opt/hermes-stack/scripts/rotate-mac-backups.sh
#
# Где работает: на СЕРВЕРЕ, но удаляет на Mac через SSH.
# Логика: ищет на Mac каталоги /Volumes/Home/Backups/hermes/YYYY-MM-DD/,
#         сортирует по имени (= хронология), оставляет 7 свежайших,
#         остальные удаляет (rm -rf на стороне Mac).
#
# Защита от факапов:
#   - требует явного HERMES_BACKUP_MAC_DEST (по умолчанию /Volumes/Home/Backups/hermes)
#   - проверяет что удаляемый путь начинается с HERMES_BACKUP_MAC_DEST
#   - никогда не удаляет корневую папку
# =============================================================================

set -euo pipefail

MAC_USER="${HERMES_BACKUP_MAC_USER:-igor}"
MAC_HOST="${HERMES_BACKUP_MAC_HOST:-mac.local}"
MAC_DEST_BASE="${HERMES_BACKUP_MAC_DEST:-/Volumes/Home/Backups/hermes}"
SSH_PORT="${HERMES_BACKUP_SSH_PORT:-22}"
SSH_KEY="${HERMES_BACKUP_SSH_KEY:-/root/.ssh/mac_backup_key}"
LOG_FILE="/var/log/hermes-backup-mac.log"
KEEP=7

log()  { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE" ; }
fail() { log "ERROR: $*"; exit 1; }

command -v ssh >/dev/null 2>&1 || fail "ssh не найден"
[[ -r "$SSH_KEY" ]] || fail "SSH-ключ $SSH_KEY не читается"

SSH_OPTS=(-i "$SSH_KEY" -p "$SSH_PORT" \
  -o BatchMode=yes -o ConnectTimeout=10 \
  -o StrictHostKeyChecking=accept-new)
SSH_TARGET="${MAC_USER}@${MAC_HOST}"

log "Ротация на ${SSH_TARGET}:${MAC_DEST_BASE} (оставляю ${KEEP} копий)"

# Получаем список каталогов вида YYYY-MM-DD, отсортированных по имени (= по дате).
# Защита: фильтр строго под дату 20YY-MM-DD, чтобы случайно не снести что-то ещё.
mapfile -t ALL_DIRS < <(ssh "${SSH_OPTS[@]}" "$SSH_TARGET" \
  "find '$MAC_DEST_BASE' -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null \
   | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}\$' | sort" 2>/dev/null || true)

COUNT=${#ALL_DIRS[@]}
log "Найдено копий: $COUNT"

if [[ $COUNT -le $KEEP ]]; then
  log "Ротация не требуется (≤ $KEEP)"
  exit 0
fi

# Удаляем самые старые (первые в отсортированном списке)
TO_DELETE=$(( COUNT - KEEP ))
log "Удаляю $TO_DELETE самых старых копий:"
for ((i=0; i<TO_DELETE; i++)); do
  d="${ALL_DIRS[$i]}"
  full="$MAC_DEST_BASE/$d"
  # Двойная защита: имя строго под дату + fullpath начинается с MAC_DEST_BASE
  if [[ ! "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    log "  SKIP (не дата): $d"
    continue
  fi
  log "  rm -rf $full"
  ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "rm -rf '$full'" 2>>"$LOG_FILE"
done

log "Ротация завершена. Осталось копий: $KEEP"
