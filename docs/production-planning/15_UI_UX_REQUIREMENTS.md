# UI and UX requirements

## Product and navigation

Preserve familiar Flutter routes and workflows while placing screen behavior behind use cases and repositories. Navigation is role-aware, but removing a menu item is never the authorization control. Separate staff, borrower/customer and any future public visitor experiences; the current portal does not provide a public catalogue or enquiry funnel.

Show the chosen company/branch context and offline freshness globally. Every saved/posted record has a visible state: draft, submitted, awaiting approval, approved, posted, pending sync, conflict, rejected, reversed or archived. Exact status names should align with the approved domain state machine.

## Forms and workflow

- Group related fields into a clear step flow; show conditional field dependencies and why a field is required.
- Use field-level errors, preserve valid inputs after validation failures, and provide a review/confirmation summary before irreversible actions.
- Separate estimate, approved terms and posted transaction values. Clearly mark simulated integrations and never label simulated payment/verification as completed real-world service.
- Present approval action, authority and next state explicitly; request reason for return/reject/reverse/correction.
- Confirm destructive draft deletion. Posted history is corrected by reversal workflow.
- Use stable, searchable dropdowns backed by reference data, not free-form strings for controlled values. Use explicit units for rates, money, date, distance and quantity.

## Offline behavior

- Persistent offline badge with last successful sync/backup time and pending/conflict counts.
- Normal local workflows remain available without network. External-only actions show “requires connection” and retain a safe draft when possible.
- Do not silently show stale cloud data as current. Show last refreshed time and local-vs-server source.
- Sync errors identify which records need action; retry is safe/idempotent. An unresolved financial/stock conflict blocks the dependent workflow.
- Backup/restore has progress, integrity result and recovery guidance.

## Privacy and security in the interface

- Mask identity and bank values by default; reveal only through scoped permission and access logging.
- Keep sensitive data out of push notifications, app switcher snapshots, exported filenames and clipboard by default.
- Before collecting location, camera or document data, explain purpose and provide a non-location route where policy permits.
- Provide logout/lock, accessible account status, and clear device deactivation/role expiry behavior.
- Never expose production credentials, OTPs, card security codes or development account-switch controls.

## Accessibility and localization

- Support dynamic text scaling, screen readers, logical focus order, keyboard navigation, sufficient contrast and non-color-only status cues.
- Ensure touch targets and error messages work on small screens and low-cost Android devices.
- Retain bilingual MFI KYC content if MFI scope remains; business owner must approve languages, translations and legal text. Provide locale-aware number/date/currency display while storing canonical values.
- Do not truncate long names, addresses, account references or translated labels in PDFs and print layouts.

## Platform and responsive behavior

Establish Android/iOS as initial supported platforms unless owner says otherwise. Qualify desktop/web separately for SQLite, encryption, location, secure storage, attachment paths, printing and backups. Layout should adapt to phone/tablet and keyboard use without exposing extra data on large screens.

## UX acceptance checks

- A new user can identify offline state and current record freshness immediately.
- Required/conditional fields and permitted next actions are discoverable without guessing.
- A failed save has no ambiguous success state and preserves recoverable input.
- A user cannot visually mistake an estimate or mock integration for a posted business event.
- All sensitive views/exports are masked by default and role-appropriate.
