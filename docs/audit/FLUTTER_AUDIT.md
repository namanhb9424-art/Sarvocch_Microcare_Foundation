# SARVOOCCH — Flutter Mobile Application Audit

**Document Classification:** Mobile Engineering Baseline  
**Auditor:** Principal Flutter Engineer  
**Date:** 3 November 2026  
**Reference Directory:** `/Users/vaidik/sarvocch_app` & `sarvocch_repo/sarvocch_app`  
**Flutter Version:** 3.47.5 (Channel stable) • Dart 3.13.4  

---

## 1. Executive Summary

The **SARVOOCCH** mobile application is a production-grade Flutter application built to mirror the web portal's user experience. It employs an offline-first SQLite database (`sqflite`), Provider-based reactive state management, Google Inter typography, and the `#0F766E` teal brand design system.

Automated analysis (`flutter analyze`) currently passes with **0 errors and 0 warnings** (49 informational deprecation notices).
Integration and user flow test suites (`flutter test test/user_flows_test.dart`) execute with **6/6 tests passing**.

---

## 2. Implemented Screens & Feature Coverage

| Flutter Screen | File Path | Route | Supported Personas | Parity Status |
| :--- | :--- | :--- | :--- | :--- |
| **Splash Screen** | `lib/screens/splash_screen.dart` | `/splash` | All | **MATCHED** |
| **Login Screen** | `lib/screens/login_screen.dart` | `/login` | All | **MATCHED** |
| **Dashboard** | `lib/screens/dashboard_screen.dart` | `/dashboard` | Admin, Manager, Underwriter | **MATCHED** |
| **Customer Portal** | `lib/screens/portal/customer_portal_screen.dart` | `/portal` | Customer | **MATCHED** |
| **CRM Customer List** | `lib/screens/crm/crm_list_screen.dart` | `/crm` | Admin, Manager, Agent | **MATCHED** |
| **CRM Customer Detail** | `lib/screens/crm/crm_detail_screen.dart` | `/crm-detail` | Admin, Manager, Agent | **MATCHED** |
| **Bilingual KYC Form** | `lib/screens/crm/kyc_form_screen.dart` | `/kyc-form` | Admin, Manager, Agent | **MATCHED** |
| **KYC Document Verify** | `lib/screens/kyc_verify/kyc_verify_screen.dart` | `/kyc-verify` | Admin, Manager, Underwriter | **MATCHED** |
| **Pre-GRT Group Form** | `lib/screens/pregrt/pregrt_screen.dart` | `/pregrt` | Admin, Manager, Agent | **PARTIAL** (Missing verified group apply) |
| **New Loan Application**| `lib/screens/applications/apply_loan_screen.dart` | `/apply` | Admin, Manager, Agent | **MATCHED** |
| **Applications Queue** | `lib/screens/applications/applications_screen.dart` | `/applications` | Admin, Manager, Underwriter | **MATCHED** |
| **Application Detail** | `lib/screens/applications/application_detail_screen.dart`| `/application-detail` | Admin, Manager, Underwriter | **MATCHED** |
| **Loans List** | `lib/screens/loans/loans_list_screen.dart` | `/loans` | All (Scoped) | **MATCHED** |
| **Loan Detail** | `lib/screens/loans/loan_detail_screen.dart` | `/loan-detail` | All (Scoped) | **MATCHED** |
| **EMI Calculator** | `lib/screens/calculator/emi_calculator_screen.dart` | `/calculator` | All | **MATCHED** |
| **Loan Products** | `lib/screens/products/products_screen.dart` | `/products` | Admin, Manager | **MATCHED** |
| **Field Operations** | `lib/screens/field/field_tasks_screen.dart` | `/field` | Admin, Manager, Agent | **MATCHED** |
| **Attendance & Geofence**| `lib/screens/attendance/attendance_screen.dart` | `/attendance` | Admin, Manager, Agent | **MATCHED** |
| **Cloud Quotations** | `lib/screens/cloud_quotations/cloud_quotation_screen.dart`| `/cloud-quotes` | All | **MATCHED** |
| **Admin Settings** | `lib/screens/settings/admin_settings_screen.dart` | `/settings` | Admin | **MATCHED** |

---

## 3. Discrepancy & Missing Feature Analysis

Comparing the Flutter screens against the 38 website templates reveals the following gaps to achieve 100% website feature parity:

1. **Branch Management (`/branches` and `/branches/<bid>/details`)**:
   - Web: Lists branches, adds new branch with GPS coords, geofence radius, head name, and views branch-specific statistics.
   - Flutter: In SQLite schema, but lacks dedicated `/branches` screen.
2. **HRM & Employees (`/employees`, `/hrm`, `/employees/<eid>/print`)**:
   - Web: Staff directory, onboarding document checklist, leaves application and approval, 1-5 star performance reviews, and monthly payroll calculation.
   - Flutter: In SQLite schema, but lacks dedicated `/hrm` and `/employees` screens.
3. **WhatsApp Communication Hub (`/whatsapp`)**:
   - Web: Lists customers, generates OTP, triggers `wa.me` links, and verifies OTP.
   - Flutter: Lacks dedicated `/whatsapp` hub screen.
4. **Group Loan Application (`/pregrt/<pid>/apply`)**:
   - Web: When a Pre-GRT group is verified, allows 2-5 members to submit batch loan applications simultaneously.
   - Flutter: Shows Pre-GRT verification, but lacks the "Batch Group Apply" workflow screen.
5. **Printable Document Viewers & Exporters**:
   - Web: Generates printable HTML/PDF views for:
     - Customer Login Slip (`/crm/<cid>/login-slip`)
     - Bilingual KYC Dossier (`/crm/<cid>/kyc-form/print`)
     - Loan Passbook Card (`/loans/<lid>/card`)
     - Pre-GRT Certificate (`/pregrt/<pid>/print`)
     - Employee ID Form (`/employees/<eid>/print`)
   - Flutter: Needs responsive document viewer / sharing bottom sheets for these documents.
6. **Product Branding**:
   - Update all in-app labels, headers, and dialogs to strictly use **SARVOOCCH**.

---

## 4. Local Database Architecture (`DatabaseHelper`)

`sarvocch_app/lib/data/database_helper.dart` contains 18 relational tables with mock initial seed data:
- `users`, `employees`, `customers`, `comm_logs`, `products`, `applications`, `app_extra`, `approvals`, `loans`, `schedule`, `payments`, `mandates`, `tasks`, `attendance`, `branches`, `att_requests`, `pregrt`, `pregrt_members`, `kyc_forms`, `settings`, `cloud_connections`.

### Test Compatibility:
In automated test mode (`flutter test`), `DatabaseHelper` safely falls back to `sqflite_common_ffi` in-memory database to prevent native Android/iOS channel missing-plugin crashes.
