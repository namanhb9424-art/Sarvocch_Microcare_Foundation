# SARVOOCCH — Role-by-Role Manual Verification & Testing Guide

**Document Classification:** QA Manual & Scenario Playbook  
**Auditor:** Senior QA Automation Engineer  
**Date:** 3 November 2026  
**Application Name:** SARVOOCCH  

---

## 1. Test Scenario 1: Field Officer (PSO) Onboarding & Attendance
- **Account**: `agent1` / `agent123` (Ravi Field Officer)
- **Step 1 - Attendance**: Navigate to **Attendance & Geofence** (`/attendance`). Tap **Punch IN**. Verify GPS coordinates are within 2000m radius of Vijay Nagar branch. Verify status records `Present`.
- **Step 2 - Bilingual KYC**: Navigate to **New Customer (KYC)** (`/kyc-form`).
  - Fill Applicant: Center `C-101`, Group `G-A`.
  - Enter Husband details: Name `Ramesh Verma`, tick **Husband Consent** checkbox.
  - Tick **Physical Residence Visited**. Submit form. Verify success snackbar.
- **Step 3 - Loan Origination**: Navigate to **New Loan Application** (`/apply`).
  - Select newly created applicant.
  - Select product **General Micro Loan** (18% interest, reducing balance).
  - Verify real-time EMI calculation and cashflow ratio (must be <= 60%).
  - Deposit minimum 2 documents (Aadhaar + Voter ID). Submit application.

---

## 2. Test Scenario 2: Credit Underwriter Risk Assessment & Sanction
- **Account**: `uw1` / `uw123` (Uday Underwriter)
- **Step 1 - Review Application**: Navigate to **Applications** (`/applications`). Tap on the newly submitted application.
- **Step 2 - Risk Audit**: Inspect verified income vs. expense breakdown. Verify that EMI-to-income ratio does not exceed the 60% threshold.
- **Step 3 - Advance Stage**: Tap **Advance Stage**. Select `Approved`, then `Sanctioned`. Download bilingual Sanction Letter PDF.

---

## 3. Test Scenario 3: Branch Manager Pre-GRT & Disbursement
- **Account**: `manager1` / `manager123` (Meera Manager)
- **Step 1 - Pre-GRT Verification**: Navigate to **Pre-GRT (Group Form)** (`/pregrt`). Tap group card. Inspect 7 CGT discipline checks for all members.
- **Step 2 - Manager Sign-off**: Tap **Verify & Approve**. Enter remarks and confirm. Group status changes to `VERIFIED`.
- **Step 3 - Loan Disbursement**: Open Sanctioned application. Select **Disburse Loan**.
  - Verify that the active loan is created in `loans`.
  - Verify that month-by-month repayment schedule is generated in `schedule`.
  - Verify that customer stage in `customers` updates to `active`.

---

## 4. Test Scenario 4: Field Collection & Cash Reconcile
- **Account**: `agent1` / `agent123` (Ravi Field Officer)
- **Step 1 - Field Tasks**: Navigate to **Field Operations & Sync** (`/field`). Locate overdue borrower installment task.
- **Step 2 - Record Collection**: Tap **Complete**. Enter collected cash amount (e.g. ₹5,200) and collection notes.
- **Step 3 - Verification**: Inspect **Loans & EMI** (`/loans`). Verify that the schedule installment is marked `PAID` with today's date, and payment record exists in `payments`.

---

## 5. Test Scenario 5: Customer Portal & UPI Repayment
- **Account**: `cust1` / `cust123` (Sunita Verma)
- **Step 1 - Self-Service Portal**: Log in. Verify `/portal` displays active loan principal, monthly EMI, and next due date.
- **Step 2 - Instant Repayment**: Tap **Pay EMI via UPI**. Dynamic QR code appears with exact EMI amount. Tap **Simulate Successful UPI Payment**.
- **Step 3 - Passbook & Closure**: Verify upcoming EMI updates. For closed loans, tap **Download NOC** to inspect digital clearance certificate.
