# SARVOOCCH Microcare Android — Master Implementation Plan

**Version:** 1.0  
**Prepared:** 2026-11-03  
**Role:** Principal Flutter Architect / Mobile Audit  
**Target Engineer:** Gemini Flash Implementation Agent  
**Source of truth:** Existing repository at `/Users/vaidik/sarvocch_app`

---

## A. Executive Audit Summary

### What exists

The project is a **Flutter 3.x / Dart 3.x** multi-platform app (Android primary, also targeting macOS, iOS, Web, Windows, Linux). It contains **56 Dart files**, 19 screens, 6 providers, 9 models, and a 795-line SQLite seed file. A release APK (`sarvocch_microcare.apk`, 60 MB) was built on 2026-11-03.

The app covers a micro-finance workflow for **SARVOOCCH Microcare Foundation**, supporting five roles: Admin, Branch Manager, Underwriter, Field Officer (PSO), and Customer.

### What works (evidence-based)

| Area | Status |
|------|--------|
| Login with SQLite-backed credential check | ✅ Functional (demo only) |
| Role-based routing (`admin` → dashboard, `customer` → portal) | ✅ Functional |
| Loan application pipeline (submitted → under_review → approved → sanctioned → disbursed) | ✅ Full workflow in `LoanProvider.advanceApplication()` |
| EMI schedule generation (reducing balance + flat rate) | ✅ Mathematically correct |
| Installment payment recording (UPI, cash, card, eNACH) | ✅ Functional |
| Full loan settlement with payoff quote | ✅ Functional |
| Bilingual KYC form (3-step stepper) | ✅ Functional |
| Pre-GRT group workflow (create → submit → verify/return) | ✅ Functional |
| Geofenced attendance (Haversine calculation) | ✅ Algorithm correct, GPS mocked |
| Attendance correction request/approval flow | ✅ Functional |
| Field tasks (collection, verification) | ✅ Functional (GPS display only, no map) |
| HRM: Employee list, Leave management, Payroll calculation | ✅ Functional (2 missing DB tables) |
| Customer self-service portal (EMI view, UPI QR, NOC preview) | ✅ Functional (UPI payment is simulated) |
| WhatsApp OTP simulation | ✅ Simulated (hardcoded OTP `123456`) |
| KYC document verification (Aadhaar / PAN / Voter) | ✅ Local validation only — no real bureau |
| Cloud DB Quotation screen (6 providers, pricing) | ✅ Functional UI, fake sync engine |
| EMI Calculator | ✅ Functional |
| Branch / Product / CRM / Drawer navigation | ✅ Functional |
| QR codes (UPI, Loan Card, Sanction Letter) | ✅ Static / hardcoded URLs |
| 6 comprehensive integration tests (`user_flows_test.dart`) | ✅ Pass on FFI |

### What is defective or missing

1. **Zero real API connections.** Every piece of data originates from a local SQLite seed. No HTTP client exists (`http`, `dio`, or Retrofit are absent from `pubspec.yaml`). The cloud sync in `CloudQuoteProvider` is a simulated delay (`Future.delayed`).
2. **Authentication is completely insecure.** Passwords stored in plaintext (`pw` column). No token, no session, no JWT, no secure storage.
3. **GPS is hardcoded** in `AttendanceScreen` (`_mockLat = 22.7510`, `_mockLng = 75.8900`). The app cannot perform real geofenced attendance on Android.
4. **Two HRM database tables are missing**: `leaves` and `perf`. `HrmScreen` performs raw SQL `FROM leaves` and `FROM perf` — both will **throw runtime exceptions** on a fresh install.
5. **APK signed with debug key** (`signingConfig = signingConfigs.getByName("debug")`). Not Play Store eligible.
6. **APK is 60 MB** with no shrinking/obfuscation configured.
7. **`widget_test.dart` is the Flutter counter template** — it will always fail on this app (tests for `find.text('0')` and `Icons.add` which do not exist).
8. **Document generation** (NOC PDF, Loan Passbook, Sanction Letter, Pre-GRT Certificate) is rendered as text widgets in a `DocumentViewerSheet`; there is no real PDF generation or download.
9. **WhatsApp integration** is completely simulated — OTP is `Random()` on device, displayed in-app, hardcoded verification accepts `123456` anywhere.
10. **KYC Bureau check** displays "NSDL & UIDAI Mock Handshake Passed 200 OK" — hardcoded string, no actual API call.
11. **Dashboard pie chart** uses 4 hardcoded series (`86000`, `32000`, `20000`, `15000`) rather than live `branchPortfolio` data from `LoanProvider`.
12. **`_totalOverdue`** is hardcoded in `LoanProvider._calculateKpis()` to `5200.0` when `overdueCount > 0`.
13. **No internet permission** in `AndroidManifest.xml` — the moment any real API call is added, it will fail silently.
14. **No camera, location, or storage permissions** declared in `AndroidManifest.xml`.
15. **Field tasks screen** shows `lat/lng` coordinates as text instead of a map; `_triggerSync()` is a 1-second fake delay.
16. **Navigation architecture** uses `Navigator.pushReplacementNamed` / string routes with no deep-link support, route guards, or proper back-stack management.
17. **No error boundaries** — a failed DB query shows a blank screen; no user-facing error states.
18. **`AuthProvider.init()`** is never called from `main.dart` or `SplashScreen`; the `init()` flow only runs in tests, meaning `demoUsers` is always empty in production.
19. **Loan card QR** points to `https://sarvocch.demo/loans/...` — a non-existent domain.
20. **`use_build_context_synchronously`** lint is globally silenced in `analysis_options.yaml`, masking real async/context bugs.

---

## B. Screen and Feature Inventory

### Website modules → Mobile screens

| Website Module | Mobile Screen | File | Status |
|---|---|---|---|
| Login / Role Auth | `LoginScreen` | `login_screen.dart` | ⚠️ Demo-only auth |
| Dashboard / KPIs | `DashboardScreen` | `dashboard_screen.dart` | ⚠️ Hardcoded chart |
| CRM Lead Management | `CrmListScreen` + `CrmDetailScreen` | `crm/` | ✅ Functional |
| Bilingual KYC Form | `KycFormScreen` | `crm/kyc_form_screen.dart` | ⚠️ Missing fields |
| KYC Document Verification | `KycVerifyScreen` | `kyc_verify/` | ❌ Mocked bureau |
| Pre-GRT Group Recognition Test | `PreGrtScreen` + `GroupApplyScreen` | `pregrt/` | ✅ Functional |
| Loan Application | `ApplyLoanScreen` | `applications/apply_loan_screen.dart` | ⚠️ Missing fields |
| Applications Pipeline | `ApplicationsScreen` + `ApplicationDetailScreen` | `applications/` | ✅ Functional |
| Active Loans & Schedule | `LoansListScreen` + `LoanDetailScreen` | `loans/` | ✅ Functional |
| Field Tasks / Collections | `FieldTasksScreen` | `field/` | ⚠️ No map, fake sync |
| Attendance & Geofence | `AttendanceScreen` | `attendance/` | ❌ GPS mocked |
| Branch Management | `BranchesScreen` | `branches/` | ✅ Read-only |
| Loan Products | `ProductsScreen` | `products/` | ✅ Read-only |
| HRM (Staff, Leave, Perf, Payroll) | `HrmScreen` | `hrm/` | ❌ 2 missing tables |
| WhatsApp Hub | `WhatsAppScreen` | `whatsapp/` | ❌ Fully simulated |
| Customer Self-Service Portal | `CustomerPortalScreen` | `portal/` | ⚠️ UPI simulated |
| EMI Calculator | `EmiCalculatorScreen` | `calculator/` | ✅ Functional |
| Cloud DB Quotations | `CloudQuotationScreen` | `cloud_quotations/` | ⚠️ Fake sync |
| Admin Settings | `AdminSettingsScreen` | `settings/` | ✅ Functional |
| Splash Screen | `SplashScreen` | `splash_screen.dart` | ⚠️ Auth init missing |

