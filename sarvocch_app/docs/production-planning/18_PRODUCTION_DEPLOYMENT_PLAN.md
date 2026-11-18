# Production deployment plan

## Current state and target

The supplied website is a local Flask/SQLite prototype; README states KYC, payment, eNACH and WhatsApp are mocked. Deployment manifests reference Render and Vercel, but this does not establish a production deployment, canonical domain, backup policy or operational owner. The user clarified that no Sarvoch-related website is available online here; the supplied local source is the reference. The standalone Flutter workspace has no commit history/remote, while the source repo has a traceable baseline (see 01_REPOSITORY_AUDIT.md).

The primary target requested is offline-capable Flutter with local SQLite. Choose Android/iOS release platforms and legal/business identity before operational release. Keep the Flask prototype isolated from real data until its hosting, authentication, storage durability and integrations are production-reviewed.

## Release prerequisites

1. **Scope and owner:** MFI scope is selected and manufacturing excluded. Name the product owner, data owner, security owner, support contact and release approver.
2. **Data/legal:** approve privacy notice/consent, retention, applicable jurisdiction obligations, accounting/tax policy and incident response. Obtain specialist review where required.
3. **Schema and data:** migration, exact-paise storage and encrypted backup/restore safeguards are implemented in source; verify them with versioned fixtures, recovery drills and financial reconciliation before launch.
4. **Security:** authentication, access scopes, masking, encrypted storage and redacted errors are implemented in source; complete threat-model, authorization, MASVS-mapped, dependency and signed-build reviews.
5. **Device operations:** define managed/unmanaged device policy, employee offboarding, lost-device response, provisioning, backup transfer, support and app update channel.
6. **Integrations:** keep payments, KYC verification, WhatsApp/eNACH and sync disabled until real provider contracts, credentials, consent, callbacks, idempotency and failure handling are approved.
7. **Quality:** repair and run the planned verification suite, then complete the release acceptance matrix in 16_TESTING_STRATEGY.md and 21_ACCEPTANCE_CRITERIA.md on the approved device/platform matrix.
8. **Documentation:** publish user/admin guide, privacy and consent copy, backup/restore runbook, release notes and data export process.

## Mobile distribution and operations

- Create separate development, staging and production application identifiers/signing identities. Protect signing keys and restrict release permissions.
- Android release builds now require a configured, existing release keystore and never fall back to the debug key. The checked-in properties template contains placeholders only; key generation, secret provisioning, signature verification and signed-release acceptance remain operator/release gates.
- Build reproducibly from reviewed version control with locked dependencies and schema version attached to release metadata.
- Provide a safe first-run setup that creates a named organization/admin only after verified provisioning; never silently create production demo accounts.
- Deliver updates through chosen managed/private/public stores after licensing, privacy listing and platform review. Define support for devices that miss multiple migrations.
- Monitor crash counts, storage failures, sync errors and security incidents without collecting sensitive record content.
- Publish a release rollback and database recovery plan. Application binary rollback is unsafe if new schema has removed old columns; use forward-compatible expand/contract migrations.

## Website/server pathway (optional)

If the business requires shared devices or the Flask portal, first replace implicit local SQLite hosting with an architecture whose durable storage, backups, auth/session secret management, HTTPS, logs, migrations, observability and recovery are verified. Vercel ephemeral filesystem behavior noted in the README is unsuitable as the sole persistent SQLite store. Define a canonical API contract and data ownership before connecting Flutter. No public website domain or production server is verified in this audit.

## Operational runbooks

- Backup/restore: frequency, encryption/key custody, verification, storage location, retention, recovery time/data objectives, restore drill and owner.
- Lost device: revoke identity, invalidate future sync credentials, assess locally held data and remotely wipe only where device management supports it.
- Data correction: approval and audit procedure for reversals, reconciliation and customer dispute.
- Incident: triage, containment, evidence preservation, privacy/legal notifications and credential/key rotation.
- Upgrade: canary pilot, pre-upgrade backup, migration monitor, rollback/forward-fix, support window and deprecation policy.

The current planning range is recorded in [23_REMAINING_EFFORT_ESTIMATE.md](23_REMAINING_EFFORT_ESTIMATE.md). It is not a committed date; release depends on policy decisions, release inputs and acceptance evidence.
