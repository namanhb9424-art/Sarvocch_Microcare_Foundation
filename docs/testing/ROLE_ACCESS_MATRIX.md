# SARVOOCCH — Role Access & Permissions Matrix

**Document Classification:** Security & Access Control Specification  
**Auditor:** Application Security & Financial Systems Engineer  
**Date:** 3 November 2026  
**Application Name:** SARVOOCCH  

---

## 1. Full Module Permission Breakdown

| Functional Module | Route / Endpoint | Admin | Branch Manager | Credit Underwriter | Field Agent (PSO) | Customer / Borrower |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| **Executive Dashboard** | `/dashboard` | ✅ FULL | ✅ FULL | ✅ FULL | ❌ DENIED | ❌ DENIED |
| **Customer Portal** | `/portal` | ❌ N/A | ❌ N/A | ❌ N/A | ❌ N/A | ✅ FULL |
| **CRM Customer Roster** | `/crm` | ✅ ALL | ✅ BRANCH | ✅ ALL | ✅ OWN LEADS | ❌ DENIED |
| **Lead Origination** | `/crm/new` | ✅ ALLOW | ✅ ALLOW | ❌ DENIED | ✅ ALLOW | ❌ DENIED |
| **Bilingual KYC Form** | `/kyc-form` | ✅ ALLOW | ✅ ALLOW | ❌ DENIED | ✅ ALLOW | ❌ DENIED |
| **KYC Document Verify** | `/kyc-verify` | ✅ ALLOW | ✅ ALLOW | ✅ ALLOW | ❌ DENIED | ❌ DENIED |
| **New Loan Origination**| `/apply` | ✅ ALLOW | ✅ ALLOW | ❌ DENIED | ✅ ALLOW | ❌ DENIED |
| **Applications Queue** | `/applications` | ✅ ALL | ✅ BRANCH | ✅ ALL | ✅ OWN APPS | ❌ DENIED |
| **Credit Underwriting** | `/applications/<aid>` | ✅ ALLOW | ✅ ALLOW | ✅ ALLOW | ❌ VIEW ONLY | ❌ DENIED |
| **Sanction & Disburse** | `/applications/<aid>/action` | ✅ ALLOW | ✅ ALLOW | ❌ SANCTION ONLY | ❌ DENIED | ❌ DENIED |
| **Loans & Schedules** | `/loans` | ✅ ALL | ✅ BRANCH | ✅ ALL | ✅ ASSIGNED | ✅ OWN ONLY |
| **Foreclosure Settle** | `/loans/<lid>/settle` | ✅ ALLOW | ✅ ALLOW | ❌ DENIED | ❌ DENIED | ✅ ALLOW |
| **UPI Repayments** | `/pay/<lid>` | ✅ SIMULATE | ✅ SIMULATE | ❌ DENIED | ❌ DENIED | ✅ FULL |
| **Pre-GRT Group Form** | `/pregrt` | ✅ ALL | ✅ BRANCH | ✅ ALL | ✅ OWN GROUPS | ❌ DENIED |
| **Pre-GRT Review** | `/pregrt/<pid>/review`| ✅ APPROVE | ✅ APPROVE | ❌ DENIED | ❌ DENIED | ❌ DENIED |
| **Field Operations** | `/field` | ✅ ALL | ✅ ASSIGN | ❌ DENIED | ✅ EXECUTE | ❌ DENIED |
| **Attendance Punch** | `/attendance` | ✅ AUDIT | ✅ AUDIT | ✅ PUNCH | ✅ PUNCH | ❌ DENIED |
| **Branch Directory** | `/branches` | ✅ MANAGE | ✅ VIEW | ❌ DENIED | ❌ DENIED | ❌ DENIED |
| **Staff & HRM** | `/hrm`, `/employees`| ✅ MANAGE | ✅ MANAGE | ❌ DENIED | ❌ DENIED | ❌ DENIED |
| **WhatsApp Hub** | `/whatsapp` | ✅ FULL | ✅ FULL | ❌ DENIED | ✅ ASSIGNED | ❌ DENIED |
| **Policy Settings** | `/settings` | ✅ FULL | ❌ DENIED | ❌ DENIED | ❌ DENIED | ❌ DENIED |
| **User Administration**| `/users` | ✅ FULL | ❌ DENIED | ❌ DENIED | ❌ DENIED | ❌ DENIED |
