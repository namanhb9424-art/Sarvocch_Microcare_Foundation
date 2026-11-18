# Testing and quality strategy

## Current status

The worktree contains Flutter widget and user-flow test files. The test suite has not been run during this implementation session. Existing test sources are known to call obsolete provider APIs and need repair before they can provide release evidence. Static analysis of `lib` completed with no errors and five informational style notices; analysis did not verify runtime behavior. This document describes the MFI verification required for release and does not claim that it has passed.

## Verification layers

| Layer | Focus | Required MFI evidence |
|---|---|---|
| Domain/unit | Paise arithmetic, loan rules, state transitions and scope | Exact boundary examples approved by finance; schedule reconciliation; eligibility and approval limits; unauthorized transitions denied. |
| Database/provider | SQLite constraints, transactions, mapping and authorization | Foreign keys, unique operation IDs, rollback, idempotency, branch/assignment scope, audit history and balance reconciliation. |
| Migration/recovery | Every supported schema version through v32 and sanitized legacy records | Upgrade fixtures, invalid/conflicting row report, interrupted upgrade, restore after failure, integer-money reconciliation and encrypted attachment checksums. |
| Widget/accessibility | Forms, navigation, sensitive data and states | Validation and retained values after errors, keyboard/focus order, text scaling, screen reader, masking, offline/pending labels and privacy cover. |
| Integration | Complete local borrower and lending workflows | Lead → KYC/group → application → review/approval → loan/schedule → disbursement → collection/payment → receipt/closure, including negative paths and rollback. |
| Security/authorization | Deny by default, tampering and sensitive data | Role × branch × assignment × action matrix; account change/revocation; session lock; backup/export authorization; log redaction; encrypted backup/attachment review. |
| Offline/reliability | Airplane mode, restart, low storage and interruption | Approved local transactions persist offline; retry does not duplicate; app termination during posting/attachment/restore recovers safely; unsynced state remains visible. |
| Performance | Representative local data and constrained devices | Search/load budgets set by owner; pagination where needed; startup, migration duration and storage measured on selected devices. |
| Platform/release | Signed build on the approved platform matrix | Android permissions, secure storage, database/attachments, print/share, backup exclusion, install/upgrade behavior and signature verified. Qualify other platforms separately if selected. |
| Optional sync | Contract and server behavior, only if later approved | Duplicate replay, stale schema, lost acknowledgement, conflict, revoked device, partial batch and retry. Sync is currently disabled. |

## Quality gates

- Use isolated temporary databases and synthetic/sanitized fixtures; never place production customer data in test artifacts.
- Finance approves independent examples and boundary cases for all posted money. Assertions compare integer paise rather than floating-point values.
- Workflow verification checks state history, actor/scope, failure rollback, and ledger reconciliation, not only route reachability.
- Permission verification calls data boundaries directly as well as through UI controls.
- Migration acceptance reconciles record counts, money totals, foreign keys, uniqueness conflicts and attachment hashes for every supported version.
- No posted payment or collection can duplicate after double tap, app restart or retry.
- Accessibility, privacy-cover and secure-storage behavior are checked on physical devices.
- Release build and dependency evidence are reproducible from the controlled source baseline.

## Acceptance evidence

Every case links to a requirement and criterion. Reports record source revision, schema version, platform/device, fixture version, pass/fail, defects and waiver owner. A waiver does not turn a failed safety or financial reconciliation check into a pass; any permitted non-critical waiver needs an owner, rationale and expiry date.

See [21_ACCEPTANCE_CRITERIA.md](21_ACCEPTANCE_CRITERIA.md) for release gates and [19_IMPLEMENTATION_ROADMAP.md](19_IMPLEMENTATION_ROADMAP.md) for current implementation evidence.
