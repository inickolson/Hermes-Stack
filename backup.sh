#!/bin/bash

set -e

BACKUP_DIR="/opt/hermes-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

mkdir -p "$BACKUP_DIR"

cd /opt/hermes-stack

tar -czf \
"$BACKUP_DIR/hermes-stack-full-$TIMESTAMP.tar.gz" \
docker-compose.yml \
STACK.md \
AGENTS.md \
.env \
data

find "$BACKUP_DIR" \
-name "hermes-stack-full-*.tar.gz" \
-mtime +14 \
-delete
