# Microfinance release acceptance criteria

These criteria apply to the approved SARVOOCCH Microcare Foundation microfinance app. Manufacturing capabilities are out of scope. Each criterion needs recorded evidence and an owner decision where policy is involved; source code alone is not acceptance evidence.

## Product and administration

| Area | Acceptance criteria |
|---|---|
| Organization and branches | Legal entity, branch list, currency, timezone and supported devices match owner-approved configuration. Branch changes are authorized and audited. |
| Users and roles | Approved role/action/scope matrix is implemented. Provisioning, password reset, offboarding, lockout and lost-device response have named owners. Unauthorized, inactive, expired or out-of-scope accounts are denied. |
| Customer records and consent | Only approved fields are collected. Purpose, consent wording, access, correction, export and retention are approved. Aadhaar, PAN, voter ID, bank and income data are masked or encrypted as approved. |
| Audit and reporting | Critical changes record actor, role snapshot, timestamp, subject and safe change details in append-only history. Reports define each total, role scope, as-of time and offline/pending-data state; exports are audited. |

## MFI lifecycle

| Workflow | Acceptance criteria |
|---|---|
| Lead and customer onboarding | Duplicate and conversion rules are approved. A customer record has a stable identity, source and responsible staff member; branch and assignment scope is enforced. |
| KYC and group formation | Consent and manual-review process are approved. Required documents and group rules are explicit. Review decisions record the reviewer and reason. Mock issuer or OTP checks are clearly labeled and cannot imply real verification. |
| Loan application and underwriting | Products, fees, rate units, affordability method, eligibility, tenure and approval limits are owner-approved. Applications retain the submitted product terms and exact amounts. Maker/checker rules and all allowed/rejected state transitions are evidenced. |
| Schedule and disbursement | Approved amount and terms do not change silently. Schedule principal reconciles exactly to disbursed principal in paise. Disbursement reference, channel, actor and ledger confirmation meet the approved accounting process. |
| Collections and installment payment | Collection staff, branch/assignment scope, amount and installment allocation are validated. A payment, installment status, audit record and pending sync event commit atomically and retry once. Cash receipts reconcile to the ledger; simulated provider channels are unavailable as real payments. |
| Settlement, adjustment and reversal | Payoff arithmetic, effective date, fees/waivers, approval, refund and reversal rules are approved before enabling settlement. Original events remain visible and adjustments are linked and auditable. |
| Receipt and borrower record | Receipt wording and legal status are approved. A device copy is clearly distinguished from an official receipt until reconciled. Customer access only exposes the authenticated customer’s own approved information. |
| Staff field operations | Attendance, location, leave and field-task rules are approved, scoped, auditable and workable when offline. GPS is treated as device-provided evidence with accuracy and consent context. |

## Data protection and reliability

- Every supported starting schema version migrates without silent loss. Preserved conflicts are visible to an administrator and have a documented resolution path.
- Financial fields round-trip in integer paise. Database constraints reject invalid references, duplicate installment payment and inconsistent dual-written money values.
- Encrypted database, key storage, portable/local backup and KYC attachments survive interruption and restore together. Backup integrity and restore results are independently checked.
- App background/resume, logout, session revocation, account switch and device restart do not reveal stale sensitive screens or stale scoped data.
- Logs, errors, exports and backups contain no unapproved identity, authentication or financial values.
- Approved core flows work in airplane mode and after process/app restart. The UI indicates unsynced records and does not claim cross-device sharing while the sync service is disabled.

## Verification and release gates

- Automated coverage is repaired and executed for money arithmetic, migrations, auth/session lifecycle, branch/assignment scope, workflow transitions, idempotency, backup/restore and offline behavior.
- Sanitized fixtures exercise each supported migration path, including invalid/conflicting legacy data and interruption/restart recovery.
- A security/privacy review records findings and closure evidence; required legal and accounting review is complete.
- A release build is signed with owner-controlled production credentials and verified on the approved Android device/OS matrix. Debug-only simulation paths are absent from production behavior.
- Backup, restore, lost-device, incident response, support escalation, release/rollback and data-retention instructions have named owners and have been rehearsed as applicable.
- Product owner and release owner record a go/no-go decision against the evidence above.

## Explicit exclusions for this release estimate

- Manufacturing products and workflows.
- Live payment, KYC issuer, credit-bureau, insurance, WhatsApp, eNACH or accounting/ERP integrations until provider contracts, credentials, consent and error/reconciliation rules are approved.
- Cross-device synchronization until an authoritative service, hosting/security model and conflict policy are approved.
- iOS, web and desktop release qualification until supported platforms and acceptance matrices are selected.

Related decisions are tracked in [22_OPEN_QUESTIONS.md](22_OPEN_QUESTIONS.md); implementation evidence and remaining gates are tracked in [19_IMPLEMENTATION_ROADMAP.md](19_IMPLEMENTATION_ROADMAP.md).
