# Security architecture and production readiness

## Risk basis

Initial source findings included plaintext Flutter passwords, demo credentials and role switching; those app paths have since been removed or migrated as described below. Remaining inspected Flask/deployment prototypes still contain demo login material and a development session-key fallback, and the supplied Compose file contains a fixed secret-like value. Exact values are intentionally omitted. The payment screen presents simulated card fields; real PAN/CVV must never be collected or stored by this application. Sensitive KYC data and attachments are stored without a documented retention model.

Use OWASP MASVS control families for storage, cryptography, authentication/authorization, network, platform, code quality, resilience and privacy. MASVS is a verification standard; a checklist alone does not establish security. ([OWASP MASVS](https://mas.owasp.org/MASVS/), [MASTG data storage tests](https://mas.owasp.org/MASTG/0x05d-Testing-Data-Storage/)).

## Implementation update (8 Nov 2026)

The Flutter native database now uses SQLite3MultipleCiphers with a random key
stored in platform secure storage. Startup validates and migrates an existing
plaintext database before replacing it, encrypted local snapshots remain
device-bound, and portable backups use a passphrase-derived SQLite key plus an
AES-GCM envelope. KYC photo files are stored as AES-GCM ciphertext in app-private
storage with a separate key held in secure storage. Startup migrates available
legacy picker files; unavailable references are reported for operator review.
Both backup formats carry KYC image bytes only inside their encrypted envelope,
and restore re-encrypts each image with a new device key. Browser startup is
blocked because its database path is not encrypted. These source changes have
not yet received device-level Android/iOS verification, a key-loss/recovery
drill, or an independent security assessment. Other files, gallery originals,
platform file-protection settings, and operating-system backup behavior still
need review. Do not treat this implementation update as release approval.

KYC review and edit reads return only a masked bank-account suffix. Editing
unrelated form fields leaves the protected account value unchanged; replacement
values are encrypted before persistence and are obscured while being entered.
Full account data is not decrypted into the routine KYC screen.
Local recovery snapshot creation and portable backup export are recorded in the
append-only audit log. Successful restore/import actions use an append-only
`recovery_events` ledger. Its operator ID, username and display name are
explicitly snapshots from the active administrator in the database being
replaced; they are not foreign keys into the imported user table, whose IDs may
belong to different people or devices. The administrator activity view combines
both event sources. Schema v32 adds this ledger to upgraded and fresh databases.
Database, recovery, sensitive-field and attachment encryption keys all use
persistent platform secure storage and fail closed when it is unavailable;
debug builds no longer substitute process-only keys.

The login form no longer contains sample passwords, the role-switch control and
debug database reset have been removed, and fresh databases no longer seed
sample identities. Schema v27 disables only the bundled sample identities
identified by their original username, name and phone tuple, clears their
password hashes, and preserves all linked business records. If no active
accounts remain, first-admin setup becomes available again. Bootstrap requires
a username not present on any historical account, so it creates a fresh
administrator identity instead of reactivating a disabled employee or borrower
account with its prior links. The migration must still be exercised against
sanitized legacy database fixtures before release.
Login, first-administrator setup, password changes and temporary-password
dialogs clear their password text controllers after submission attempts and on
screen or dialog disposal. This limits how long those values remain in UI state;
the Dart runtime does not promise memory zeroization for immutable strings.
Sign-in attempts with unknown, locked or unsupported account verifiers now run
equivalent PBKDF2 work for valid-length passwords, reducing the large timing
difference that exposed whether a username existed. Database and UI timing can
still vary, so this is not a constant-time guarantee or a substitute for
device-level throttling.

Pre-GRT group records now retain only the last four characters of a voter ID.
Schema v31 redacts existing group snapshots and database triggers reject
subsequent writes containing more than four characters; the screen labels the
value as a masked suffix. Full identity values remain in the KYC record only
for its existing verification purpose and are masked at the customer model
boundary.

While a user is signed in, the provider keeps the authenticated password-hash
fingerprint only in memory. On app resume it rechecks account status, lockout,
password hash, role, branch, customer link and forced-password-change state;
missing or changed authorization state logs out the session and appends a
`session_revoked` audit event containing only the reason. Database errors fail
closed. This is local session protection and does not replace provider-side
authorization checks or future server-side revocation for a synchronized app.
The app now covers its current screen as soon as it becomes inactive, hidden or
paused, and keeps the cover visible until the active session has been rechecked
or cleared. The cover also blocks pointer input, hides the underlying semantics,
and dismisses the active keyboard focus. Verify task-switcher snapshots and
lifecycle timing on each supported Android and iOS release device before
relying on this as a platform-level screenshot control.

KYC image previews now go through the customer access boundary. The current
actor and branch/assignment scope are checked again before the encrypted image
is returned, the referenced KYC slot must still match, and a
`kyc_attachment_viewed` audit event records the slot without image data or PII.
KYC save validates each encrypted image reference before the database writes
the reference. The form tracks newly selected encrypted files and deletes
uncommitted selections when replaced, cleared or abandoned; it retains them
after a successful save.
Legacy plaintext picker paths are not rendered by the KYC form; affected images
must be replaced or migrated through the attachment flow before they can be
previewed. New and restored JPEG/PNG attachments are now limited to 12 MB and
20 megapixels; dimensions are read from the image headers before the file is
stored or previewed to reduce decompression-memory risk. Runtime authorization
and migration behavior still need device verification.

KYC saves now append an immutable consent-state snapshot in the same transaction
as the form and customer update. The snapshot records the declaration, conditional
husband-loan consent, combined credit-bureau/insurance sharing choice and field
officer address-visit attestation, along with the capture actor, time and form
revision. The notice is explicitly marked pending owner/legal review; this event
history does not certify that its current wording or legal basis is approved.
Administrators can review the latest audit activity in Admin Settings, where
consent summaries are shown without exposing arbitrary audit payloads.

## Target controls

### Identity and session

- Remove demo auto-login, role switcher and production demo accounts. Provision identities through an approved administrative flow.
- Hash passwords using a maintained server-side password-hashing algorithm and parameters. Client-side offline credentials use a reviewed KDF with per-user salt and server-provisioned verifier; do not reuse plaintext or a static shared secret.
- Keep refresh/session tokens out of SQLite/logs; use platform protected storage. Use Android Keystore to protect cryptographic keys and Apple's Keychain for secrets. These stores can restrict key use; they do not encrypt the whole database by themselves. ([Android Keystore](https://developer.android.com/privacy-and-security/keystore), [Apple Keychain](https://developer.apple.com/documentation/security/keychain-services)).
- Define idle lock, app-background timeout, device loss and user/role revocation behavior. Require step-up authentication for sensitive exports, restore, high-value approvals or posting where appropriate.
- Enforce permission and scope at the use-case/data-access boundary and again on server endpoints. Deny by default; do not trust role names supplied by the client.

### Data at rest and in transit

- Minimize sensitive data collected. Mask identity/bank identifiers; store only what a documented business/legal purpose requires.
- Encrypt private attachments and backups. Protect database keys using platform keystores and define key rotation/recovery. Threat-model SQLite temporary files, WAL/journal, export, crash dumps and backups; perform platform verification before release.
- Store keys separately from encrypted content. Do not hard-code API keys, OTP secrets, passwords or encryption keys in app/config/repo. Rotate leaked or fixed development secrets; use deployment secret stores for server configuration.
- Require TLS for any sync or integration, validate certificate chains, never disable validation for “offline” or development fallback.
- Exclude credentials, OTPs, full identity numbers, account details and tokens from logs, analytics, notifications and crash traces.

### Authorization, approvals and audit

- Central policy function checks action + resource + organization/branch scope + current status.
- Approval/posting uses maker-checker separation where risk requires it; enforce on domain operations, not only buttons/routes.
- Append-only audit events cover login/lock, role grants, sensitive view/export, create/edit/submit/approve/reject/post/reverse, sync resolution, backup/restore and admin policy changes.
- Audit event captures actor, assigned roles, device, event ID, record public ID, timestamp, previous/next state, reason and correlation ID. Avoid placing full PII in event payloads.
- Posted financial and inventory events are immutable. Correct through linked reversals and replacements.

### Input, file and platform security

- Validate types, bounds, enums, cross-field rules and attachment content on every entry point. Treat imported and synced data as untrusted.
- File allowlist by actual content/signature, size caps, safe generated names, storage outside web root, checksum, malware scan where available, no direct execution, scoped retrieval and retention expiry.
- Prevent path traversal, SQL injection (parameterized queries), unsafe HTML/PDF rendering, deep-link privilege bypass and unintended clipboard/screenshot exposure.
- Set secure Android backup and iOS file protection policies after testing recoverability. Private data exports require explicit authorization and audit.
- Protect user-facing error messages from leaking SQL, stack traces, file paths, identifiers or secrets.

### Prototype cleanup before any release

Inventory source, build artifacts, environment files, container manifests, deployment settings, APK and test fixtures for secrets/demo credentials. Rotate exposed values before any connected service is enabled; remove hard-coded defaults, invalidate existing demo sessions and ensure generated logs/artifacts are not shipped. The value strings are not reproduced in this audit.

## Verification gates

- Threat model approved for offline device, lost/stolen device, malicious local user, compromised server, insider abuse and conflicting sync.
- MASVS profile selected and mapped to evidence, including data storage, auth, network, privacy, platform interaction and key handling.
- Security review of database encryption, backup/restore, key loss, log redaction, authorization scope and role revocation.
- Static dependency/license/security review at release time; pin reproducible builds and maintain an update/incident process.
- Independent assessment of released Android/iOS builds and server deployment before production customer data is loaded.
