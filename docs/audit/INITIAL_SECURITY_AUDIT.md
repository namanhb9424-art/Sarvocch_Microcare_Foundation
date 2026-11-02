# SARVOOCCH — Initial Security & Threat Model Audit

**Document Classification:** Application Security Assessment  
**Auditor:** Application Security Engineer & DevSecOps Lead  
**Date:** 3 November 2026  
**Standards:** OWASP Top 10 API Security & RBI Digital Lending Guidelines  

---

## 1. Threat Surface Assessment

### 1.1 Authentication & Credential Storage
- **Current State**: Password hashes generated using Werkzeug's PBKDF2:SHA256 (`scrypt` / `pbkdf2:sha256:600000`). Demo users support convenient password bypass for evaluation.
- **Production Guardrail**: In production deployment, demo passwords MUST be completely disabled via `FLASK_ENV=production` or `DISABLE_DEMO_LOGINS=1`.
- **Session Security**: Session cookies must have `HttpOnly=True`, `SameSite=Lax`, and `Secure=True` in production.

### 1.2 Authorization & Data Scoping
- **Horizontal Access Control**: Field agents and branch staff must be scoped to their assigned branch (`scope_agent()` in Flask and `scopedLoans` in Flutter). Direct IDOR access via `/crm/<cid>` or `/loans/<lid>` must be strictly blocked if the resource belongs to another branch/agent.
- **Vertical Access Control**: Financial actions (`/applications/<aid>/action`, `/settings`, `/branches`) require explicit managerial or administrative privileges.

### 1.3 Sensitive Data Protection & Aadhaar Masking
- **RBI / UIDAI Regulatory Requirement**: Full 12-digit Aadhaar numbers must NEVER be stored in plain text or displayed in unmasked form.
- **Implementation**: The system captures only the last 4 digits in Pre-GRT group rosters (`aadhaar4`) and masks Aadhaar display as `XXXXXXXX1234` on customer profiles and printouts.

---

## 2. Security Action Items

1. **Strict Content Security Policy (CSP)**: Ensure headers prevent unauthorized inline script execution.
2. **Rate Limiting**: Apply rate limiting to login endpoints (`/login`) to mitigate brute-force attempts.
3. **Audit Logging**: Preserve immutable records in `approvals`, `comm_logs`, and `payments` for all balance-impacting events.
