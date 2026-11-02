# SARVOOCCH — Website Reverse Engineering & Functional Audit

**Document Classification:** Authoritative Requirements Baseline  
**Auditor:** Senior Flask & Financial Systems Engineering Group  
**Date:** 3 November 2026  
**Reference Source:** `/Users/vaidik/sarvocch_repo/app.py` (3,090 lines) & `/Users/vaidik/sarvocch_repo/templates/` (38 templates)  

---

## 1. Executive Summary

This document establishes the exhaustive reference catalog of every route, workflow, database interaction, security restriction, and template in the **SARVOOCCH** reference web application.

The web application functions as the single source of truth for all business terminology, validation thresholds, calculations, and role-based permissions.

---

## 2. Global Role-Based Access Control (RBAC) Architecture

The application enforces a strict role hierarchy with 5 distinct personas defined in `PERMS`:

```python
PERMS = {
    "admin": {"*"},
    "manager": {
        "dashboard", "crm", "kyc", "apply", "applications", "approve", "disburse",
        "loans", "payments", "field", "employees", "hrm", "whatsapp", "sync",
        "calculator", "products", "kycform", "pregrt", "attendance"
    },
    "underwriter": {
        "dashboard", "crm", "kyc", "applications", "approve", "loans",
        "calculator", "pregrt", "attendance"
    },
    "field_agent": {
        "crm", "kyc", "apply", "applications", "field", "sync",
        "calculator", "whatsapp", "payments", "kycform", "pregrt", "attendance"
    },
    "customer": {
        "portal", "payments", "calculator"
    },
}
```

### Module Navigation (`NAV`):
1. `dashboard` -> "Dashboard" (`/dashboard`) [Icon: `speedometer2`]
2. `portal` -> "My Loans" (`/portal`) [Icon: `wallet2`]
3. `crm` -> "CRM" (`/crm`) [Icon: `people`]
4. `kycform` -> "New Customer (KYC Form)" (`/kyc-form/new`) [Icon: `person-vcard`]
5. `pregrt` -> "Pre-GRT (Group Form)" (`/pregrt`) [Icon: `people-fill`]
6. `apply` -> "New Application" (`/apply`) [Icon: `file-earmark-plus`]
7. `applications` -> "Applications" (`/applications`) [Icon: `files`]
8. `loans` -> "Loans & EMI" (`/loans`) [Icon: `cash-coin`]
9. `kyc` -> "KYC Verify" (`/kyc`) [Icon: `shield-check`]
10. `calculator` -> "EMI Calculator" (`/calculator`) [Icon: `calculator`]
11. `products` -> "Loan Products" (`/products`) [Icon: `box-seam`]
12. `field` -> "Field Operations" (`/field`) [Icon: `geo-alt`]
13. `sync` -> "Offline Sync" (`/sync`) [Icon: `arrow-repeat`]
14. `whatsapp` -> "WhatsApp" (`/whatsapp`) [Icon: `whatsapp`]
15. `employees` -> "Employees" (`/employees`) [Icon: `person-badge`]
16. `hrm` -> "HRM" (`/hrm`) [Icon: `briefcase`]
17. `attendance` -> "Attendance" (`/attendance`) [Icon: `clock-history`]
18. `branches` -> "Branches" (`/branches`) [Icon: `building`]
19. `settings` -> "Settings" (`/settings`) [Icon: `gear`]
20. `users` -> "Users & Roles" (`/users`) [Icon: `key`]

---

## 3. Exhaustive Route Inventory

