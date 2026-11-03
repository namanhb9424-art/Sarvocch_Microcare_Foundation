# SARVOOCCH — Critical Defects Register & Forensic Resolution Log

**Document Classification:** Engineering Defect Tracking  
**Auditor:** Independent Code Reviewer & QA Lead  
**Date:** 3 November 2026  

---

## 1. Resolved Critical Defects

### DEF-01: Custom Drawer Hardware Back-Button Application Trap
- **Identified Defect**: Navigation drawer previously invoked `Navigator.pushReplacementNamed` across all menu items, dismantling the route history stack. Pressing hardware back on any screen minimized or exited the app.
- **Resolution**: Updated `custom_drawer.dart` to use `pushNamed` for all nested sub-routes, reserving replacement solely for root home destinations (`/dashboard` and `/portal`).

### DEF-02: Missing Back-Button PopScope Protection on Home Dashboards
- **Identified Defect**: Android hardware back button on `/dashboard` and `/portal` caused immediate app termination without user confirmation.
- **Resolution**: Wrapped Scaffolds in Flutter's modern `PopScope(canPop: false)` with an exit confirmation dialog.

### DEF-03: Quick Role Switcher Navigation Desync
- **Identified Defect**: Switching roles in `quick_role_switch_sheet.dart` updated provider state but kept the user on the previous role's view.
- **Resolution**: Added `Navigator.pushNamedAndRemoveUntil` directing `customer` to `/portal` and internal staff to `/dashboard`.

### DEF-04: Hardcoded Interest Rate in Loan Origination
- **Identified Defect**: `apply_loan_screen.dart` hardcoded an interest rate of 18.0% instead of reading the selected product's configured rate and flat/reducing calculation method.
- **Resolution**: Dynamically reads `selectedProduct.rate` and `selectedProduct.method` to calculate live monthly EMI and cashflow debt ratio.

### DEF-05: Disconnection Between Field Collections and Loan Schedules
- **Identified Defect**: Completing a field task in `field_tasks_screen.dart` updated the task record but omitted recording a payment in `payments` and left the loan schedule installment marked unpaid.
- **Resolution**: Updated `_markTaskDone` to locate the first unpaid installment, mark `schedule.paid = 1`, and insert a matching record into `payments`.

### DEF-06: Customer Financial Data Scoping
- **Identified Defect**: `loans_list_screen.dart` displayed all organization loans regardless of the logged-in role.
- **Resolution**: Added scoped filtering so customers only see their personal loans, and field officers see loans assigned to their portfolio.

---

## 2. In-Progress & Planned Parity Gaps

| ID | Module | Defect / Missing Feature | Priority | Target Fix |
|---|---|---|---|---|
| GAP-01 | Branches | Missing `/branches` directory and configuration screen in Flutter | P1 | Phase 7 |
| GAP-02 | HRM | Missing `/hrm` staff leave, performance, and payroll screens in Flutter | P1 | Phase 7 |
| GAP-03 | WhatsApp | Missing `/whatsapp` OTP click-to-chat verification hub in Flutter | P1 | Phase 7 |
| GAP-04 | Pre-GRT | Missing verified group batch loan application flow (`/pregrt/<pid>/apply`) in Flutter | P1 | Phase 7 |
| GAP-05 | Print | Missing responsive document view/export sheets for Loan Passbook, Login Slip, KYC Dossier | P1 | Phase 7 |
| GAP-06 | Branding | Standardization to strict spelling **SARVOOCCH** across all strings | P0 | Phase 6 & 7 |