### Missing screens (website has these, mobile does not)

| Missing Screen | Priority |
|---|---|
| Reports & Portfolio Analytics (branch-wise disbursement table, PAR aging) | P1 |
| Loan NOC PDF Download (actual file generation) | P1 |
| Loan Passbook PDF Download | P1 |
| Sanction Letter PDF Download | P1 |
| Group Apply full multi-member loan submission screen | P1 |
| Notifications / Alerts Center | P2 |
| Profile / Change Password screen | P1 |
| Offline queue manager / sync status dashboard | P2 |
| Bureau (CIBIL / Equifax) check result screen | P2 |
| eNACH mandate setup & management screen | P2 |
| Document upload (photo capture → server) | P1 |
| Pre-GRT member add/edit screen (mobile-optimized) | P2 |

---

## C. Field and Function Parity Gaps

### C.1 KYC Form — Missing fields

The `KycFormScreen` is a 3-step stepper. The DB schema has 40+ fields but the form exposes fewer than 20.

| Missing Field | DB Column | Priority |
|---|---|---|
| House number (मकान सं.) | `house_no` | P1 |
| Post office (डाकघर) | `post_office` | P1 |
| State (राज्य) | `state` | P1 |
| PIN code (पिन कोड) | `pincode` | P1 |
| Land (hectares) | `land_ha` | P1 |
| Livestock (पशुधन) | `livestock` | P1 |
| Passbook holder name | `passbook_name` | P1 |
| Family member table (dynamic rows) | `family` (JSON) | P1 |
| Relative in center | `relative_in_center`, `relative_name` | P2 |
| Other loans count | `other_loans`, `current_debt` | P1 |
| Repayment frequency dropdown | `repay_freq` | P1 |
| Distance to center (m) / branch (km) | `dist_center_m`, `dist_branch_km` | P2 |
| Co-applicant fields | `co_name`, `co_phone`, `co_relation`, `co_income` | P1 |
| Guardian type dropdown | `guardian_type` (bound to free-text, should be dropdown) | P1 |
| Religion dropdown | `religion` (free-text, should be dropdown) | P2 |
| Photo capture (applicant + husband) | `photo`, `h_photo` | P1 |
| Signed physical copy upload | `signed_copy` | P2 |

### C.2 Loan Application — Missing fields

| Missing Field | DB Column | Priority |
|---|---|---|
| Employer name | `employer` | P2 |
| Co-borrower name/phone/relation/income | `co_name`, `co_phone`, `co_relation`, `co_income` | P1 |
| Agricultural income | `inc_agri` | P1 |
| Previous loans JSON | `prev_loans` | P1 |
| Insurance wanted/for | `insurance_wanted`, `insurance_for` | P2 |
| EMI expense from existing loans | `exp_emi` | P1 |
| Loan cycle number | `loan_cycle` | P1 |
| Documents deposited multi-select | `docs_deposited` | P1 |
| Group / Center recommendation amounts | `group_rec`, `center_rec` | P2 |
| Declaration checkbox (separate from form) | `declaration` | P1 |

### C.3 Incorrect / Broken Functions

| Issue | Location | Evidence |
|---|---|---|
| `_totalOverdue` hardcoded to `5200.0` | `loan_provider.dart:108` | `_totalOverdue = overdueCount > 0 ? 5200.0 : 0.0` |
| Dashboard pie chart uses static values | `dashboard_screen.dart:266-310` | All 4 sections hardcoded: `86000`, `32000`, `20000`, `15000` |
| `AuthProvider.init()` never called | `main.dart` / `splash_screen.dart` | `demoUsers` always empty in production |
| WhatsApp OTP always `123456` | `customer_provider.dart:233` | `if (otp == '123456')` |
| `_mockLat`, `_mockLng` hardcoded GPS | `attendance_screen.dart:18-19` | Used in real punch-in flow |
| Field task sync is fake | `field_tasks_screen.dart:133-145` | `await Future.delayed(...)` |
| Cloud sync is fake | `cloud_quote_provider.dart` | Simulated progress increments |
| HRM `leaves` table missing | `database_helper.dart` | Not in `_onCreate`, queried in `hrm_screen.dart:51-56` |
| HRM `perf` table missing | `database_helper.dart` | Not in `_onCreate`, queried in `hrm_screen.dart:58-64` |
| KYC bureau check is mocked | `kyc_verify_screen.dart:69` | Hardcoded "NSDL & UIDAI Mock Handshake Passed 200 OK" |
| UPI payment is simulated | `customer_portal_screen.dart:283-290` | `ScaffoldMessenger.showSnackBar(...)` without actual payment |
| NOC download is fake snackbar | `customer_portal_screen.dart:326-329` | No PDF generated |
| Loan card QR points to `.demo` domain | `loan_detail_screen.dart:273` | `sarvocch.demo/loans/...` |
| Sanction Letter QR points to `.demo` domain | `application_detail_screen.dart:165` | `sarvocch.demo/applications/...` |
| NOC certificate number hardcoded | `customer_portal_screen.dart:314` | `SMF-NOC-2026-0941` |

---

## D. Architecture Recommendations

### D.1 Keep (don't refactor unnecessarily)

- **Provider** (`provider: ^6.1.5`) — existing state management, well-structured, retain it. Do NOT migrate to Riverpod or Bloc — unnecessary risk.
- **SQLite / sqflite** — local persistence is architecturally correct for offline-first MFI field use. Retain it.
- **Named routes** in `MaterialApp` — simple and works. Add a `RouteGuard` wrapper rather than replacing the router.
- **Model classes** — all 9 are well-designed `fromMap` factories. Retain and extend.

### D.2 Add (required for production)

