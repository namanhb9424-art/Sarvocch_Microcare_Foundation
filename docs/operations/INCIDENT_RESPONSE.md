# SARVOOCCH — Incident Response & Triage Protocol

**Document Classification:** SRE & Incident Management  
**Date:** 3 November 2026  

---

## 1. Severity Classifications

- **SEV-1 (Critical)**: Total system outage, database corruption, failure of loan disbursement or collection recording across multiple branches. Response time: < 15 minutes.
- **SEV-2 (High)**: Major workflow failure (e.g., Pre-GRT group approval blocked, WhatsApp OTP failure, GPS punch failure). Response time: < 1 hour.
- **SEV-3 (Medium)**: Non-blocking UI defect, cosmetic discrepancy, single-client connectivity issue. Response time: < 4 hours.

---

## 2. Emergency Operational Playbook

### 2.1 Web Server Down (502 / Connection Refused)
1. Verify port listener: `lsof -i :5001` or `docker ps`
2. Check recent application exceptions: `tail -n 100 instance/app.log`
3. Restart process using `./scripts/restart_server.sh` or `docker-compose restart sarvoocch-web`

### 2.2 Payment / Collection Discrepancy
1. Locate payment transaction reference in `payments` table.
2. Cross-reference `schedule.paid` status and `loans.outstanding`.
3. If cash was collected offline, trigger manual reconciliation via `/sync` or execute corrective journal entry.
