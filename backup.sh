#!/bin/bash

set -e

BACKUP_DIR="/opt/hermes-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

mkdir -p "$BACKUP_DIR"

cd /opt/hermes-stack

tar \
  --exclude='data/.cache' \
  --exclude='data/.local' \
  --exclude='data/.hermes/cache' \
  --exclude='data/.hermes/image_cache' \
  --exclude='data/.hermes/audio_cache' \
  -czf \
  "$BACKUP_DIR/hermes-stack-full-$TIMESTAMP.tar.gz" \
  docker-compose.yml \
  STACK.md \
  AGENTS.md \
  CHEATSHEET.md \
  RECOVERY.md \
  .env \
  data

find "$BACKUP_DIR" \
  -name "hermes-stack-full-*.tar.gz" \
  -mtime +14 \
  -delete