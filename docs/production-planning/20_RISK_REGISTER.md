# Microfinance production risk register

Risk status is based on source/document inspection as of 15 November 2026. “Implemented in source” means the control exists in this worktree; it does not mean runtime or release evidence is complete. Severity describes the consequence if the risk reaches production.

## Open release risks

| ID | Risk | Severity | Current evidence and impact | Closure needed |
|---|---|---:|---|---|
| R1 | Business, legal and accounting policies are not fully approved | Critical | Interest/fees, affordability, settlement, reversal, official receipts, retention, consent and accounting treatment still contain owner/legal decisions. Prototype formulas or notices cannot be treated as authoritative policy. | Record approved policies with effective dates and owners; implement and reconcile any resulting changes. |
| R2 | Migrations, recovery and device lifecycle have not completed runtime drills | Critical | Schema is at v32 and migration/restore protections are implemented in source, but upgrade fixtures, interrupted restore, encrypted attachment recovery and platform privacy behavior need runtime evidence. | Exercise supported starting versions and device flows with sanitized data; record reconciliation and recovery results. |
| R3 | Functional verification is incomplete | High | The active session has not authorized running tests. Existing test files call obsolete provider APIs; static analysis of `lib` has no errors but reports five informational style notices. | Repair/authorize and run the planned workflow, migration, security and recovery verification; close every finding. |
| R4 | Production release signing and device qualification are unavailable | High | A fresh version 2.0.0+2 universal debug APK was built on 16 Nov and excludes the static cloud database plan feature. It is debuggable and is not a production release. Android release signing is configured to require a keystore, but the configured keystore file is missing. | Owner supplies protected signing material; build a release APK, verify its signature, and qualify on the selected Android matrix. |
| R5 | Financial workflows depend on unapproved policy | Critical | Installment posting is exact-paise and locally atomic in source. Settlement remains debug-only because payoff policy and payment confirmation are unresolved. Disbursement/ledger reconciliation and official receipt status need business approval. | Approve accounting/credit rules and evidence each end-to-end ledger reconciliation before enabling real transactions. |
| R6 | External provider claims or cross-device sharing could be misunderstood | High | Sync is disabled and queued events remain local. Payment, KYC/OTP, WhatsApp, credit-bureau and other external services are mocked or unavailable. | Keep unavailable paths clearly labeled; enable only after contracts, credentials, consent, callbacks, idempotency and failure/reconciliation policies exist. |
| R7 | Repository/use-case architecture remains incomplete | Medium | Roadmap Phase 5 still calls for routing screen operations through use cases and repositories; current feature logic remains distributed across providers and database helper. | Decide whether this refactor is required for the first Android release; if required, implement and verify before release. |
| R8 | Source baseline and release ownership are not established | High | Workspace files are untracked in the open repository. Production signing, deployment, backups, monitoring, support and incident response need named owners. | Establish a controlled source baseline and record accountable release/operations owners and runbooks. |
| R9 | Platform and operational scope may exceed verified Android behavior | Medium | Flutter platform wrappers exist, but Android physical-device behavior remains to be qualified; iOS/web/desktop requirements are unresolved. | Declare first-release platform and device/OS matrix; qualify other platforms separately before claiming support. |

## Controls implemented in source; evidence still required

- Password hashing, lockout, first-admin setup, session revalidation/revocation, route/role gates and branch/assignment checks.
- Encrypted SQLite and KYC attachments, protected key storage, local/portable recovery, masking and redacted error logging.
- Integer-paise storage and calculations for core lending/collection paths, append-only audit/approval events, transaction boundaries and database integrity checks.
- Debug-only settlement and provider simulations; production payment recording is limited to cash capture by authorized staff.

These controls reduce the original prototype risks but do not replace migration fixtures, security review, financial-policy approval or signed-device acceptance. See [19_IMPLEMENTATION_ROADMAP.md](19_IMPLEMENTATION_ROADMAP.md) for implementation evidence and [21_ACCEPTANCE_CRITERIA.md](21_ACCEPTANCE_CRITERIA.md) for release gates.