| Route | Methods | Perm Required | Template / Output | Data Operations & Persistence |
| :--- | :--- | :--- | :--- | :--- |
| `/` | GET | None | Redirect `/dashboard` or `/login` | Session check |
| `/login` | GET, POST | Public | `login.html` | Authenticates against `users` table via `check_password_hash` or demo passwords |
| `/logout` | GET | Authenticated | Redirect `/login` | Clears Flask session |
| `/change-password` | GET, POST | Authenticated | `change_password.html` | Updates password hash in `users` |
| `/dashboard` | GET | `dashboard` | `dashboard.html` | Calculates active loans, disbursements, collections, overdue counts, portfolio by branch |
| `/dashboard/details` | GET | `dashboard` | `dashboard_detail.html` | Drill-down view for KPI tiles (loans, apps, collections) |
| `/calculator` | GET | `calculator` | `calculator.html` | Flat vs reducing EMI calculator |
| `/api/emi` | GET | Public | JSON | Rest API calculation: `amount`, `rate`, `tenure`, `method` |
| `/products` | GET, POST | `products` | `products.html` | Lists & inserts loan products into `products` table |
| `/crm` | GET | `crm` | `crm.html` | Lists leads and borrowers filtered by branch/agent scope |
| `/crm/new` | POST | `crm` | Redirect `/crm` | Inserts lead into `customers` table |
| `/crm/<cid>` | GET | `crm` | `crm_detail.html` | Profile, interaction timeline, linked applications & loans |
| `/crm/<cid>/log` | POST | `crm` | Redirect `/crm/<cid>` | Inserts communication log into `comm_logs` |
| `/crm/<cid>/stage` | POST | `crm` | Redirect `/crm/<cid>` | Updates `stage` in `customers` table |
| `/crm/<cid>/login` | POST | `admin`, `manager` | Redirect `/portal` | Fast masquerade into customer portal |
| `/crm/<cid>/login-slip`| GET | `crm` | `login_slip.html` | Printable customer credential sheet with Hindi translations |
| `/kyc-form/new` | GET, POST | `kycform` | `kyc_form.html` | Complete RBI JLG bilingual onboarding with husband consent |
| `/crm/<cid>/kyc-form` | GET, POST | `kycform` | `kyc_form.html` | Pre-populated KYC form for existing customer |
| `/crm/<cid>/kyc-form/print`| GET | `kycform` | `kyc_print.html` | Printable 4-page formal dossier |
| `/kyc` | GET | `kyc` | `kyc.html` | Document OCR verification queue |
| `/api/kyc/verify` | POST | `kyc` | JSON | Validates Aadhaar (Verhoeff), PAN, or Voter ID checksum |
| `/apply` | GET, POST | `apply` | `apply.html` | Complete loan origination with 60% EMI risk check |
| `/applications` | GET | `applications` | `applications.html` | Filterable list: Submitted, Review, Approved, Sanctioned, Disbursed, Rejected |
| `/applications/<aid>` | GET | `applications` | `application_detail.html`| Full application dossier with approval audit trail |
| `/applications/<aid>/action` | POST | `approve`/`disburse` | Redirect | Advances application stage; if Disbursed -> auto-creates `loans` & `schedule` |
| `/applications/<aid>/sanction.pdf`| GET | `applications`| PDF via ReportLab | Official bilingual sanction letter |
| `/loans` | GET | `loans` | `loans.html` | Tabbed view of Active, Overdue, and Closed loans |
| `/loans/<lid>` | GET | `loans` | `loan_detail.html` | Schedule, repayments list, e-mandate status |
| `/loans/<lid>/card` | GET | `loans` | `loan_card.html` | Printable bilingual Loan Passbook (ऋण कार्ड) |
| `/loans/<lid>/settle` | GET, POST | `loans` | `settle.html` | Foreclosure quote (principal + next interest), records full settlement |
| `/loans/<lid>/noc.pdf` | GET | Authenticated | PDF via ReportLab | No Objection Certificate for closed loans |
| `/loans/<lid>/autopay` | POST | `loans` | Redirect | Sets up eNACH / UPI mandate |
| `/autopay/run` | POST | `admin` | Redirect | Simulates automated batch mandate clearing |
| `/loans/<lid>/demo_backdate`| POST | `admin` | Redirect | Fast backdating tool to simulate overdue aging |
| `/portal` | GET | `portal` | `portal.html` | Customer self-service: active loan summary, upcoming EMI, passbook |
| `/pay/<lid>` | GET, POST | `payments` | `pay.html` | Simulated customer UPI repayment (QR code, ref, instant schedule update) |
| `/field` | GET | `field` | `field.html` | Field officer itinerary, GPS map, collections checklist |
| `/field/assign` | POST | `manager` | Redirect `/field` | Assigns field tasks to specific PSO agents |
| `/field/attendance` | POST | `field` | Redirect `/field` | Records field start/end location |
| `/field/task/<tid>/done` | POST | `field` | Redirect `/field` | Records cash collection, updates task, inserts into `payments` & `schedule` |
| `/attendance` | GET | `attendance` | `attendance.html` | Daily punch log, geofence status against branch lat/lng |
| `/attendance/punch` | POST | `attendance` | Redirect | Punch IN / OUT with GPS distance validation |
| `/attendance/request` | POST | `attendance` | Redirect | Submit attendance regularisation / correction request |
| `/attendance/request/<rid>/decide` | POST | `manager`, `admin` | Redirect | Approve or reject attendance regularisation request |
| `/branches` | GET, POST | `branches` | `branches.html` | List and configure branch locations, GPS coords, allowed radius |
| `/branches/<bid>/details` | GET | `branches` | `branch_detail.html` | Branch portfolio, overdue rates, staff allocation |
| `/employees` | GET, POST | `employees` | `employees.html` | Staff directory, onboarding checklist, document attachments |
| `/employees/<eid>/update` | POST | `employees` | Redirect | Update background check status and employment state |
| `/employees/<eid>/print` | GET | `employees` | `employee_print.html` | Printable Employee ID Form with Hindi bilingual labels |
| `/hrm` | GET | `hrm` | `hrm.html` | Monthly payroll summary, leave approvals, performance ratings |
| `/hrm/leave` | POST | `hrm` | Redirect `/hrm` | Employee leave application |
| `/hrm/leave/<lid>/<action>` | POST | `hrm` | Redirect `/hrm` | Approve or reject staff leave request |
| `/hrm/perf` | POST | `hrm` | Redirect `/hrm` | 1-5 star performance rating with observation notes |
| `/pregrt` | GET | `pregrt` | `pregrt_list.html` | Pre-GRT group formation roster |
| `/pregrt/new` | GET, POST | `pregrt` | `pregrt_form.html` | Form new 2-5 member JLG group with 7 CGT discipline checks |
| `/pregrt/<pid>` | GET, POST | `pregrt` | `pregrt_form.html` | Pre-GRT group detail |
| `/pregrt/<pid>/review` | POST | `manager` | Redirect | Verify & Approve or Return to PSO with remarks |
| `/pregrt/<pid>/print` | GET | `pregrt` | `pregrt_print.html` | Printable Pre-GRT Certificate & Group Member roster |
| `/pregrt/<pid>/apply` | GET, POST | `apply` | `group_apply.html` | Batch loan origination for all verified group members |
| `/whatsapp` | GET | `whatsapp` | `whatsapp.html` | WhatsApp verification hub |
| `/whatsapp/<cid>/send` | POST | `whatsapp` | Redirect | Generates 6-digit OTP and generates `wa.me` click-to-chat URL |
| `/whatsapp/<cid>/verify`| POST | `whatsapp` | Redirect | Verifies OTP, marks customer WhatsApp verified, writes comm log |
| `/sync` | GET | `sync` | `sync.html` | Offline synchronization dashboard and manual sync trigger |
| `/api/sync` | POST | Authenticated | JSON | Reconciles queued mobile transactions with server SQLite |
| `/settings` | GET, POST | `admin` | `settings.html` | System policies: age limits, max household income, max EMI %, GST rate |
| `/users` | GET | `admin` | `users.html` | User listing & credential management |
| `/users/<uid>/role` | POST | `admin` | Redirect `/users` | Update user role and permissions |

