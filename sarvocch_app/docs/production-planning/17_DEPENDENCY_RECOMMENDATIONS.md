# Dependency recommendations

## Current Flutter dependencies

The app currently uses Provider, sqflite/sqflite_common_ffi, path/path_provider, secure storage, HTTP/connectivity, geolocation/permissions, image picker, PDF/printing, charts, shimmer, QR, UUID, intl and Google Fonts. Direct versions are recorded in the nested app's pubspec.lock; declarations in pubspec.yaml are ranges. No package was installed or upgraded during this audit.

## Recommended direction

| Need | Recommendation | Reason / constraint |
|---|---|---|
| Relational local DB | Evaluate Drift as target over SQLite | It provides typed generated queries, transactions, migrations and reactive queries; it remains SQLite. Pin a compatible version only during a reviewed implementation change. Current registry page showed Drift 2.35.3 on 5 Nov 2026; recheck release, SDK and platform support then. [Flutter persistence guidance](https://docs.flutter.dev/data-and-backend/persistence/choose-a-database), [Drift package](https://pub.dev/packages/drift). |
| Code generation | Use drift_dev + build_runner only if Drift selected | Generated schema/query code has reproducible build requirements; commit generated output or regenerate according to project policy. Do not add until architecture decision. |
| State management | Retain Provider initially | Existing app is Provider-based; replacing state management does not solve schema, authorization or business-rule duplication. Introduce repository/use-case boundaries first. |
| Secure secret storage | Keep existing platform secure-storage integration only for keys/tokens | It does not encrypt SQLite, attachments, backups or logs. Test actual iOS/Android platform behavior and key recovery. Avoid duplicating storage packages. |
| Cryptographic database | SQLite3MultipleCiphers is now wired through sqlite3.dart's native asset hook and sqflite_common_ffi | Native Android/iOS/desktop builds use the encrypted SQLite implementation. Device-level platform verification, key-loss recovery, temp/WAL review and release support qualification remain required. |
| PDF/printing | Keep current pdf/printing if supported output passes accessibility/layout tests | Already supports offline rendering. Verify fonts, complex scripts, printer/share behavior and attachments on supported devices. |
| Location/media | Retain only needed geolocator, permission_handler, image_picker | Keep permission prompts purpose-specific and provide a documented fallback where business policy permits. |
| Network/connectivity | Keep behind optional sync adapter | Core operations must not depend on HTTP. Connectivity status is advisory; only application-level acknowledgement indicates sync success. |
| Charts/loading visuals | Keep fl_chart/shimmer only for used screens | Avoid libraries with no clear user function; do not replace core UI without measured need. |
| IDs/date/format | Keep UUID and intl as appropriate | Stable UUIDs are needed for future sync; local database integer IDs remain internal. |

## Money and quantity representation

SQLite INTEGER is an exact signed 64-bit integer, while REAL stores approximate IEEE-754 binary floating point. Use integer minor units for money and integer-scaled quantities with unit and declared scale. ([SQLite floating-point documentation](https://www.sqlite.org/floatingpoint.html)). Do not add a “decimal” dependency until formula/rounding rules are approved; implement calculations with reviewed integer/rational logic or a maintained decimal package and store posted totals as integers.

## Dependency governance

- Recheck supported Dart/Flutter SDKs, Android/iOS minimums, transitive licenses and security advisories at implementation/release time.
- Prefer packages with active maintenance, documented platform support, reproducible releases and a migration path.
- Commit lockfile for application builds; use reproducible CI and review `pub outdated`/security notices during planned maintenance, not as an unreviewed auto-upgrade.
- Keep package count small. A package does not replace server authorization, secure design, threat modeling or migration tests.
- Do not introduce a cloud database SDK unless the owner explicitly approves online service and data residency/ownership requirements.
