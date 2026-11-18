# Open questions and business decisions

These are owner, legal, finance, operations or release decisions. They cannot be inferred from source code or unrelated public information. The approved scope is the existing SARVOOCCH Microcare Foundation microfinance app; manufacturing is excluded.

## Scope and operating model

1. Is a public visitor/customer website part of this release, or only the staff/borrower operational app? Which customer types and portal actions are in scope?
2. Which repository is the canonical implementation baseline: the open Flutter workspace or the supplied local website source? What is the approved source control and review workflow?
3. Which roles, reporting hierarchy, branch boundaries and maker-checker actions are authoritative? Can a staff member hold multiple roles?
4. Who provisions accounts, approves access, offboards staff, revokes a lost device and resolves expired/offline access?
5. Which platforms are required first: Android, iOS, desktop or web? What Android versions/devices, shared-device, accessibility and language requirements apply?
6. Which reports and KPIs are mandatory, how are they calculated, and which roles may view or export them?

## MFI and finance policy

7. Which loan products, rate units, fees/taxes, eligibility, affordability thresholds and approval limits are approved?
8. What are the repayment calendars, prepayment/settlement formulas, rescheduling, refund, reversal, waiver and late-payment rules?
9. Which system is the financial system of record? What ledger entries, disbursement references, reconciliation steps and closure evidence are required?
10. What wording and controls define an official receipt versus an internal/device copy? Which actions require ledger confirmation or a second approval?
11. What group-size and membership rules are approved? Existing prototype values must not be treated as policy without confirmation.

## Data, privacy and integration

12. Which personal and financial fields are necessary, for what purpose, and for how long? Who approves consent, privacy notice, correction, export and erasure processes?
13. Which legal entity/jurisdiction, currencies, accounting periods, timezones and number/date formats must be supported?
14. Are payment, KYC issuer, credit-bureau, insurance, WhatsApp/eNACH, maps, email, SMS, accounting or ERP providers contracted? What sandbox credentials and callback/failure rules are available?
15. Does the app need multiple devices to share live work? If yes, who hosts the authoritative service, where is data hosted, and what conflict/recovery objectives apply?
16. May attachments be exported or backed up to user-managed storage, and what key-recovery method is acceptable after device loss?

## Release ownership

17. Who owns production signing keys, deployment secrets, backups, monitoring, incident response, customer support and release approval?
18. What migration and historical-retention obligations apply to prototype records? Which records must be purged or anonymized before production?
19. What performance, availability, recovery-time and support-window targets are required?

## Decisions required before release

The product choice is resolved: keep the MFI app; manufacturing workflows remain excluded. Resolve questions 1–6 before claiming the supported user/platform scope. Approve the credit, accounting and receipt rules in questions 7–11 before real financial transactions. Approve privacy, hosting and provider decisions in questions 12–16 before enabling corresponding data flows or integrations. Name release and operations owners before signing or production deployment.