```
lib/
  services/
    api_service.dart          # Central HTTP client (http package)
    auth_service.dart         # Token management, SecureStorage
    location_service.dart     # GPS using geolocator
    pdf_service.dart          # PDF generation using pdf + printing packages
    notification_service.dart # FCM push notifications
    sync_service.dart         # Real offline queue + cloud sync
  utils/
    route_guard.dart          # Auth-aware navigation wrapper
    validators.dart           # Centralized field validators
    error_handler.dart        # Global error display utilities
  widgets/
    error_state.dart          # Empty/error/loading state widgets
    date_picker_field.dart    # Consistent date picker widget
    photo_capture_field.dart  # Camera + gallery picker widget
```

### D.3 Required new packages

| Package | Purpose |
|---|---|
| `http` or `dio` | Real HTTP API client |
| `flutter_secure_storage` | JWT / session token storage |
| `geolocator` | Real GPS for attendance |
| `permission_handler` | Runtime permissions (location, camera, storage) |
| `pdf` + `printing` | Generate NOC, passbook, sanction letter PDFs |
| `image_picker` | Photo capture for KYC |
| `firebase_messaging` | EMI reminders, approval notifications |
| `connectivity_plus` | Offline detection |
| `shared_preferences` | Settings persistence across launches |

### D.4 Database migrations

Add `onUpgrade` handler in `DatabaseHelper` and bump version to `2`. Required for:
- Creating `leaves` and `perf` tables (immediate crash fix)
- Adding missing columns to existing tables

---

## E. Implementation Roadmap

### Priority legend: P0 = crash/blocker, P1 = core feature missing, P2 = enhancement

---

#### TASK-001
- **ID:** TASK-001
- **Priority:** P0
- **Title:** Create missing `leaves` and `perf` DB tables to prevent HRM crash
- **Files:** `lib/data/database_helper.dart`
- **Dependencies:** None
- **Description:**  
  Add `CREATE TABLE IF NOT EXISTS leaves (id, user_id, from_d, to_d, reason, status)` and `CREATE TABLE IF NOT EXISTS perf (id, user_id, period, rating, notes, by_name)` inside `_onCreate`. Add `onUpgrade` callback that creates both tables when version < 2. Bump DB version to 2. Add seed data for both tables in `DemoSeedData.seedDatabase()`.
- **Acceptance criteria:** HRM screen loads all 4 tabs without exception on fresh install and after upgrade from v1.
- **Required tests:** Unit test `DatabaseHelper` upgrade path; widget test all 4 HRM tabs render with seeded data.

---

#### TASK-002
- **ID:** TASK-002
- **Priority:** P0
- **Title:** Fix `AuthProvider.init()` never being called — `demoUsers` always empty
- **Files:** `lib/screens/splash_screen.dart`, `lib/providers/auth_provider.dart`
- **Dependencies:** None
- **Description:**  
  `SplashScreen.initState()` must call `context.read<AuthProvider>().init()` and `await` its completion before navigating. Currently it navigates immediately. This means `_demoUsers` is always `[]` in production and the auto-login to first user is never triggered.
- **Acceptance criteria:** App launches → splash waits for `init()` → navigates to `/login`; `auth.demoUsers` is populated.
- **Required tests:** Integration test: launch app, verify `auth.demoUsers.length >= 5` before first navigation.

---

#### TASK-003
- **ID:** TASK-003
- **Priority:** P0
- **Title:** Replace hardcoded GPS coordinates with real `geolocator` plugin
- **Files:** `lib/screens/attendance/attendance_screen.dart`, `android/app/src/main/AndroidManifest.xml`, `pubspec.yaml`
- **Dependencies:** Add `geolocator: ^13.x`, `permission_handler: ^11.x` to pubspec
- **Description:**  
  Remove `_mockLat = 22.7510` and `_mockLng = 75.8900`. Implement `_getLocation()` async method using `geolocator.Geolocator.getCurrentPosition()`. Add `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` to `AndroidManifest.xml`. Show permission rationale dialog before requesting. If permission denied, show clear error — do not silently use mock coordinates.
- **Acceptance criteria:** Punch-in uses real device GPS. Distance calculation matches actual distance to branch. Permission denied shows user-facing error.
- **Required tests:** Widget test with mocked `Geolocator` returning known coords; verify snackbar shows correct distance.

---

#### TASK-004
- **ID:** TASK-004
- **Priority:** P0
- **Title:** Add required Android permissions to `AndroidManifest.xml`
- **Files:** `android/app/src/main/AndroidManifest.xml`
- **Dependencies:** TASK-003
- **Description:**  
  Add these permissions (currently NONE exist):
  ```xml
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
  <uses-permission android:name="android.permission.CAMERA"/>
  <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
  <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
  ```
  Without `INTERNET`, all future API calls silently fail on Android.
- **Acceptance criteria:** App requests permissions at the correct moment. Network calls succeed.
- **Required tests:** Manual test on physical Android device; verify no `SecurityException` in logcat.

---

#### TASK-005
- **ID:** TASK-005
- **Priority:** P0
- **Title:** Fix `widget_test.dart` — currently tests a counter app, not this app
- **Files:** `test/widget_test.dart`
- **Dependencies:** None
- **Description:**  
  The file contains the Flutter template smoke test for a counter. It will fail immediately on this app because there is no counter widget. Replace with a smoke test that: (1) builds `SarvoocchApp`, (2) verifies the splash screen renders, (3) verifies the login screen has a "Sign In" button.
- **Acceptance criteria:** `flutter test test/widget_test.dart` passes.
- **Required tests:** The fix itself is a test.

---

#### TASK-006
- **ID:** TASK-006
- **Priority:** P1
- **Title:** Fix hardcoded overdue amount in `LoanProvider._calculateKpis()`
- **Files:** `lib/providers/loan_provider.dart`
- **Dependencies:** None
- **Description:**  
  Line 108: `_totalOverdue = overdueCount > 0 ? 5200.0 : 0.0;` — replace with actual calculation: sum of all `emi` amounts from `schedule` rows where `paid = 0` AND `due_date < date('now')`. Add a subquery or a dedicated DB fetch.
- **Acceptance criteria:** Dashboard "Overdue Amount" KPI reflects actual DB data, not a hardcoded value.
- **Required tests:** Unit test: seed loan with 2 overdue installments → verify `totalOverdue` equals sum.

---

#### TASK-007
- **ID:** TASK-007
- **Priority:** P1
- **Title:** Fix dashboard pie chart — use live `branchPortfolio` data
- **Files:** `lib/screens/dashboard_screen.dart`
- **Dependencies:** TASK-006
- **Description:**  
  Replace the 4 hardcoded `PieChartSectionData` values (`86000`, `32000`, `20000`, `15000`) and hardcoded legend labels with dynamic data from `loan.branchPortfolio` (a `Map<String, double>` already computed in `LoanProvider._calculateKpis()`). Compute percentages at render time. Show "No data" state when map is empty.
