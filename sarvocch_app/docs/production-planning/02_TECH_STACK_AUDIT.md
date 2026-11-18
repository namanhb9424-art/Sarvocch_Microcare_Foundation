# Technology stack audit

## Verified stack

| Layer | Current implementation | Finding |
|---|---|---|
| Mobile UI | Flutter / Dart, Material, many standalone screen files | Cross-platform shell exists; no formal feature/domain layers |
| Mobile state | provider 6.1.5+1 / ChangeNotifier | Retain short term; providers currently mix state, queries and business rules |
| Mobile persistence | sqflite 2.4.5 on mobile, sqflite_common_ffi 2.4.5 for desktop, path_provider/path | Local SQLite exists; schema is raw SQL in DatabaseHelper; one migration version transition |
| Server | Flask >=3.0, Python configured as 3.12.7 in render.yaml, SQLite | Large single-file app, server routes and business rules embedded in app.py |
| Authentication | Werkzeug password hashing and Flask session on server; plaintext comparison in Flutter local users table | Web and mobile authentication semantics differ; demo login/auto-login exists |
| Documents | ReportLab server PDFs; Flutter pdf and printing packages | Generated finance documents are print/share capable; visual parity still needs review |
| Network/sync | http 1.6.0; connectivity_plus 6.1.5; Flask /api/sync | Real server path exists, but local-only and mock paths coexist; no shared database between devices |
| Location | geolocator 13.0.4, permission_handler 11.4.0; server Haversine logic | Purpose is attendance/field visits; location permission disclosures and spoofing threat model are needed |
| File/media | image_picker 1.2.4; server upload allowlist | File storage is not normalized into attachment metadata and retention policy |
| UI libraries | google_fonts 9.0.0, fl_chart 1.3.0, shimmer 4.0.0, qr_flutter 4.1.0, cupertino_icons 1.0.9 | Verify font assets/offline behavior; use chart/shimmer only where product needs them |
| Helpers | intl 0.20.3, path 1.9.1, uuid 4.6.0 | Dates, paths and identifiers |
| Secure storage | flutter_secure_storage 9.2.4 | Present but does not fix plaintext SQLite passwords or app authorization flaws |
| HTTP/PDF | http 1.6.0, pdf 3.13.1, printing 5.15.1 | HTTP is not a required dependency for local business operations; server sync is optional future boundary |
| Tests | flutter_test; flutter_lints 6.0.0 | Test suite exists; not run during this audit |

The package version listing is from pubspec.lock in the nested source tree. pubspec.yaml declares ranges; versions should be rechecked at implementation time. No dependency installation or upgrade was performed.

## Architecture findings

Flutter entrypoint constructs six providers and a MaterialApp named-route table (sarvocch_app/lib/main.dart:38-98). DatabaseHelper owns file path, schema creation, migration and demo seeding (sarvocch_app/lib/data/database_helper.dart:8-46, 93-539). Many providers and screens call the database directly; loan/payment updates are written from LoanProvider and UI widgets. Server app.py repeats the same domain logic. The app therefore has two business-rule implementations with no generated contract or single canonical service layer.

SQLite is used as app persistence, but Flutter database schema version is only 2 and the version 2 upgrade creates four tables (database_helper.dart:41-91). Server schema changes use add-column migration helpers rather than a versioned migration registry (app.py:2947-2975). Neither path currently provides a tested, reversible upgrade chain.

## Data and financial representation

Current finance values use Dart double and SQLite REAL (e.g. LoanModel and database_helper.dart:160-286). SQLite REAL is binary floating point; it is not exact decimal money. Proposed production representation: currency code plus signed 64-bit minor units (INR paise for INR), and integer-scaled quantities with an explicit unit precision. Calculate in integer/rational or a vetted decimal layer and persist posted totals; never store financial amounts as REAL. Keep printed display rounding separate from posting arithmetic.

## Architecture recommendation

For the verified offline SQLite need, adopt Drift over the existing SQLite file only after scope approval. It supplies typed table/query code, transaction support and schema migration tooling while retaining SQLite; use one database source of truth behind repositories/use cases. Keep Provider at presentation boundary initially. Separate presentation, application rules, domain types and persistence; do not port business logic into widgets. Use repositories with an interchangeable local store and future sync adapter. Preserve migration compatibility with the existing SQLite data before replacing DatabaseHelper.

The Flutter plugin/wrapper set does not prove that every target is production-supported. Establish Android/iOS as release targets first; then separately qualify web and desktop, especially SQLite encryption, attachments, secure storage, printing, location and backup behavior.
