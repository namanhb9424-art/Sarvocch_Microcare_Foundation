# SARVOOCCH — Deployment Rollback & Recovery Guide

**Document Classification:** Site Reliability & Operational Continuity  
**Date:** 3 November 2026  

---

## 1. Fast Rollback Procedure

### 1.1 Web Application Rollback
If a defective release is deployed:
1. Identify last verified Git commit:
   ```bash
   git log --oneline -n 5
   ```
2. Checkout stable tag or commit:
   ```bash
   git checkout <stable_commit_hash>
   ```
3. Restart WSGI process:
   ```bash
   kill -HUP $(pgrep -f "gunicorn app:app") || pkill -f "python.*app.py"
   PORT=5001 FLASK_DEBUG=1 python app.py &
   ```

### 1.2 Docker Rollback
```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### 1.3 Database Rollback
If schema migration caused data corruption:
```bash
# Restore previous snapshot from backup
cp instance/backups/sarvocch_db_pre_deploy.bak instance/sarvocch.db
```