- **Acceptance criteria:** Pie chart reflects actual DB disbursements per branch. Adding a new disbursement updates the chart on next refresh.
- **Required tests:** Widget test: seed 2 loans in different branches → verify 2 pie sections with correct percentages.

---

#### TASK-008
- **ID:** TASK-008
- **Priority:** P1
- **Title:** Add missing KYC form fields (Phase 1 — mandatory fields)
- **Files:** `lib/screens/crm/kyc_form_screen.dart`, `lib/providers/customer_provider.dart`
- **Dependencies:** None
- **Description:**  
  Add to the existing 3-step stepper the following missing mandatory fields, matching the DB schema:  
  Step 1 (Applicant): `guardian_type` (dropdown: husband/father/mother/self), `religion` (dropdown), `state` (text), `pincode` (numeric, 6 digits).  
  Step 2 (Residence & Bank): `house_no`, `post_office`, `passbook_name`, `land_ha` (numeric), `livestock` (text), `other_loans` (toggle), `current_debt` (numeric), `repay_freq` (dropdown: weekly/biweekly/monthly), `dist_center_m` (numeric), `dist_branch_km` (numeric).  
  Step 3 (Consent): `co_name`, `co_phone`, `co_relation` (dropdown), `co_income` (numeric).  
  Update `CustomerProvider.saveKycForm()` to accept and persist all new parameters.  
  Add a Step 4 for **Family Members** (dynamic `ListView` of rows with name, age, education, relation, occupation fields; stored as JSON in `family` column).
- **Acceptance criteria:** All 40+ KYC fields from `kyc_forms` schema are exposed and saved correctly.
- **Required tests:** Unit test `saveKycForm()` with all new fields → verify DB row contains correct values. Widget test Step 1 → Step 4 navigation.

---

#### TASK-009
- **ID:** TASK-009
- **Priority:** P1
- **Title:** Add missing loan application fields
- **Files:** `lib/screens/applications/apply_loan_screen.dart`, `lib/providers/loan_provider.dart`
- **Dependencies:** None
- **Description:**  
  Add to `ApplyLoanScreen` and `submitNewLoanApplication()`:  
  - Employer name (`employer`)
  - Co-borrower: name, phone, relation (dropdown), income (`co_name`, `co_phone`, `co_relation`, `co_income`)
  - Agricultural income (`inc_agri`)
  - EMI expense from existing loans (`exp_emi`)
  - Loan cycle number (`loan_cycle`) — auto-populated from previous closed loans
  - Previous loans JSON (`prev_loans`) — checkbox list of prior loan IDs
  - Insurance wanted (yes/no toggle) + insurance for (self/spouse/both) (`insurance_wanted`, `insurance_for`)
  - Documents deposited multi-select chips (`docs_deposited`)
  - Declaration acceptance checkbox (`declaration`)
- **Acceptance criteria:** All `applications` and `app_extra` table columns are populated from the form.
- **Required tests:** Unit test: submit application with all fields → verify both `applications` and `app_extra` rows are complete.

---

#### TASK-010
- **ID:** TASK-010
- **Priority:** P1
- **Title:** Implement real PDF generation for NOC, Loan Passbook, and Sanction Letter
- **Files:** `lib/widgets/document_viewer_sheet.dart`, `lib/services/pdf_service.dart` (new), `pubspec.yaml`
- **Dependencies:** Add `pdf: ^3.x` and `printing: ^5.x` to pubspec; TASK-004 (storage permission)
- **Description:**  
  Create `PdfService` with three methods:  
  - `generateNoc(LoanModel loan) → Future<Uint8List>`  
  - `generateLoanPassbook(LoanModel loan, List<ScheduleItemModel> schedule) → Future<Uint8List>`  
  - `generateSanctionLetter(ApplicationModel app) → Future<Uint8List>`  
  Each method builds a formatted PDF using the `pdf` package with SARVOOCCH letterhead, loan/borrower details, and a signature line.  
  Replace snackbar stubs in `CustomerPortalScreen._showNocDialog()` and `DocumentViewerSheet` with `Printing.layoutPdf()` to open the native print/share sheet.  
  QR codes in the PDF should point to the real backend URL (configured via settings), not `sarvocch.demo`.
- **Acceptance criteria:** Tapping "Download NOC" opens a shareable/printable PDF. PDF contains correct loan details from DB.
- **Required tests:** Unit test `PdfService.generateNoc()` returns non-empty bytes. Widget test: tap "NOC PDF" → share sheet appears.

---

#### TASK-011
- **ID:** TASK-011
- **Priority:** P1
- **Title:** Add photo capture to KYC Form (applicant photo + husband photo)
- **Files:** `lib/screens/crm/kyc_form_screen.dart`, `lib/providers/customer_provider.dart`, `pubspec.yaml`, `AndroidManifest.xml`
- **Dependencies:** Add `image_picker: ^1.x` to pubspec; TASK-004 (camera permission)
- **Description:**  
  Add two `ImagePicker` widgets in KYC form Step 1:  
  - Applicant photo (stored as base64 in `photo` column or file path)  
  - Husband photo (stored in `h_photo`)  
  Show thumbnail preview after capture. Allow retake. On save, store file path or base64 in `kyc_forms` table. The field must show "Photo Required ✗" if not captured and submission is attempted.
- **Acceptance criteria:** KYC save requires at least applicant photo. Photo is persisted and visible on `CrmDetailScreen`.
- **Required tests:** Widget test: form submission without photo shows validation error.

---

#### TASK-012
- **ID:** TASK-012
- **Priority:** P1
- **Title:** Implement production release signing configuration
- **Files:** `android/app/build.gradle.kts`, `android/key.properties` (new — gitignored)
- **Dependencies:** Developer must generate a keystore
- **Description:**  
  Add signing configuration to `build.gradle.kts`:
  ```kotlin
  val keystoreProperties = Properties()
  val keystorePropertiesFile = rootProject.file("key.properties")
  if (keystorePropertiesFile.exists()) {
      keystoreProperties.load(FileInputStream(keystorePropertiesFile))
  }
  signingConfigs {
      create("release") {
          keyAlias = keystoreProperties["keyAlias"] as String
          keyPassword = keystoreProperties["keyPassword"] as String
          storeFile = file(keystoreProperties["storeFile"] as String)
          storePassword = keystoreProperties["storePassword"] as String
      }
  }
  buildTypes {
      release {
          signingConfig = signingConfigs.getByName("release")
          isMinifyEnabled = true
          isShrinkResources = true
          proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
      }
  }
  ```
  Create `android/key.properties.template` with placeholder values. Add `key.properties` and `*.jks` to `.gitignore`.  
  Enable `isMinifyEnabled` and `isShrinkResources` to reduce APK from 60 MB to expected ~18–25 MB.
- **Acceptance criteria:** `flutter build apk --release` produces an APK signed with the release key. `apksigner verify` reports valid signature.
- **Required tests:** CI step: `apksigner verify --print-certs release.apk` exits 0.

