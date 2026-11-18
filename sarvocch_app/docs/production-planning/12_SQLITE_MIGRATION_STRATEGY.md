# SQLite migration strategy

## Current baseline

Flutter `DatabaseHelper` is at schema version 32. New installs create the MFI tables with foreign-key declarations and enable SQLite foreign-key enforcement on every connection. Version 23 adds a transactional rebuild for applications, application-extra, approvals, loans, schedule and payments. Version 24 adds a transactional rebuild for users, employees, customers, KYC, PreGRT, field tasks, attendance, audit and related operational tables. Version 25 snapshots product name, repayment method, amount and tenure limits, and configured fee on each new loan application; older applications are backfilled from their linked product. Approval and disbursement use the saved terms, so later catalogue edits do not silently change an application in progress. Version 26 adds a duplicate-safe partial unique index for one pending attendance correction per user/day, preserving and reporting existing duplicate groups. Version 28 resolves ambiguous pending collection-task loan links without deleting tasks. Version 29 adds employee salary paise storage, and version 30 adds paise companions for household income and expense components, requested amount and derived cashflow totals; migrations backfill only values exactly representable in paise, retain legacy columns, and report invalid rows for review. Version 31 redacts historical Pre-GRT voter IDs to their last four characters and enforces the masked-suffix limit on new writes. Version 32 adds an immutable recovery-event ledger whose operator identity is a snapshot from the database being replaced, so restore attribution does not depend on user IDs in the imported database. New MFI money writes dual-write legacy-compatible values and integer paise with SQL consistency triggers. Each relationship group is rebuilt only when preflight finds no orphaned links; otherwise its source tables remain intact, Admin Settings reports the blocker, and startup retries while the migration warning remains. Recovery bundle hashes are implemented. Drift remains an evaluation/rearchitecture item rather than the current database layer. These migration paths have source analysis but still require runtime verification against sanitized fixtures, including interruption and restoration drills. The Flask server still creates 24 tables and applies idempotent `ALTER TABLE` additions through `migrate()` without a central version table (app.py:107-171, 2947-2975). Flutter and Flask schemas therefore overlap but are not identical, and are not a shared multi-device store.

## Principles

1. Treat every installed schema as user data; migration is a production change even if no server is involved.
2. Never delete the previous database before validating the new one and completing a recoverable backup.
3. Run migration in a transaction where SQLite supports it; use a new-table/copy/verify/swap path for changes that cannot safely be altered in place.
4. Use versioned, deterministic migrations and a schema history record. Each migration has an ID, checksum, preconditions and postconditions.
5. Test every supported starting version using sanitized representative fixture databases; include interrupted migration and low-storage recovery.
6. Keep normal migrations offline and independent from backend access.

## Recommended rollout

### Phase A: inventory and backup

- Inventory actual on-device schema versions, row counts, null patterns, duplicate business keys and file attachments. Do not inspect runtime personal data during the current audit; perform only with approved fixtures/consent in implementation.
- Add a user-visible encrypted backup/export with file manifest and checksum before structural conversion.
- Export schema and non-sensitive lookup sets separately from private record exports.
- Record supported source versions and establish recovery owner/runbook.

### Phase B: introduce typed migrations

- Introduce Drift tables/DAOs and migration registry at a new schema version while retaining the existing SQLite file as migration input.
- Enable foreign keys; run `foreign_key_check` and orphan reports after copy.
- Create new normalized tables alongside old ones; map IDs to stable `public_id`; maintain old→new ID mapping until references and attachments verify.
- Preserve an explicit bridge for Flutter-only `cloud_connections`; never import mock endpoints/API keys into production configuration.
- Migrate demo/test seed data only into a clearly isolated demo profile. Production must not auto-create demo credentials or seed real-looking borrower data.

### Phase C: exact money and normalized events

- For each source REAL amount, define currency, historic rounding rule and conversion policy with finance owner. Convert to integer minor units using approved decimal parsing and documented rounding; do not cast binary float directly.
- Produce a reconciliation report per table: source row count, converted count, null/invalid count, totals by currency and round-trip discrepancy. Block cutover on unexplained difference.
- Preserve original raw values in a quarantined migration audit field/table until the owner signs reconciliation; restrict access and retention.
- Convert mutable payment/schedule data into immutable transaction and allocation records. Resolve prior settlements/duplicates with user-approved mapping; do not fabricate ledger history.
- Convert embedded JSON/text fields such as family, previous loans, documents and settings into normalized rows with validation. Retain source payload in an access-restricted migration archive only as long as needed.

### Phase D: atomic switch and rollback

- Copy into new schema within a migration transaction or a versioned temporary database; validate indexes, uniqueness, FKs, totals and attachment checksums.
- On success, mark migration complete, atomically switch active database pointer, then reopen and perform a read-only startup reconciliation.
- If any step fails, leave old file unchanged, discard only the incomplete staging file, show a clear recovery screen and keep a backup. Do not repeatedly retry a known-invalid migration without user action.
- Retain previous database snapshot until a later successful backup has been independently verified.

## Future server import and sync compatibility

Local SQLite remains authoritative for a standalone device. If multi-device synchronization is approved, use public UUIDs, operation IDs, schema version, actor/device IDs, captured time, payload hash and per-operation result. Server sync must be idempotent, authenticated, encrypted in transit, and return explicit conflict/rejection details. Do not merge SQLite files or assume local autoincrement IDs are globally unique.

## Migration release gates

- Every supported source version migrates on-device without network access.
- Row and ledger totals reconcile exactly under the signed-off rounding policy.
- Foreign-key and unique-constraint checks pass; attachments reopen by checksum.
- Interruption at each migration step leaves either a usable original or a validated new database.
- Backup restore can recover both database and attachments on a clean install.
- Rollback plan and user support instructions are approved before release.
