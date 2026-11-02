# SARVOOCCH — Database Schema & Data Integrity Audit

**Document Classification:** Database Architecture  
**Auditor:** Database Architect & Reliability Engineer  
**Date:** 3 November 2026  
**Database Engine:** SQLite 3 (Production Path: `instance/sarvocch.db` • Test Path: In-Memory)  

---

## 1. Relational Schema Summary (24 Tables)

| # | Table Name | Primary Key | Key Foreign Keys | Purpose |
|---|---|---|---|---|
| 1 | `users` | `id` | - | System accounts with RBAC roles (`admin`, `manager`, `underwriter`, `field_agent`, `customer`) |
| 2 | `employees` | `id` | `user_id`, `manager_id` | Staff profiles, designations, branches, salary, onboarding docs |
| 3 | `customers` | `id` | `agent_id` | Borrower leads & customers, KYC statuses, stages |
| 4 | `comm_logs` | `id` | `customer_id` | Interaction history (calls, field visits, WhatsApp) |
| 5 | `products` | `id` | - | Loan products, flat/reducing methods, rates, min/max limits |
| 6 | `applications` | `id` | `customer_id`, `product_id`, `agent_id` | Loan origination pipeline |
| 7 | `app_extra` | `application_id` | `application_id` | Cashflow breakdown, income/expense breakdown, insurance choice |
| 8 | `approvals` | `id` | `application_id` | Step-by-step approval audit trail with remarks |
| 9 | `loans` | `id` | `application_id`, `customer_id`, `product_id` | Active, overdue, and closed loans |
| 10 | `schedule` | `id` | `loan_id` | Installment breakdown (due date, emi, principal, interest, balance, paid) |
| 11 | `payments` | `id` | `loan_id`, `schedule_id` | Payment receipts, collection channel, reference codes |
| 12 | `mandates` | `id` | `loan_id` | eNACH / UPI autopay mandates |
| 13 | `tasks` | `id` | `customer_id`, `loan_id` | Field collection tasks and residence verification visits |
| 14 | `attendance` | `id` | `user_id` | Daily punch-in / punch-out with GPS coordinates |
| 15 | `branches` | `id` | - | Branch directory, GPS coordinates, geofence radius |
| 16 | `holidays` | `day` | - | Gazetted holiday calendar for repayment scheduling |
| 17 | `settings` | `key` | - | Global MFI lending rules & operational thresholds |
| 18 | `att_requests` | `id` | `user_id` | Attendance regularisation & leave requests |
| 19 | `leaves` | `id` | `user_id` | Staff leave requests and management approval pipeline |
| 20 | `perf` | `id` | `user_id` | Quarterly staff performance evaluations & ratings |
| 21 | `sync_log` | `id` | `user_id` | Mobile offline sync idempotency journal |
| 22 | `kyc_forms` | `id` | `customer_id` | Bilingual JLG onboarding details & husband consent |
| 23 | `pregrt` | `id` | `agent_id` | Pre-GRT group formation and branch manager verification |
| 24 | `pregrt_members` | `id` | `pregrt_id`, `customer_id` | Individual group member discipline checks (7 CGT points) |

---

## 2. Integrity Constraints & Foreign Key Rules

1. `schedule.loan_id` references `loans.id` ON DELETE CASCADE.
2. `payments.loan_id` references `loans.id`.
3. `pregrt_members.pregrt_id` references `pregrt.id`.
4. `app_extra.application_id` references `applications.id`.
5. `kyc_forms.customer_id` UNIQUE constraint ensures exactly one comprehensive KYC dossier per customer.