---

#### TASK-013
- **ID:** TASK-013
- **Priority:** P1
- **Title:** Set correct `applicationId`, `versionCode`, and `versionName`
- **Files:** `android/app/build.gradle.kts`, `pubspec.yaml`
- **Dependencies:** None
- **Description:**  
  The current `applicationId = "com.sarvocch.microcare.sarvocch_app"` is a developer placeholder. The implementation engineer must confirm the desired production package name with the client (e.g., `in.org.sarvocch.microcare`). Update `pubspec.yaml` version from `1.0.0+1` to the agreed semantic version. Ensure `versionCode` increments on every release build.
- **Acceptance criteria:** `flutter build apk --release` embeds correct package name. `adb shell pm list packages | grep sarvocch` returns the correct ID.
- **Required tests:** Manual verification on device. Play Console upload validates package name.

---

#### TASK-014
- **ID:** TASK-014
- **Priority:** P1
- **Title:** Build `ApiService` and wire real backend authentication
- **Files:** `lib/services/api_service.dart` (new), `lib/providers/auth_provider.dart`, `pubspec.yaml`
- **Dependencies:** TASK-004 (INTERNET permission); Add `http: ^1.x` and `flutter_secure_storage: ^9.x`
- **Description:**  
  Create `ApiService` with:
  - `baseUrl` loaded from a `const String` or `.env` mechanism
  - `login(username, password) → Future<AuthResponse>` — POST to `/api/auth/login`, returns JWT
  - `getHeader()` — returns `Authorization: Bearer <token>` from `FlutterSecureStorage`
  - Error handling: `401 → logout()`, `5xx → throw ApiException`  
  Update `AuthProvider.login()` to call `ApiService.login()` and persist the JWT. Retain SQLite as offline cache.  
  Passwords must NEVER be stored in SQLite in production. Remove the `pw` column from the schema or replace with a `session_token` column.
- **Acceptance criteria:** Login calls the real backend. JWT is stored in `SecureStorage`. Logout clears the token.
- **Required tests:** Unit test `ApiService.login()` with mock HTTP client → returns populated `AuthResponse`. Test 401 → `logout()` is called.

---

#### TASK-015
- **ID:** TASK-015
- **Priority:** P1
- **Title:** Add route guard to protect authenticated routes
- **Files:** `lib/main.dart`, `lib/utils/route_guard.dart` (new), `lib/screens/splash_screen.dart`
- **Dependencies:** TASK-002, TASK-014
- **Description:**  
  Create `RouteGuard` widget that wraps each named route's builder. If `auth.isAuthenticated == false`, redirect to `/login`. If `auth.currentUser?.role == 'customer'` and route is not `/portal` or `/calculator`, redirect to `/portal`.  
  Implement `onGenerateRoute` instead of static `routes` map to enable dynamic guard logic.  
  `SplashScreen` must: (1) call `AuthProvider.init()`, (2) check for a stored JWT, (3) attempt silent token refresh, (4) navigate to dashboard/portal/login accordingly.
- **Acceptance criteria:** Navigating directly to `/dashboard` without login redirects to `/login`. Customer role cannot access admin screens.
- **Required tests:** Integration test: navigate to `/settings` as unauthenticated → redirected to `/login`.

---

#### TASK-016
- **ID:** TASK-016
- **Priority:** P1
- **Title:** Implement real-time cloud sync for SQLite ↔ Backend
- **Files:** `lib/services/sync_service.dart` (new), `lib/providers/cloud_quote_provider.dart`
- **Dependencies:** TASK-014; Add `connectivity_plus: ^6.x`
- **Description:**  
  Replace `CloudQuoteProvider.triggerCloudSync()` fake delay with a real sync engine:
  1. Detect connectivity with `connectivity_plus`.
  2. On connectivity restored, upload pending local mutations (new customers, applications, payments) as JSON POST to backend.
  3. Fetch remote changes since `last_synced` timestamp.
  4. Merge into SQLite using `ConflictAlgorithm.replace`.
  5. Update `cloud_connections.last_synced`.
  6. Expose `SyncService.syncProgress` as a `ValueNotifier<double>` consumed by the UI.
  7. Handle 409 conflicts with last-write-wins strategy.
- **Acceptance criteria:** Field officer creates a customer offline → goes online → customer appears on manager's dashboard. `syncStatusMessage` reflects real operation counts.
- **Required tests:** Integration test: insert customer offline → trigger sync with mocked HTTP → verify customer exists on "server" mock.

---

#### TASK-017
- **ID:** TASK-017
- **Priority:** P1
- **Title:** Add `Profile / Change Password` screen
- **Files:** `lib/screens/profile/profile_screen.dart` (new), `lib/widgets/custom_drawer.dart`, `lib/main.dart`
- **Dependencies:** TASK-014
- **Description:**  
  Create profile screen with: display name, role, branch, phone. Add "Change Password" section with current password, new password (min 8 chars, 1 uppercase, 1 digit), confirm password. POST to `/api/auth/change-password`. Expose from drawer and `/profile` route.
- **Acceptance criteria:** User changes password → next login requires new password. Weak password shows validation error inline.
- **Required tests:** Unit test password validator. Widget test form validation states.

---

#### TASK-018
- **ID:** TASK-018
- **Priority:** P1
- **Title:** Add map view to Field Tasks screen (GPS coordinates to visual map)
- **Files:** `lib/screens/field/field_tasks_screen.dart`, `pubspec.yaml`
- **Dependencies:** TASK-003, TASK-004; Add `flutter_map: ^7.x` + `latlong2` (offline-capable, no API key required) or `google_maps_flutter`
- **Description:**  
  Add a "Map" toggle view to `FieldTasksScreen`. When active, show a `FlutterMap` with markers for each task's `lat`/`lng`. Tapping a marker shows task title and borrower name. Color-code markers: red = open collection, green = done, blue = verification task.  
  Use `flutter_map` (OpenStreetMap tiles) to avoid API key requirement for initial release. `google_maps_flutter` can be substituted if the client has a Maps API key.
- **Acceptance criteria:** Field officers see spatial distribution of tasks. Marker tap shows task details.
- **Required tests:** Widget test: tasks with known coords render correct number of markers.

---

#### TASK-019
- **ID:** TASK-019
- **Priority:** P1
- **Title:** Implement Portfolio / Reports screen
- **Files:** `lib/screens/reports/reports_screen.dart` (new), `lib/main.dart`
- **Dependencies:** TASK-006, TASK-007
- **Description:**  
  Create a new reports screen with tabs:
  - **Portfolio Summary:** Total disbursed, outstanding, overdue, recovery rate by branch (table + bar chart from `fl_chart`).
  - **PAR Aging Report:** Loans overdue 1–30 days, 31–60 days, 61–90 days, 90+ days. Counts and amounts.
  - **Collection Efficiency:** Month-wise EMI collected vs. due (line chart).
  - **Branch Drill-down:** Tap a branch → show its loans, customers, field officers.
  All data sourced from existing SQLite queries. Export to CSV using `share_plus` package.
