# Sarvoocch Saathi

Flutter application for local microfinance operations. It uses SQLite for its
working data and is designed to keep core workflows available offline on a
single device.

## Run locally

```sh
flutter pub get
flutter run
```

On first launch, create the initial administrator account. Administrators can
create staff and customer accounts from **Admin Settings → User Accounts &
Access**. New accounts must change their temporary password at first sign-in.
Sample identities are seeded in debug builds only.

## Current workflows

- Customer records, assignment and branch-scoped access.
- KYC form capture and a separate manual review. Captured document details do
  not count as issuer verification.
- Loan applications, approval history, disbursement references, schedules and
  cash collection records.
- Attendance with configured branch geofences, manager review of corrections,
  leave requests and employee records.
- PreGRT capture and review. Group batch origination remains paused until the
  organization approves the required per-member terms and disclosures.

The applicant age, document-count, EMI-to-income and PreGRT checks currently
reflect rules found in the local portal prototype. They are not a substitute
for an organization-approved credit policy or product configuration.

## Local data and recovery

Each installation has its own SQLite database. Native builds encrypt the full
database with SQLite3MultipleCiphers; the random database key is held in device
secure storage. An upgrade validates and encrypts a legacy plaintext database
before replacing it. If secure storage, encryption support, or validation
fails, startup stops instead of creating a fresh database over existing data.
Browser builds are disabled because browser storage is not encrypted.
The current supported release targets are Android and iOS; desktop builds also
use the native encrypted SQLite implementation and require platform review.

The app does not provide multi-device synchronization or a production cloud
backend. Local recovery snapshots in Admin Settings are encrypted and stored on
the device; they depend on the recovery key in device secure storage and cannot
be restored after app data removal or device loss. Admin Settings also supports
portable `.svcbak` export/import using an AES-GCM protected file, an encrypted
SQLite payload, encrypted KYC image contents, and a passphrase of at least 16
characters. Store the file and passphrase separately; the passphrase is not
stored by the app. Restoring either backup writes fresh device-key-encrypted
KYC image files, replaces local records, saves the current database as an
on-device recovery snapshot, records the restore in the audit log and signs the
administrator out. Existing portable backup formats without image bundles
remain readable; missing image data is rejected when the restored database
references encrypted KYC images.

New KYC photos are copied into app-private storage and individually AES-GCM
encrypted with a key held in device secure storage. Startup migrates available
photos left by older app versions and reports image references that need an
operator to replace or remove the photo. The backup flow includes the photo
bytes inside the already encrypted backup envelope, then encrypts them again
with a fresh key when restored. Old gallery originals and non-KYC files outside
this managed storage are not encrypted by the app.

Authenticated sessions sign out after five minutes without keyboard or pointer
activity, or when the app returns from the background after that period.

Database upgrades add uniqueness constraints only when existing rows allow
them. Existing duplicate rows are preserved and reported in Admin Settings
instead of being removed during migration.

## Not connected

The app does not process payments or eNACH, verify identity against government
issuers, send WhatsApp messages, calculate payroll/statutory deductions, or
synchronize data between devices. QR/payment and OTP development simulations
are labelled and do not update regulated or financial records as successful
external transactions. KYC bank account numbers are AES-GCM field-encrypted
and customer listings expose only their last four digits. The cloud-provider
page is static reference material; it does not accept credentials or sync data.
The v9 migration clears legacy cloud connection values and attempts to remove
their old database pages. Sync stays unavailable until a backend is deliberately
configured; the app has no implicit localhost or plain-HTTP fallback. Database
encryption does not encrypt files selected from the device or the operating
system, and the app still needs platform security review before handling live
customer data. Upgrading from an older version replaces the live plaintext
SQLite file, but cannot guarantee erasure of historical plaintext pages from
flash storage or external backups created by earlier versions. Platform file
protection, secure-storage recovery, and backup behavior still require Android
and iOS device verification before handling live customer data.

## Static analysis

Run Flutter analysis on application sources with:

```sh
flutter analyze lib
```
