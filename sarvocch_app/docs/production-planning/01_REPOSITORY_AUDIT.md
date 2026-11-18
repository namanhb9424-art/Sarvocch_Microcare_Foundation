# Repository audit

Audit date: 5 November 2026. Read-only inspection; no existing files were modified.

## Git identity and baseline

| Item | Verified result |
|---|---|
| Workspace | /Users/vaidik/sarvocch_app |
| Workspace remote | None reported by git remote -v |
| Workspace branch | main |
| Workspace history | No commits; git log and HEAD lookup fail because the tree is not a Git repository with commits |
| Workspace status | All app/platform/docs files were untracked at audit start; no pre-existing tracked changes to overwrite |
| Local website/source repo | /Users/vaidik/sarvocch_repo |
| Source repo remote | https://github.com/namanhb9424-art/Sarvocch_Microcare_Foundation.git |
| Source repo branch | feature/flutter-mobile-app |
| Source repo status | Clean at audit time |
| Source repo baseline | df56cb71e2104e742217a658e6b20af6db1c5fc3 |

The Flutter workspace's main.dart, database_helper.dart and pubspec.yaml compare byte-for-byte with the nested Flutter project in the Git-tracked source repository. This makes the supplied repo the traceable baseline even though the open workspace copy has no commit history.

## Project identity and architecture

The source README names SARVOOCCH Microcare Foundation – Micro Finance Portal and describes a Flask + SQLite prototype. app.py begins with the same identity and notes that KYC, payment gateway, eNACH and WhatsApp paths are mocked (app.py:1-5; README.md:1-5). The Flutter title and model files independently confirm the microfinance identity (sarvocch_app/lib/main.dart:64-66; sarvocch_app/lib/models/loan_model.dart:74-100).

The Flask app is a server-rendered monolith: one 3,186-line app.py defines routing, permission checks, SQLite schema, validation, calculations, PDF generation, file handling, migration helpers and seed data. UI is rendered from templates/*.html; static/app.js, static/style.css, icons and static/sw.js provide client behavior and PWA caching. The Flutter client is a second presentation/data implementation with screens, Provider-based state, sqflite database helper and services. The two implementations duplicate business rules.

There is no first-party public manufacturing site, product catalogue or contact/enquiry site in this source tree. It is an authenticated operational portal. Its local root redirects to the dashboard or login. The README's example host is localhost; deployment manifests describe Render and Vercel configurations but do not establish a canonical public domain.

## Repository contents inspected

- Flask service: app.py, api/index.py, requirements.txt, Procfile, Dockerfile, docker-compose.yml, render.yaml, vercel.json.
- Server-rendered pages: dashboard, CRM, KYC, applications, loans, portal, field, attendance, branch, HRM, product configuration, pre-GRT, sync, WhatsApp, settings and print/PDF templates.
- Flutter source: sarvocch_app/lib, assets, Android/iOS/desktop/web wrappers, and test/.
- Documentation: project, operations, requirements, audit, testing, security, deployment and mobile planning documents.
- No separate factory/product imagery, transformer catalogue or manufacturing documents were found in the reported file inventory.
- Existing audit and parity documents date from 3 November 2026. They are evidence about prior analysis, not source truth; several claims conflict with the code (see 20_RISK_REGISTER.md).

## Existing functionality (verified by source)

The 20 website navigation modules are defined in app.py:58-80. Routes cover authentication, dashboard and reports, loan products, CRM, KYC onboarding/verification, loan applications and approvals, disbursement, schedules, payments/settlement, field tasks, attendance/geofencing, branches, employees/HRM, pre-GRT groups, WhatsApp simulation, offline-sync endpoint, settings and user roles (app.py:494-2907). The current SQLite schema is in app.py:107-171 and additive migrations in app.py:2947-2975.

Flutter routes are declared in sarvocch_app/lib/main.dart:68-95; providers are registered at lines 55-63. Providers and screens often call DatabaseHelper directly; some screens also call raw SQLite directly. No API/repository/use-case boundary consistently separates UI from persistence.

## Runtime, tests and CI

The workspace package declares Dart >=3.0.0 <4.0.0. The installed SDK metadata reports Flutter 3.47.5 / Dart 3.13.4; this is the local toolchain version, not a pinned project requirement. Android uses Java/Kotlin 17 and Flutter-supplied SDK versions; iOS minimum deployment target is 15.0 (android/app/build.gradle.kts; ios/Runner.xcodeproj/project.pbxproj). Flutter wrappers exist for Android, iOS, macOS, Windows, Linux and web, but SQLite implementation/runtime support is not equally verified on all targets.

Flutter tests exist in test/widget_test.dart, test/user_flows_test.dart and test/comprehensive_parity_test.dart. The Git-tracked repo also has manual QA guides and parity matrices. No tests or analyzers were executed because this was an audit, not a test request. No automated CI workflow was found in the inspected source list; confirm repository settings and hidden workflows before release.

## Evidence boundaries

No credential values, test passwords, session keys, or token strings are copied into these reports. The source contains demo authentication material and a development secret fallback; findings are described without reproducing values. Runtime database and upload contents were not opened because they may contain personal or financial data.