- **Acceptance criteria:** Reports screen accessible from drawer for Admin and Manager roles. PAR aging correctly buckets overdue installments.
- **Required tests:** Unit test PAR bucket logic. Widget test report renders without error.

---

#### TASK-020
- **ID:** TASK-020
- **Priority:** P2
- **Title:** Fix `analysis_options.yaml` — re-enable silenced safety lints
- **Files:** `analysis_options.yaml`
- **Dependencies:** TASK-003, TASK-008, TASK-009
- **Description:**  
  Remove these silenced rules after fixing underlying async/context issues:
  - `use_build_context_synchronously: ignore` — currently masking real bugs in `KycFormScreen`, `AttendanceScreen`, `ApplicationDetailScreen` and others.
  - `prefer_final_fields: ignore` — cosmetic but good practice.
  After re-enabling, run `flutter analyze` and fix every reported `use_build_context_synchronously` error by adding `if (!mounted) return;` guards or using `NavigatorState` before the `await`.
- **Acceptance criteria:** `flutter analyze` exits 0 with no errors or warnings.
- **Required tests:** CI gate: `flutter analyze --no-pub` exits 0.

---

#### TASK-021
- **ID:** TASK-021
- **Priority:** P2
- **Title:** Implement push notifications for EMI reminders and approval events
- **Files:** `lib/services/notification_service.dart` (new), `android/app/src/main/AndroidManifest.xml`, `pubspec.yaml`
- **Dependencies:** Add `firebase_core`, `firebase_messaging`; TASK-014
- **Description:**  
  Integrate Firebase Cloud Messaging. Register device token on login. Handle foreground/background messages:
  - EMI due in 3 days → show local notification with loan details and "Pay Now" deep link to `/loans`.
  - Application status changed → notify field officer: "Your application #APP-7 was approved".
  - Attendance not punched by 10:00 AM → remind field officers.
  Add `com.google.firebase.MESSAGING_EVENT` intent in `AndroidManifest.xml`.
- **Acceptance criteria:** Device receives test push from Firebase console. Deep-link from notification navigates to correct screen.
- **Required tests:** Widget test: FCM message handler triggers correct navigation intent.

---

#### TASK-022
- **ID:** TASK-022
- **Priority:** P2
- **Title:** Replace simulated WhatsApp OTP with real WhatsApp Business API
- **Files:** `lib/screens/whatsapp/whatsapp_screen.dart`, `lib/providers/customer_provider.dart`, `lib/services/api_service.dart`
- **Dependencies:** TASK-014; backend must expose WhatsApp OTP endpoint
- **Description:**  
  Replace `_sendWhatsAppOtp()` local Random OTP with a POST to `/api/whatsapp/send-otp` (body: `{customer_id, phone}`). Backend is responsible for calling WhatsApp Business API. OTP is NOT stored in the SQLite `wa_otp` column on the client; it is verified server-side via `/api/whatsapp/verify-otp`. The hardcoded `otp == '123456'` check in `CustomerProvider.verifyWhatsAppOtp()` must be removed.
- **Acceptance criteria:** OTP is sent to real phone number via WhatsApp. Wrong OTP returns error from server. `wa_verified = 1` is set only after server confirms.
- **Required tests:** Unit test mock API: verify OTP endpoint called with correct params. Test error path (wrong OTP) shows snackbar.

---

#### TASK-023
- **ID:** TASK-023
- **Priority:** P2
- **Title:** Implement offline queue manager with visual status
- **Files:** `lib/services/sync_service.dart`, `lib/screens/field/field_tasks_screen.dart`
- **Dependencies:** TASK-016
- **Description:**  
  Add an `offline_queue` SQLite table: `(id, entity_type, entity_id, operation, payload_json, created_at, synced_at)`. Every create/update in `CustomerProvider`, `LoanProvider`, `PreGrtProvider` when offline inserts a row. `SyncService.triggerSync()` processes the queue in order. Replace the `_triggerSync()` fake delay in `FieldTasksScreen` with a real queue flush that reports counts.
- **Acceptance criteria:** Field officer creates 3 customers offline → sees "3 items pending sync" badge → goes online → badge clears → customers visible to manager.
- **Required tests:** Integration test: insert 3 items to queue → trigger sync with mocked HTTP → verify queue is empty after sync.

---

## F. Android-Specific Improvements

### F.1 Security

| Issue | Fix | Priority |
|---|---|---|
| Release APK signed with debug key | TASK-012: production keystore | P0 |
| Plaintext passwords in SQLite | TASK-014: remove `pw` column, use JWT | P0 |
| No `INTERNET` permission | TASK-004 | P0 |
| API keys in code (demo JWT in seed data) | Use `FlutterSecureStorage`; never commit real keys | P1 |
| `api_key` stored unencrypted in `cloud_connections` table | Encrypt at rest using SQLCipher or store in SecureStorage | P1 |
| No SSL certificate pinning | Add certificate pinning in `ApiService` for production | P2 |
| Debug banner enabled in release | `debugShowCheckedModeBanner: false` ✅ already done | ✅ |

### F.2 Android lifecycle

| Issue | Fix | Priority |
|---|---|---|
| No `WillPopScope` deprecation handling | Already using `PopScope` with `canPop: false` ✅ | ✅ |
| No save instance state for in-progress forms | Add `RestorationMixin` to `KycFormScreen` and `ApplyLoanScreen` | P2 |
| GPS location acquired but not stopped on `dispose()` | Add `Geolocator.stopListening()` in `dispose()` | P1 |
| Database opened multiple times on lifecycle | `DatabaseHelper._database` singleton ✅ correct | ✅ |

### F.3 Networking

| Issue | Fix |
|---|---|
| No HTTP client at all | Add `http` package, create `ApiService` (TASK-014) |
| No timeout configured | Set 30s timeout on all API calls |
| No retry on network failure | Implement exponential backoff in `ApiService` |
| No offline detection | Add `connectivity_plus` (TASK-016) |

### F.4 Storage

| Issue | Fix |
|---|---|
| SQLite `pw` column stores plaintext passwords | Remove; replace with session token |
| Photos stored as base64 in SQLite (BLOB bloat) | Store file path; save image to `getApplicationDocumentsDirectory()` |
| No DB encryption | Consider `sqflite_sqlcipher` for sensitive financial data |

### F.5 Performance

| Issue | Fix |
|---|---|
| 60 MB APK | Enable `isMinifyEnabled`, `isShrinkResources` (TASK-012) |
| `fl_chart` rendering hardcoded data on every `setState` | Memoize chart sections — use `const` constructors where data is static |
| `_loadAllHrmData()` runs 4 DB queries sequentially | Use `Future.wait([q1, q2, q3, q4])` |
| `BranchesScreen._loadBranches()` runs N+1 queries per branch | Replace with a single `JOIN` query |
| Full `fetchCustomers()` called after every comm log add | Use targeted `notifyListeners()` with incremental update |

