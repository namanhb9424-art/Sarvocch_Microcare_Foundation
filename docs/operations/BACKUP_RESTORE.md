# SARVOOCCH — Database Backup & Disaster Recovery Guide

**Document Classification:** Database Reliability & Disaster Recovery  
**Date:** 3 November 2026  

---

## 1. Automated Snapshot Script
SQLite databases should be backed up using atomic `.backup` or VACUUM commands rather than raw file copies while running:

```bash
#!/bin/bash
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/app/instance/backups"
mkdir -p "$BACKUP_DIR"

sqlite3 /app/instance/sarvocch.db ".backup '$BACKUP_DIR/sarvocch_$TIMESTAMP.db'"
echo "[✓] Snapshot created: $BACKUP_DIR/sarvocch_$TIMESTAMP.db"

# Retain last 7 daily snapshots
find "$BACKUP_DIR" -type f -name "sarvocch_*.db" -mtime +7 -delete
```

---

## 2. Restoration Verification Procedure
1. Stop the web server: `docker-compose stop sarvoocch-web`
2. Replace corrupt database:
   ```bash
   cp /app/instance/backups/sarvocch_target.db /app/instance/sarvocch.db
   ```
3. Run integrity check:
   ```bash
   sqlite3 /app/instance/sarvocch.db "PRAGMA integrity_check;"
   ```
4. Start web server and verify `/dashboard`.
