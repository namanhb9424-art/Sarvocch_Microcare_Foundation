# SARVOOCCH — Repository Discovery & Ecosystem Audit

**Document Classification:** Internal Technical Baseline  
**Auditor:** Autonomous Software Engineering Team  
**Date:** 3 November 2026  
**Product Name:** SARVOOCCH (Spelling Invariant: S-A-R-V-O-O-C-C-H)  
**Target Delivery Date:** 4 November 2026  

---

## 1. Executive Summary

This discovery audit catalogues the software components, repositories, branches, dependencies, and configuration of the **SARVOOCCH** microfinance ecosystem across the workspace `/Users/vaidik`.

The ecosystem consists of:
1. **Reference Web Application (`/Users/vaidik/sarvocch_repo`)**: A Python/Flask monolith using SQLite, Jinja2 templates, Bootstrap 5.3, and ReportLab for financial documents and passbooks.
2. **Cross-Platform Mobile Application (`/Users/vaidik/sarvocch_app` and mirrored in `sarvocch_repo/sarvocch_app`)**: A Flutter 3.47 application built with Dart 3.13, Provider state management, and `sqflite` offline-first database.
3. **Remote Version Control**:
   - Upstream GitHub Repository: `https://github.com/namanhb9424-art/Sarvocch_Microcare_Foundation.git`
   - Active Working Branch: `feature/flutter-mobile-app` (Pull Request #1 open)
   - Official Release Asset: `v1.0.0-apk` with `sarvocch_microcare.apk` attached.

---

## 2. Filesystem & Repository Layout

### 2.1 Workspace Root (`/Users/vaidik`)
- `/Users/vaidik/sarvocch_repo`: Main Git repository cloned from GitHub.
  - Working branch: `feature/flutter-mobile-app`
  - Upstream tracked branch: `origin/feature/flutter-mobile-app`
  - HEAD commit: `2ea25b6` ("feat(mobile): add Sarvocch Microcare Flutter cross-platform mobile application")
- `/Users/vaidik/sarvocch_app`: Independent Flutter workspace root used for development and Android builds.
  - Sourced assets: Official blue squircle brand logo (`assets/icon/app_logo.png`, 1254x1254px).
  - Standalone Android APK binary: `sarvocch_microcare.apk` (62.3 MB).

### 2.2 Directory Structure (`sarvocch_repo`)
```text
sarvocch_repo/
├── .git/                      # Git version control metadata
├── .gitignore                 # Python + Flutter build ignore rules
├── .vercelignore              # Vercel deployment exclusions
├── Procfile                   # Web process definition (gunicorn app:app)
├── README.md                  # Project overview, demo logins, mobile app guide
├── render.yaml                # Render cloud deployment blueprint
├── requirements.txt           # Python dependencies (Flask, reportlab, gunicorn)
├── vercel.json                # Vercel serverless routing config
├── app.py                     # Monolithic Flask server (3,090 lines, 24 tables, 40+ endpoints)
├── api/
│   └── index.py               # Serverless entrypoint wrapping Flask app
├── static/
│   ├── style.css              # Custom CSS variables, teal palette, table layouts
│   ├── sw.js                  # ServiceWorker for offline cache
│   └── icons/                 # Web app icons (favicon, 192px, 512px)
├── templates/                 # 38 Jinja2 HTML templates
│   ├── base.html              # Master layout, navigation bar, flash messages
│   ├── dashboard.html         # Admin & management operational KPIs
│   ├── kyc_form.html          # Bilingual applicant & husband consent form
│   ├── apply.html             # Loan application & cashflow appraisal
│   ├── pregrt_form.html       # Group Recognition Test formation & discipline
│   ├── field.html             # Field agent tasks, GPS coordinates & collections
│   ├── attendance.html        # Geofence punch & attendance regularisation
│   ├── hrm.html               # Staff onboarding, leave pipeline, payroll
│   ├── branches.html          # Branch GPS coordinates & portfolio summary
│   ├── whatsapp.html          # Click-to-chat OTP verification hub
│   └── (28 additional templates)
├── sarvocch_app/              # Complete Flutter cross-platform mobile client
│   ├── pubspec.yaml           # Flutter dependencies & assets declarations
│   ├── lib/                   # 19 screens, 6 providers, 8 data models, widgets
│   ├── test/                  # Automated integration tests (6/6 passing)
│   └── android/               # Native Android configuration & mipmap icons
└── docs/                      # Enterprise engineering documentation
```

---

## 3. Technology Stack & Runtime Verification

| Component | Technology | Version | Location / Command | Runtime Status |
| :--- | :--- | :--- | :--- | :--- |
| **Operating System** | macOS Sequoia (Darwin ARM64) | 25.6.0 | Host machine | Active |
| **Python** | CPython | 3.14.7 | `/opt/homebrew/bin/python3` | Verified |
| **Virtual Environment** | Python venv | 3.14.7 | `/Users/vaidik/sarvocch_repo/.venv` | Installed |
| **Web Server** | Flask / Werkzeug | 3.1.3 | Port 5001 (daemonized) | **ONLINE (HTTP 200/302)** |
| **PDF Engine** | ReportLab | 5.1.0 | Python virtualenv | Verified |
| **Database** | SQLite3 | 3.x | `instance/sarvocch.db` | 24 tables initialized |
| **Flutter SDK** | Flutter Stable | 3.47.5 | Channel stable | Verified |
| **Dart SDK** | Dart | 3.13.4 | Bundled with Flutter | Verified |
| **Android Tooling** | Android SDK / ADB | Platform Tools 35 | `/opt/homebrew/share/android-commandlinetools` | Available |
| **GitHub CLI** | `gh` | 2.101.0 | Authenticated as `vaidikchitwar` | Write permissions |

---

## 4. Git History & Branches
1. `c647dd8` — `first commit` (Base Flask web portal from namanhb9424-art).
2. `2ea25b6` — `feat(mobile): add Sarvocch Microcare Flutter cross-platform mobile application` (Full Flutter codebase, assets, launcher icons, unit tests).
3. **Pull Request**: Open at `https://github.com/namanhb9424-art/Sarvocch_Microcare_Foundation/pull/1`.
4. **Active Branch**: `feature/flutter-mobile-app` tracking `origin/feature/flutter-mobile-app`.

---

## 5. Risk Assessment & Constraints
1. **Port 5000 Collision on macOS**: macOS AirPlay Receiver occupies default port 5000. Web server is successfully configured on port `5001`.
2. **Product Name Standardization**: The directive mandates the exact name **SARVOOCCH**. Legacy files spell it as "Sarvocch" or "Sarvocch Microcare Foundation". Updates must preserve visual design while standardizing this exact identifier.
3. **Zero Regression**: Every single one of the 38 website templates and 40 backend endpoints must be supported. No feature simplification permitted.
