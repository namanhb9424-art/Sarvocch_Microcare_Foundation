# SARVOOCCH Android — Execution Status & Live Tracking

**Document Purpose:** Live engineering tracking for autonomous execution of the Android implementation plan.  
**Auditor / Architect:** Principal Android Engineer & Lead Flutter Architect  
**Current Date:** 3 November 2026  
**Status:** IN PROGRESS — Active Execution  

---

## 1. High-Level Execution Progress

| Milestone | Total Tasks | Completed | In Progress | Blocked | Status |
|---|---|---|---|---|---|
| **Phase 1: P0 Blocker & Crash Resolution** | 5 | 0 | 5 | 0 | IN PROGRESS |
| **Phase 2: Core Data & Financial Integrity** | 4 | 0 | 0 | 0 | PENDING |
| **Phase 3: Field & Screen Parity Expansion** | 4 | 0 | 0 | 0 | PENDING |
| **Phase 4: API Integration & Sync Engine** | 4 | 0 | 0 | 0 | PENDING |
| **Phase 5: Release Engineering & Verification** | 3 | 0 | 0 | 0 | PENDING |
| **TOTAL** | **20** | **0** | **5** | **0** | **ACTIVE** |

---

## 2. Task Checklist & Real-Time Status

| Task ID | Pri | Description | Target Files | Status | Test Reference |
|---|---|---|---|---|---|
| **TASK-001** | P0 | Missing `leaves`, `perf`, `holidays`, `sync_log` DB tables (fixes HRM crash) | `lib/data/database_helper.dart`, `lib/data/demo_seed_data.dart` | IN_PROGRESS | `test/user_flows_test.dart` |
| **TASK-002** | P0 | Fix `SplashScreen` lifecycle & `AuthProvider.init()` frame callback | `lib/screens/splash_screen.dart` | IN_PROGRESS | `test/widget_test.dart` |
| **TASK-003** | P0 | Integrate `geolocator` for real device GPS geofence checks | `lib/screens/attendance/attendance_screen.dart`, `pubspec.yaml` | IN_PROGRESS | Device & widget tests |
| **TASK-004** | P0 | Add Android runtime permissions (`INTERNET`, `LOCATION`, `CAMERA`) | `android/app/src/main/AndroidManifest.xml` | IN_PROGRESS | Manifest audit |
| **TASK-005** | P0 | Fix `test/widget_test.dart` to smoke test `SarvoocchApp` | `test/widget_test.dart` | IN_PROGRESS | `flutter test` |
| **TASK-006** | P1 | Dynamic overdue KPI calculation in `LoanProvider` (replace hardcoded 5200.0) | `lib/providers/loan_provider.dart` | PENDING | `test/user_flows_test.dart` |
| **TASK-007** | P1 | Dynamic dashboard branch portfolio pie chart | `lib/screens/dashboard_screen.dart` | PENDING | Widget test |
| **TASK-008** | P1 | Missing KYC Form fields & Family Member JSON table | `lib/screens/crm/kyc_form_screen.dart`, `lib/providers/customer_provider.dart` | PENDING | Flow 4 test |
| **TASK-009** | P1 | Missing loan application fields (co-borrower, cashflow appraisal, checklist) | `lib/screens/applications/apply_loan_screen.dart`, `lib/providers/loan_provider.dart` | PENDING | Flow 3 test |
| **TASK-010** | P1 | Real PDF Generation (Loan Passbook, Sanction Letter, Pre-GRT, NOC) | `lib/services/pdf_service.dart`, `lib/widgets/document_viewer_sheet.dart` | PENDING | Unit test |
| **TASK-011** | P1 | Photo capture for KYC (Applicant + Husband) | `lib/screens/crm/kyc_form_screen.dart`, `pubspec.yaml` | PENDING | Widget test |
| **TASK-012** | P1 | Release Signing Config with keystore + ProGuard / R8 minification | `android/app/build.gradle.kts`, `android/key.properties` | PENDING | `apksigner verify` |
| **TASK-013** | P1 | Application ID, version code, and version name update | `android/app/build.gradle.kts`, `pubspec.yaml` | PENDING | Manifest inspect |
| **TASK-014** | P1 | Central `ApiService` with backend endpoints + Secure Storage | `lib/services/api_service.dart`, `lib/providers/auth_provider.dart` | PENDING | Unit tests |
| **TASK-015** | P1 | Route Guard / Role Auth gate on all routes | `lib/main.dart`, `lib/utils/route_guard.dart` | PENDING | Integration tests |
| **TASK-016** | P1 | Offline Queue & Sync Engine (`SyncService`) connecting to `/api/sync` | `lib/services/sync_service.dart`, `lib/providers/cloud_quote_provider.dart` | PENDING | Integration test |
| **TASK-017** | P1 | User Profile & Change Password screen | `lib/screens/profile/profile_screen.dart`, `lib/widgets/custom_drawer.dart` | PENDING | Widget test |
| **TASK-018** | P1 | Field Tasks visual spatial map representation | `lib/screens/field/field_tasks_screen.dart` | PENDING | Widget test |
| **TASK-019** | P1 | Portfolio & Analytics / Reports screen | `lib/screens/reports/reports_screen.dart`, `lib/widgets/custom_drawer.dart` | PENDING | Flow 1 test |
| **TASK-020** | P2 | Re-enable Flutter analysis lints and fix all warnings | `analysis_options.yaml` | PENDING | `flutter analyze` |

---

## 3. Test & Verification Log

- **Base Run (2026-11-03 10:44 IST):**
  - `user_flows_test.dart`: 6/6 tests passed.
  - `widget_test.dart`: 1 failure (`Counter increments smoke test` - obsolete template).
- **Target:** 100% test pass rate across unit, widget, integration, and release verifications.

