# SARVOOCCH — Role Test Accounts & Credentials Specification

**Document Classification:** Internal Test Credentials & Access Manual  
**Auditor:** DevSecOps & QA Lead  
**Date:** 3 November 2026  
**Application Name:** SARVOOCCH  

---

## 1. Demo Credentials Matrix

The platform includes 5 pre-configured demonstration accounts representing each tier of the microfinance operational hierarchy. These accounts can be tested directly in both the Web application (`http://127.0.0.1:5001/login`) and the Flutter mobile application.

| Role Code | Role Title | User Name | Username | Password | Branch Assignment | Primary Responsibilities |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `admin` | System Administrator | Aarav Admin | `admin` | `admin123` | Head Office (Indore) | Global KPI tracking, MFI lending limits, branch config, database reset |
| `manager` | Branch Manager | Meera Manager | `manager1` | `manager123` | Indore - Vijay Nagar | Pre-GRT group verification, loan approval chain, staff leaves |
| `underwriter` | Credit Underwriter | Uday Underwriter | `uw1` | `uw123` | Head Office (Indore) | Risk analysis, debt-to-income limits (<=60%), loan sanctioning |
| `field_agent` | Field Officer / PSO | Ravi Field Officer | `agent1` | `agent123` | Indore - Vijay Nagar | Bilingual customer KYC, GPS attendance punch, field collections |
| `customer` | Borrower / Customer | Sunita Verma | `cust1` | `cust123` | Indore - Vijay Nagar | Self-service portal, UPI repayment simulation, NOC download |

---

## 2. In-App Quick Role Switcher (Mobile)

On the Flutter mobile application:
- Tap the **Role Chip / Switcher Icon** in the top-right corner of the AppBar at any time.
- The **Demo Role Switcher Bottom Sheet** opens showing all available accounts with their roles, branches, and avatars.
- Selecting any role automatically updates authentication state and executes a safe stack reset (`Navigator.pushNamedAndRemoveUntil`) routing to the appropriate home screen (`/portal` for customers, `/dashboard` for internal staff).

---

## 3. Production Security Notice

> [!CAUTION]
> The plain-text demo passwords listed above are strictly intended for offline development, local staging, and demonstrative evaluation.
> In a production release, the environment variable `DISABLE_DEMO_LOGINS=1` must be set, forcing all authentication through cryptographically salted PBKDF2 hashes with mandatory complex passwords.
