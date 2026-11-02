# Sarvocch Microcare Foundation – Micro Finance Portal (prototype)

Flask + SQLite prototype. No paid services: KYC, payments, eNACH and WhatsApp are mocked.
Repo: https://github.com/Hrishi-jain/Microfin_Portal.git

## Run locally
```
pip install -r requirements.txt
python app.py          # http://127.0.0.1:5000
```
The database is created and seeded on first start (`instance/sarvocch.db`). Delete it to reset. If you upgrade from an older
copy, new tables are added automatically on the next start; delete the DB to get the new demo data.

Demo logins: admin/admin123, manager1/manager123, uw1/uw123, agent1-3/agent123, cust1/cust123.

---

## 📱 Sarvocch Microcare Flutter Mobile Application (`sarvocch_app/`)

A high-performance, modern cross-platform Flutter application providing 100% feature and visual parity with the web portal, styled with the exact `#0F766E` teal brand palette, Inter typography, smooth animations, and offline-first SQLite database.

### Key Mobile Features
- **Official Brand Identity**: Sourced directly from official badge logo (`assets/icon/app_logo.png`) with adaptive Android launcher mipmaps (mdpi to xxxhdpi) and branded Splash & Login screens.
- **5-Role RBAC & Instant Role Switcher**:
  - `admin` (`Aarav Admin`): Full system control, MFI lending policy thresholds, database resets.
  - `manager` (`Meera Manager`): Pre-GRT group verifications, sanction limits, approval pipeline.
  - `underwriter` (`Uday Underwriter`): Risk assessment, household EMI-to-income checks (<=60%), credit decisions.
  - `field_agent` (`Ravi Field Officer`): Onboarding bilingual KYC, field collections with automatic payment & schedule updates, GPS attendance.
  - `customer` (`Sunita Verma`): Self-service loan portal, interactive UPI QR repayment simulator, NOC and passbook download.
- **Robust Navigation Hierarchy**: Safe routing architecture respecting Android back-button pop scopes, preventing accidental app exits on home screens, and full stack management during role switches.
- **Local SQLite Engine**: Powered by `sqflite` with in-memory test fallback, initializing 18 relational tables mirroring the Flask schema.
- **Cloud Database Quotations & Sync Engine**: Multi-cloud comparison (Neon PostgreSQL, Supabase, Neon Serverless, AWS RDS, GCP Cloud SQL, Turso LibSQL, PlanetScale) with real-time ping simulation and architecture bridge guidelines.

### Running the Mobile App
```bash
cd sarvocch_app
flutter pub get
flutter test test/user_flows_test.dart  # 6/6 tests verify end-to-end user flows
flutter run                             # Run on connected device or emulator
flutter build apk --release             # Generate release APK
```
Release APK binary is generated at `sarvocch_app/build/app/outputs/flutter-apk/app-release.apk`.


## Onboarding flow (new)
1. **New Customer (KYC Form)** – bilingual digital form: applicant, family members, house/land/bank, financial info,
   **husband's information and consent for the loan**, declarations, address-visit verification, photos.
   Printable at `/crm/<id>/kyc-form/print`.
2. **KYC Verify** – Aadhaar / PAN / Voter ID check (mock).
3. **Pre-GRT (Group form)** – 5-10 members, per-member confirmations; submit, then the branch manager verifies or returns it
   with remarks. Printable.
4. **Loan Application** – needs the KYC form. Adds previous loans, monthly cash flow (income / expense), documents deposited,
   life insurance, group / centre recommendations and a declaration. Risk flags are shown to the approver.
5. **Approval chain** – Submitted > Review > Approve (approver may reduce the amount) > Sanction > Disburse; every step is logged.

Rules (all editable by Admin in **Settings**): age 18-55, unique mobile number, group size 2-5, EMI <= 60% of household income, household income limit, processing fee 1.5% + GST shown as CGST/SGST, at least 2 documents deposited.
Pre-GRT keeps only the last 4 digits of Aadhaar.

## Added in latest batch
- **Settings** (Admin): age limits, group size, income limit, EMI %, GST rate, punch-out hours/radius. **Branches** (Admin): add branches with GPS location. **Holidays**: EMI dates skip Sat/Sun/holidays.
- **Attendance**: punch in/out within the branch radius; edit requests go staff -> manager, manager -> admin.
- **Full settlement** `/loans/<id>/settle`: principal outstanding + next instalment's interest. **Loan card** `/loans/<id>/card`. **Employee printout** `/employees/<id>/print`.
- **Group application** `/pregrt/<id>/apply` (verified Pre-GRT only): 2-5 members apply together. Emergency Loan (12%) is Admin-only.
- **Dashboard**: hover tooltips on charts; click a bar/slice or a tile to see the loans/applications/payments behind it.
- Onboarding form: co-applicant relation (Husband/Son, Wife, Other) and neighbour details.

## Deploy
Render: `render.yaml` + `Procfile` (gunicorn app:app). Vercel: `vercel.json` + `api/index.py` (data lives in `/tmp`, resets – demo only).
Set `SECRET_KEY` in production. Use a real database and encrypt bank account numbers before going live.
