#!/bin/bash
BACKUP_DIR="/opt/hermes-backups"
DATE=$(date +%Y%m%d-%H%M%S)
mkdir -p $BACKUP_DIR
cd /opt/hermes-stack
tar czf "$BACKUP_DIR/hermes-stack-daily-$DATE.tar.gz" .
# Хранить 7 дней
find $BACKUP_DIR -name "hermes-stack-daily-*.tar.gz" -mtime +7 -delete
echo "$(date): Daily backup OK ($DATE)" >> /var/log/hermes-backup.log