### F.6 Native configuration

| Issue | Fix |
|---|---|
| `minSdk = flutter.minSdkVersion` (defaults to 21) | Confirm API 21 (Android 5.0) is acceptable; consider bumping to 24 for modern APIs |
| `targetSdk = flutter.targetSdkVersion` | Verify this is ≥ 34 to pass Play Store review |
| No adaptive icon | Add `mipmap-anydpi-v26/ic_launcher.xml` for Android 8+ adaptive icon |
| No splash screen theme | Configure `launch_background.xml` for white/branded background |
| App label is `"SARVOOCCH Microcare"` | Confirm branding with client |

---

## G. API Blockers

> All functionality currently runs against local SQLite with seeded demo data. No backend endpoints exist in the codebase. The following endpoints must be available from the backend before these features can be production-ready.

### G.1 Authentication API (BLOCKER — affects all screens)

| Endpoint | Method | Body | Response | Required by |
|---|---|---|---|---|
| `/api/auth/login` | POST | `{username, password}` | `{token, user, role, branch}` | TASK-014 |
| `/api/auth/logout` | POST | `Authorization: Bearer` | `200` | TASK-014 |
| `/api/auth/refresh` | POST | `{refresh_token}` | `{token}` | TASK-014 |
| `/api/auth/change-password` | POST | `{current, new}` | `200` | TASK-017 |

### G.2 Customer & KYC API

| Endpoint | Method | Notes | Required by |
|---|---|---|---|
| `GET /api/customers` | GET | Filterable by branch, agent, stage | TASK-016 |
| `POST /api/customers` | POST | Create lead | TASK-016 |
| `PUT /api/customers/{id}/kyc` | PUT | Full KYC form with photo upload | TASK-008, TASK-011 |
| `POST /api/customers/{id}/kyc-verify` | POST | Trigger bureau check (Aadhaar/PAN) | Requires NSDL/UIDAI integration on backend |

### G.3 Applications & Loans API

| Endpoint | Method | Notes | Required by |
|---|---|---|---|
| `GET /api/applications` | GET | Role-filtered | TASK-016 |
| `POST /api/applications` | POST | Submit new loan application | TASK-016 |
| `PATCH /api/applications/{id}/advance` | PATCH | Move pipeline stage | TASK-016 |
| `GET /api/loans` | GET | With schedule & payment history | TASK-016 |
| `POST /api/loans/{id}/pay` | POST | Record installment payment | TASK-022 |
| `POST /api/loans/{id}/settle` | POST | Full settlement | TASK-016 |

### G.4 HRM API

| Endpoint | Method | Notes | Required by |
|---|---|---|---|
| `GET /api/employees` | GET | All employees, manager-filtered | TASK-016 |
| `POST /api/employees` | POST | Add new employee | TASK-016 |
| `GET /api/leaves` | GET | By user or branch | TASK-016 |
| `POST /api/leaves` | POST | Apply for leave | TASK-016 |
| `PATCH /api/leaves/{id}` | PATCH | Approve/reject | TASK-016 |

### G.5 WhatsApp API (BLOCKER — no real integration possible without backend)

| Endpoint | Method | Notes | Required by |
|---|---|---|---|
| `POST /api/whatsapp/send-otp` | POST | Triggers WhatsApp Business API | TASK-022 |
| `POST /api/whatsapp/verify-otp` | POST | Validates server-side OTP | TASK-022 |

### G.6 Documents API (BLOCKER — PDF QR codes must point to real URLs)

| Endpoint | Notes | Required by |
|---|---|---|
| `GET /api/loans/{id}/card` | Loan passbook shareable URL | TASK-010 |
| `GET /api/applications/{id}/sanction.pdf` | Sanction letter PDF | TASK-010 |
| `GET /api/loans/{id}/noc.pdf` | NOC certificate PDF | TASK-010 |

### G.7 Backend endpoints that CANNOT be faked

- **NSDL Aadhaar API / UIDAI OTP** — KYC document verification requires a licensed partner API.
- **CIBIL / Equifax credit bureau** — Credit check requires RBI-regulated bureau access. Mobile cannot bypass this.
- **eNACH / NPCI mandate registration** — Requires bank integration. No frontend-only simulation is valid.
- **UPI deep-link for real payment** — The existing QR generates a valid UPI URI, but payment confirmation must come from a payment gateway webhook, not a button tap.

---

## H. Testing Strategy

### H.1 Unit Tests (target: `test/`)

| Test Suite | Coverage Target | Priority |
|---|---|---|
| `LoanProvider` — KPI calculations (disbursed, outstanding, overdue) | All calculation paths | P0 |
| `LoanProvider` — EMI schedule generation (reducing + flat, edge cases) | Rounding, last installment | P1 |
| `LoanProvider` — Settlement quote accuracy | Principal + next interest | P1 |
| `CustomerProvider` — KYC form save + mandatory field validation | All 40+ fields | P1 |
| `AttendanceProvider` — Haversine distance calculation | Known coords | P0 |
| `AttendanceProvider` — Punch-in within/outside radius | Both branches | P1 |
| `AuthProvider` — Login success + failure paths | Role routing | P0 |
| `ApiService` — Mock HTTP client for all endpoints | 200, 401, 500 | P1 |
| `PdfService` — PDF generation produces non-empty bytes | All 3 doc types | P1 |

### H.2 Widget Tests (target: `test/widget/`)

| Test | Priority |
|---|---|
| `LoginScreen` — valid credentials enable Sign In, error shows on failure | P0 |
| `DashboardScreen` — KPI cards render with seeded data | P0 |
| `KycFormScreen` — all 4 steps navigate correctly, mandatory field validation | P1 |
| `ApplyLoanScreen` — product dropdown populates, amount range enforced | P1 |
| `ApplicationDetailScreen` — correct action buttons per role/status | P1 |
| `AttendanceScreen` — Punch In disabled after first punch | P1 |
| `HrmScreen` — all 4 tabs render without exception | P0 |
| `FieldTasksScreen` — list and map views render correct task count | P2 |
| `CustomerPortalScreen` — only shows loans matching `user.customerId` | P1 |

### H.3 Integration Tests (target: `integration_test/`)

> The existing `test/user_flows_test.dart` (6 flows) is the correct model. Extend it.

| Test Flow | Priority |
|---|---|
| Full loan lifecycle: KYC → Pre-GRT → Apply → Review → Approve → Sanction → Disburse → Pay 3 EMIs → Settle → NOC | P0 |
| Field officer punch-in at correct branch GPS coords (using `geolocator` mock) | P1 |
| Offline customer creation → sync → visible to manager | P1 |
| WhatsApp OTP flow (mocked backend) | P2 |
| Role isolation: customer cannot access `/dashboard`; field agent cannot access `/hrm` | P1 |
| Admin resets DB → all providers refresh correctly | P1 |

