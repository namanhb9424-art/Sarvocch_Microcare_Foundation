# SARVOOCCH — Backend & API Infrastructure Audit

**Document Classification:** Backend Systems Architecture  
**Auditor:** Senior Backend & Database Reliability Engineer  
**Date:** 3 November 2026  
**Reference File:** `/Users/vaidik/sarvocch_repo/app.py`  

---

## 1. Architecture Overview

The backend is built as a Flask WSGI application with embedded SQLite persistence (`instance/sarvocch.db`). It contains:
- 40+ HTTP endpoints handling HTML views and JSON REST APIs.
- Full Role-Based Access Control enforced at the route decorator level (`@need("permission")`).
- Embedded ReportLab PDF generation for bilingual sanction letters and NOC certificates.
- Automated migration runner (`migrate(db)`) and initial database seeder (`seed()`).

---

## 2. API Endpoints Catalog

### 2.1 Authentication & Session
- `POST /login`: Authenticates username and password against `users` table. In demo mode, accepts standard passwords (`admin123`, `manager123`, etc.).
- `GET /logout`: Clears session.
- `POST /change-password`: Validates current password and saves PBKDF2 hash.

### 2.2 Financial Calculations & APIs
- `GET /api/emi`: Query params: `amount`, `rate`, `tenure`, `method` (flat vs reducing). Returns JSON with monthly EMI, total interest, and total payable.
- `POST /api/kyc/verify`: Verifies Aadhaar, PAN, and Voter ID numbers. Implements Verhoeff checksum algorithm for 12-digit Aadhaar validation.
- `POST /api/sync`: Receives mobile offline task queues (collections, attendance punches, customer updates) and executes atomic batch reconciliations.

### 2.3 Operational APIs
- `POST /applications/<aid>/action`: Advances application stage (`under_review`, `approved`, `sanctioned`, `disbursed`, `rejected`).
  - **Critical Invariant**: Transitioning to `disbursed` automatically creates an active record in `loans` and inserts month-by-month repayment installments into `schedule`, properly skipping weekends and gazetted holidays.
- `POST /pay/<lid>`: Simulates instant customer UPI repayment. Inserts into `payments` table and updates `schedule` (marks `paid = 1`).
- `POST /loans/<lid>/settle`: Executes early loan closure. Validates foreclosure amount and marks all outstanding installments paid.
- `POST /attendance/punch`: Validates Haversine distance between agent GPS (`lat`, `lng`) and assigned branch coordinates.

---

## 3. Financial Integrity & Decimal Safety

In microfinance, precision loss in EMI calculation leads to portfolio reconciliation discrepancies.
- Flat rate calculation: $\text{Interest} = P \times \frac{r}{100} \times \frac{t}{12}$
- Installment balancing: The last installment absorbs any single-paisa rounding difference to ensure $\sum \text{Principal Installments} \equiv \text{Disbursed Principal}$.
- Negative balances: Checked with $\max(0, \text{balance} - \text{principal})$.
