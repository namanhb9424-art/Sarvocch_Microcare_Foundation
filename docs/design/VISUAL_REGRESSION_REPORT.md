# SARVOOCCH — Visual Regression & Parity Verification Report

**Document Classification:** Visual Quality Gate  
**Auditor:** UI/UX & QA Automation Engineer  
**Date:** 3 November 2026  
**Application Name:** SARVOOCCH  

---

## 1. Scope of Audit

This visual regression audit verifies that:
1. No existing visual components or page hierarchies have been removed or displaced.
2. The core brand colors (`#0F766E` teal, `#0B5E57` dark teal, `#E6F4F2` surface) are strictly maintained across both Web and Flutter applications.
3. Typography uses crisp Google Inter rendering without layout shifts.
4. Mobile screens faithfully adapt desktop tabular layouts into structured mobile cards without omitting fields.

---

## 2. Page-by-Page Comparison & Verification

| Screen / Workflow | Web Implementation | Flutter Implementation | Layout Consistency | Regression Check |
| :--- | :--- | :--- | :--- | :--- |
| **Login View** | Bootstrap centered card with bank branding | Responsive card with official squircle badge logo | **PASS** | No layout shift |
| **Dashboard** | 4 Top KPI tiles + Branch portfolio + pipeline | 4 Top KPI cards + Branch portfolio breakdown | **PASS** | Matching metrics |
| **Customer Portal** | Single-column card layout with instant UPI | Single-column cards with instant UPI QR generator | **PASS** | Full parity |
| **CRM Customer List**| Data table with phone, branch, stage | Searchable list tiles with avatar & stage chips | **PASS** | Adapted for mobile |
| **Bilingual KYC** | 3-tab accordion form with husband consent | 3-step Stepper form with husband consent | **PASS** | All fields preserved |
| **Loan Application** | 3-card form with real-time risk debt-ratio | 3-card form with real-time risk debt-ratio | **PASS** | Calculation matches |
| **Repayments / Loans**| 3 Tab views (Active, Overdue, Closed) | 3 Tab views (Active, Overdue, Closed) | **PASS** | All metrics aligned |
| **Pre-GRT Group** | Expandable group roster with 7 CGT checks | ExpansionTile cards with 7 CGT point badges | **PASS** | Full parity |
| **Field Operations** | Task list with GPS coords & cash collection | Task list cards with GPS coords & cash modal | **PASS** | Zero discrepancy |
| **Attendance Punch** | Branch selection with GPS coordinate readout | Branch picker with live GPS & geofence distance | **PASS** | Accurate calculation |

---

## 3. Final Visual Quality Approval

- **Visual Preservation**: **APPROVED** (100% adherence to established visual identity).
- **Brand Name Compliance**: **APPROVED** (Strict use of **SARVOOCCH**).
- **Design Stability**: **APPROVED** (No unauthorized redesigns, no glassmorphism or distracting animations).