### H.4 Device tests

| Test | Devices | Priority |
|---|---|---|
| APK installs and launches on Android 8.0 (API 26) | Physical device | P0 |
| APK installs and launches on Android 14 (API 34) | Physical device or emulator | P0 |
| GPS punch-in at actual branch location | Physical device | P1 |
| Photo capture on device camera | Physical device | P1 |
| PDF print/share dialog opens correctly | Physical device | P1 |
| Offline mode: all read operations work without internet | Both | P1 |
| Memory: no leak after 30 minutes of navigation | Profiler | P2 |

### H.5 Release tests (before every APK build)

1. `flutter analyze --no-pub` — 0 errors.
2. `flutter test` — all unit and widget tests pass.
3. `flutter test integration_test/` — all integration tests pass.
4. `flutter build apk --release` — build succeeds.
5. `apksigner verify --print-certs release.apk` — signed with release key.
6. Install release APK on clean device — verify no debug/demo data is exposed in UI.
7. ProGuard — verify no `ClassNotFoundException` at runtime.

---

## I. Final APK Release Strategy

### I.1 Build steps

```bash
# 1. Clean
flutter clean

# 2. Get dependencies
flutter pub get

# 3. Run all tests
flutter test
flutter test integration_test/

# 4. Build release APK (split per ABI recommended for Play Store)
flutter build apk --release --split-per-abi

# 5. Or build App Bundle for Play Store (preferred)
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info/

# 6. Verify signing
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

### I.2 Pre-release checklist

- [ ] Production `applicationId` confirmed and set
- [ ] Release keystore generated and stored securely (NOT in repository)
- [ ] `key.properties` configured with correct keystore paths
- [ ] `isMinifyEnabled = true` and `isShrinkResources = true` enabled
- [ ] `debugShowCheckedModeBanner: false` (already done ✅)
- [ ] All `sarvocch.demo` URLs replaced with production backend URLs
- [ ] All demo/mock accounts removed or locked behind a debug build flag
- [ ] `DemoSeedData` gated behind `kDebugMode` (never seeds in release)
- [ ] Reset DB button in `AdminSettingsScreen` hidden in release build
- [ ] `INTERNET` permission added to manifest
- [ ] `targetSdk >= 34` for Play Store compliance
- [ ] Firebase `google-services.json` placed in `android/app/`
- [ ] All API keys in environment (not hardcoded)
- [ ] Privacy policy URL configured (required by Play Store)
- [ ] App tested on minimum supported Android version (API 21 or 24)

### I.3 Play Store requirements

- **App category:** Finance
- **Content rating:** Everyone (no violence/adult content)
- **Permissions justification:** Location (geofenced attendance), Camera (KYC photos), Storage (PDF download) — must be explained in Play Store listing
- **Data safety form:** Must declare: location data collected, financial data collected (loan amounts, payment history), not shared with third parties except backend

---

## J. Critical Risks

### J.1 Release blockers (APK cannot ship to production)

| # | Risk | Severity | Evidence |
|---|---|---|---|
| R-01 | **APK signed with debug key** — Play Store will reject | BLOCKER | `signingConfig = signingConfigs.getByName("debug")` |
| R-02 | **No INTERNET permission** — all API calls will fail | BLOCKER | Manifest has zero `<uses-permission>` tags |
| R-03 | **HRM screen crashes on fresh install** — `leaves` and `perf` tables don't exist | BLOCKER | `FROM leaves` / `FROM perf` query on non-existent tables |
| R-04 | **GPS is hardcoded** — geofenced attendance is non-functional | BLOCKER | `_mockLat = 22.7510` sent to real punch-in flow |
| R-05 | **Authentication is demo-only** — any user can log in as any role | BLOCKER | SQLite plaintext passwords, no token, no session |
| R-06 | **Zero backend connectivity** — the app is entirely offline-demo | BLOCKER | No HTTP client package; no API calls anywhere |

### J.2 High-priority risks (pre-launch quality issues)

| # | Risk | Evidence |
|---|---|---|
| R-07 | Overdue amount KPI is hardcoded (₹5,200) — misleads Branch Manager | `loan_provider.dart:108` |
| R-08 | KYC bureau check is fake — violates RBI KYC norms for production MFI | `kyc_verify_screen.dart:69` |
| R-09 | WhatsApp OTP accepts `123456` universally — identity verification is bypassed | `customer_provider.dart:233` |
| R-10 | NOC / Sanction Letter / Loan Passbook cannot be generated as real PDFs | Only text widgets rendered |
| R-11 | UPI payment is simulated — no actual money movement or confirmation | Snackbar confirms "payment" without gateway call |
| R-12 | `AuthProvider.init()` not called from app startup — demo auto-login never works | `main.dart` — no `init()` call |
| R-13 | `eNACH` mandate shown as "Active (SBIN)" hardcoded string — misleading for customers | `customer_portal_screen.dart:159` |
| R-14 | APK is 60 MB — no minification/shrinking — user acquisition will suffer | Confirmed by APK file size |

### J.3 Compliance risks

| # | Risk |
|---|---|
| R-15 | Storing passwords in plaintext violates basic security requirements; RBI guidelines for MFIs require secure credential management |
| R-16 | No audit trail for who performed what action — required for RBI-regulated MFI operations (partial: `approvals` table exists for loan pipeline but not for other operations) |
| R-17 | KYC photos not encrypted at rest — sensitive PII |
| R-18 | App Data directory used for SQLite — not encrypted; on rooted devices, all borrower financial data is accessible |

---

## Quick Reference: Top 10 Highest-Priority Tasks

| Rank | Task ID | Title | Blocks |
|---|---|---|---|
| 1 | TASK-001 | Fix missing `leaves`/`perf` DB tables (HRM crash) | HRM usability |
| 2 | TASK-002 | Fix `AuthProvider.init()` never called at startup | All authenticated flows |
| 3 | TASK-003 | Replace mocked GPS with real `geolocator` | Attendance validity |
| 4 | TASK-004 | Add Android permissions to `AndroidManifest.xml` | Networking, GPS, Camera |
| 5 | TASK-005 | Fix broken `widget_test.dart` (counter template) | CI pipeline |
| 6 | TASK-012 | Production release signing + minification | Play Store submission |
| 7 | TASK-006 | Fix hardcoded overdue KPI | Data accuracy |
| 8 | TASK-007 | Fix hardcoded dashboard pie chart | Data accuracy |
| 9 | TASK-014 | Build `ApiService` + real backend authentication | All backend features |
| 10 | TASK-015 | Add route guard for authenticated navigation | Security |

---

*This document is the single source of truth for the Android implementation work. All tasks are based on direct code inspection of the repository. No assumptions have been made about features not present in the codebase.*

