# Remaining effort estimate

**Estimate date:** 16 November 2026  
**Product:** SARVOOCCH Microcare Foundation microfinance app  
**Status:** Planning estimate; not a release approval

## Estimate at a glance

For a controlled first Android production release using the current offline-first design, plan for **about 30–50 focused engineering days** after the remaining business decisions and release inputs are available. This is roughly **6–10 engineer-weeks** for one person. With two engineers, elapsed time will not simply halve because policy decisions, migration work, device drills and release qualification have dependencies.

Use **45–70 engineering days** if the full Phase 5 repository/use-case architecture refactor in the roadmap is required before release. That work is still listed as a P0 foundation objective and has not been demonstrated as complete in the current implementation evidence. The lower range assumes the owner accepts the current provider/database boundaries for the first release, with focused fixes where verification exposes problems.

These ranges cover the remaining work in this repository for a single-organization, offline-first Android release. They do not include cross-device synchronization, live payment/KYC/credit-bureau integrations, an iOS release, a new public website, or manufacturing features. Those require separate scope and estimates.

## Work remaining

| Workstream | Engineering effort | What the estimate covers |
|---|---:|---|
| Resolve product and operating policies | 2–5 days of engineering support; owner time is separate | Turn approved roles, loan/fee/interest rules, repayment and reversal rules, consent/retention, reporting, and device/platform scope into implementation decisions. Policy approval itself is an external dependency. |
| Finish MFI rules and exception paths | 6–10 days | Implement and reconcile the approved lifecycle and its negative paths: approval, disbursement, collections, settlement/reversal, receipt language and ledger confirmation. Includes correcting inconsistencies discovered during review. |
| Data migration and recovery qualification | 5–9 days | Build sanitized migration fixtures, exercise upgrades through schema v32, investigate preserved legacy conflicts, interrupt/restore backups, and verify database plus encrypted attachment recovery. |
| Functional/security verification and fixes | 7–12 days | Repair stale verification code, add or update the needed automated coverage, verify role/branch boundaries, session revocation, exact-paise arithmetic, audit trails, offline behavior and sensitive-data handling. Device findings can add work. |
| Android release and operational readiness | 4–7 days | Produce a fresh build, configure owner-supplied production signing material, verify the signed package on the agreed Android device matrix, prepare deployment/recovery/support instructions, and close release acceptance evidence. |
| Final review and stabilization | 3–7 days | Independent policy/security review findings, accessibility and usability fixes in the agreed scope, release-candidate correction cycle, and go/no-go evidence. |

The workstream ranges overlap where the same defect is found and fixed during verification. The 30–50 day overall estimate is a planning range, not the sum of every upper bound. If Phase 5 is required, add approximately **15–20 days** for the repository/use-case boundary and its regression work.

## Work that cannot be assigned a reliable calendar date yet

The estimate assumes timely decisions and access to release inputs. Calendar time remains open until the business owner confirms the unresolved items in [22_OPEN_QUESTIONS.md](22_OPEN_QUESTIONS.md), especially:

- Approved loan products, pricing, affordability, repayment, settlement, refund/reversal, receipt and retention policies.
- Roles, branch boundaries, shared-device expectations, supported Android versions/devices, and whether iOS is part of this release.
- Consent and privacy wording, data ownership, support and incident-response ownership.
- Production signing keystore and credentials, plus named people responsible for release, backups and support.
- Representative sanitized legacy data and access to physical test devices for migration, privacy-cover and recovery drills.

Owner, legal, security and device review time is not included as engineering effort. If the decisions change the schema or core money rules, add design and migration work before treating this estimate as current.

## Main estimate risks

- The current evidence describes source changes, while runtime migration, restore, attachment and device verification remain open.
- A fresh universal debug APK now includes schema v32 source, but it is debuggable and is not a production release. The configured production keystore file is missing, so signed-release evidence depends on the owner supplying it.
- The roadmap records Phase 5 architecture as unfinished. Whether it is a release requirement materially changes the estimate.
- The current session did not authorize running tests. Existing test files are known to call obsolete provider APIs; the verification pass and repairs have not yet been performed.
- Provider integrations and the sync backend are mocked or disabled. Enabling them is outside this estimate and needs provider contracts, infrastructure decisions and separate security review.

## Estimate confidence and next planning checkpoint

**Confidence: low to medium.** Source review gives a useful size for the open work, but runtime evidence and owner policy decisions are missing. Re-estimate after the policies/platform are signed off, the Phase 5 decision is made, and migration/recovery fixtures have completed an initial pass. Until then, treat the range as a budget for planning rather than a committed delivery date.

The current implementation state and phase gates are tracked in [19_IMPLEMENTATION_ROADMAP.md](19_IMPLEMENTATION_ROADMAP.md); release acceptance evidence is listed in [21_ACCEPTANCE_CRITERIA.md](21_ACCEPTANCE_CRITERIA.md).