---

## 4. Business Validation & Financial Invariants

1. **Borrower Eligibility**:
   - Age must be between `min_age` (default: 18) and `max_age` (default: 55).
   - Household annual income must not exceed `max_household_income` (default: ₹3,00,000).
   - Mobile number must be a valid 10-digit Indian number starting with 6-9.
2. **Loan Underwriting & Risk**:
   - Monthly EMI must not exceed `max_emi_pct` (default: 60%) of verified monthly household income.
   - At least 2 documents must be deposited (Aadhaar, Voter ID, PAN, Passbook, Ration Card).
   - Husband/co-applicant consent is required under RBI JLG guidelines.
3. **Financial Math**:
   - Flat Interest: $\text{EMI} = \frac{P + (P \times r \times t / 1200)}{t}$
   - Reducing Balance: $\text{EMI} = P \times \frac{r_m (1 + r_m)^t}{(1 + r_m)^t - 1}$ where $r_m = \frac{r}{1200}$
   - Repayment schedule automatically skips weekends (Saturday/Sunday) and gazetted holidays.
   - Early Settlement: $\text{Settlement} = \text{Remaining Principal} + \text{Interest of immediate next installment}$.
4. **Attendance Geofencing**:
   - Field officer punch coordinates are validated using Haversine spherical distance against assigned branch coordinates (`radius_m`, default 2000m).
