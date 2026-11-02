# SARVOOCCH — Master Feature Inventory & Functional Specifications

**Document Classification:** Authoritative Product Baseline  
**Auditor:** Principal Software Architect & Product Manager  
**Date:** 3 November 2026  
**Application Name:** SARVOOCCH  

---

## 1. Feature Modules Inventory

### MOD-01: Authentication, Session & User Personas
- Multi-role credential authentication for 5 user tiers.
- Session-based cookie management with secure logout and password update.
- Demo masquerade support for immediate role evaluation.

### MOD-02: Executive & Operational Dashboard
- Live portfolio indicators: Total Disbursed, Total Outstanding, Overdue Volume, Active Borrower Count.
- Interactive branch distribution breakdown.
- Visual status breakdown for pipeline applications and aging overdue loans.

### MOD-03: CRM & Borrower Lead Pipeline
- Lead origination with duplicate phone validation.
- Lifecycle stages: Lead -> KYC Completed -> Applied -> Disbursed -> Closed.
- Multi-channel interaction timeline (phone calls, field visits, WhatsApp).
- Printable borrower credential slip with bilingual instructions.

### MOD-04: RBI JLG Bilingual KYC Onboarding
- Comprehensive 3-step digital KYC:
  1. Center & Group registration, guardian details, education, religion, category.
  2. Residence type (Pucca/Semi-pucca/Kutcha), land holding in hectares, livestock inventory, bank account, BPL/APL status.
  3. Husband / Co-applicant identity, written liability consent, and physical residence visit verification.
- Document validation engine (Aadhaar Verhoeff algorithm, PAN format, Voter ID checksum).
- Printable 4-page formal KYC dossier.

### MOD-05: Loan Origination, Cashflow Appraisal & Underwriting
- Multi-product selection with flat and reducing balance calculation methods.
- Comprehensive household income vs. expense breakdown.
- Automated debt-burden risk check (alert when monthly EMI exceeds 60% of verified household income).
- Multi-document checklist (minimum 2 physical documents required).

### MOD-06: Multi-Stage Approval & Disbursement Chain
- Status transitions: `Submitted` -> `Under Review` -> `Approved` -> `Sanctioned` -> `Disbursed` (or `Rejected`).
- Step-by-step audit logging of approver name, role, decision amount, and timestamp.
- Bilingual printable Sanction Letter generated via ReportLab PDF engine.
- Instant loan activation upon disbursement: generates month-by-month repayment schedule skipping non-banking days.

### MOD-07: Loan Servicing, Repayments & Settlement
- Repayment schedule ledger tracking: due dates, EMI, principal component, interest component, and balance.
- Instant UPI QR-code repayment simulation for borrowers.
- Early foreclosure quotation tool: calculates exact payout (outstanding principal + immediate next installment interest).
- Printable bilingual Loan Passbook (ऋण कार्ड).
- Automated No Objection Certificate (NOC) generation upon full loan closure.

### MOD-08: Pre-GRT (Group Recognition Test)
- Formation of 2 to 5 member Joint Liability Groups (JLG).
- Mandatory verification of 7 CGT discipline checks:
  1. Regular attendance at center meetings.
  2. Joint liability mutual guarantee awareness.
  3. Upfront knowledge of processing fees.
  4. Understanding of interest rate and repayment amounts.
  5. Awareness of credit life insurance coverage.
  6. Company identity and purpose awareness.
  7. Understanding of group discipline and peer support.
- Branch manager review workflow (Approve or Return to PSO with remarks).
- Printable Pre-GRT group certificate and roster.
- Batch group loan origination for verified members.

### MOD-09: Field Operations & Mobile Offline Sync
- Field officer itinerary with customer location coordinates and collection targets.
- Cash collection recording: automatically reconciles overdue installments into `payments` and updates `schedule`.
- Resilient offline transaction queue with atomic server synchronization.

### MOD-10: Attendance & Geofenced Punch
- Daily punch-in / punch-out recording.
- Haversine spherical distance calculation validating employee presence within configured branch radius.
- Attendance regularisation request submission and managerial approval workflow.

### MOD-11: Branch Management & Regional Portfolios
- Multi-branch directory with physical address, branch head name, phone, GPS coordinates, and geofence radius.
- Branch-level financial portfolios: active vs. closed loans, total disbursed, outstanding balances, recovery rates.

### MOD-12: Human Resource Management (HRM)
- Employee profiles, salary structures, background check states, and onboarding document attachments.
- Leave application and managerial approval pipeline.
- Quarterly employee performance evaluations (1 to 5 star ratings with observation notes).
- Monthly automated payroll calculation factoring in attendance loss of pay (LOP), HRA, and PF deductions.

### MOD-13: WhatsApp Communication Hub
- Integrated customer messaging hub.
- 6-digit OTP generation and click-to-chat `wa.me` links for mobile verification.
- Two-way verification logging in customer communication audit trails.

### MOD-14: Admin Policies & System Configuration
- Configurable MFI lending rules: minimum/maximum borrower age, group size limits, maximum household income, max EMI ratio, GST rate, and attendance geofence radius.
- Automated demo database re-seeding tool.
