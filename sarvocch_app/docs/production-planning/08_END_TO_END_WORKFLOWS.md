# End-to-end workflows

The MFI flows below are source-verified prototypes and should be preserved if that is the approved product scope. Manufacturing flows are candidate process skeletons from the pasted brief; each requires policy and domain validation before acceptance criteria can be finalized.

## Verified microfinance workflows

### Lead to loan servicing

1. Authorized staff creates CRM lead with name, phone, branch, stage and optional DOB/address/agent. Duplicate phone is rejected by the server.
2. Staff completes the bilingual KYC dossier, family/co-applicant/neighbor information and declarations/attachments. The local provider validates identity, age, geography, the applicant declaration and conditional husband-consent field before save. It appends a consent-state snapshot to the audit log with the existing form revision and capture method. Credit-bureau/insurance consent copy and legal basis remain pending owner/legal approval; that checkbox is recorded but must not be treated as approved compliance evidence until the notice is reviewed.
3. Staff assembles a Pre-GRT group; the current provider requires 5–10 distinct members, whose KYC state, branch/assignment, center, group and village snapshots are rechecked in the creation transaction. The current 5–10 range still needs owner confirmation because the planning brief proposed a different range. Manager verifies or returns with remarks in a transaction that rechecks active role, branch, maker-checker separation and member declarations. Group application is available only after verification. Pre-GRT snapshots and screens retain only a masked voter-ID suffix.
4. Staff creates loan application against active product and customer KYC. Validate requested amount/tenure, cash flow, document checklist and insurance/declaration dependencies. Save application, extra financial details and submission audit record atomically.
5. Underwriting transitions the application through allowed stages. Rejection/return captures required reason. Approved amount cannot exceed requested amount. Disbursement creates loan and repayment schedule within a transaction.
6. Servicing posts repayment/settlement, updates schedule and emits receipt/history. Direct installment payment now commits the payment, paid marker, audit event and local outbox event atomically. Production target must use exact currency amounts, idempotency keys and reversal entries. Current payment route is explicitly simulated, not a live gateway.

Failure handling: keep submitted forms intact on validation failure; do not partially create loan/schedule; prevent repeat disbursement; display offline/stale status; preserve rejected and reversed events for audit.

### Field assignment and collection

1. Manager assigns a verification or collection task to a field officer and customer with due date.
2. Officer captures visit and optional location evidence offline. Task visibility, loan choices and posting require the officer's current branch to match the customer/loan branch as well as the task assignment. For collections, the app lists only active in-scope loans with a due installment and shows the due amount/date. The officer selects the loan when the task is not already linked.
3. The local transaction rechecks customer/loan/task assignment, selected due installment, exact paise amount and unpaid state; it writes the payment, updates the installment, closes the task and records audit/sync events atomically. An ambiguous loan or stale installment selection is rejected instead of being allocated to the newest loan.
4. If a future sync service is enabled, send an immutable operation envelope. Server returns accepted, duplicate, conflict or rejected for each item; unresolved conflicts stay visible and are never silently dropped.

The current /api/sync accepts bounded JSON payloads and Flutter sync/cloud behavior includes simulation. It is not sufficient proof of safe cross-device financial posting.

### Attendance correction and leave

Employee requests punch correction or leave with dates, reason and evidence as policy requires. Approver checks role and reporting scope, then approves/rejects with remarks. Approved correction creates an audited revision of the attendance record. Location is optional only where policy permits; collection/attendance location must record accuracy and source and have a clear consent notice.

## Conditional manufacturing workflows

### Enquiry to delivered order

1. Record enquiry and contact provenance, requested product family/approved revision, quantity, required date and requested documents.
2. Convert to quotation only after product, availability, pricing, tax, lead time and assumptions are checked. Approval applies to discounts/terms based on a confirmed authority matrix.
3. Customer acceptance creates a versioned sales order snapshot; changes after acceptance require amendment approval.
4. Material availability check either reserves stock or creates a purchase request. Reservation and stock movement are distinct from forecast.
5. Production planning creates jobs only from an approved order or approved replenishment policy. Routing, capacity and quality plan must be known before dispatching work.
6. Operator records operation start/stop and measured output; supervisor reconciles good, rework and scrap against planned quantities. The system prevents over-completion unless approved.
7. Quality inspector records checks and dispositions. Failed output is quarantined; it cannot become available finished stock until a defined release path.
8. Packaging links finished units/lots to package records. Dispatch picks only released, available quantity; shipment captures carrier and delivery evidence.
9. Invoice/receivable is created from approved shipment or agreed milestone. Payment allocations and credit adjustments create ledger events; reconciliation exceptions remain open.

### Procurement to stock

1. Authorized request identifies item/specification, quantity, needed date and reason.
2. Approval creates a supplier quotation comparison or direct PO according to confirmed policy.
3. PO revision snapshots supplier, currency, price, tax, terms and requested delivery.
4. Receipt is matched to PO lines; quantity/quality variance is recorded and can enter quarantine.
5. Accepted receipt posts a stock movement; rejected/short items create supplier resolution records. Invoice matching and payment follow separately.

## Shared failure and recovery rules

- Validation errors identify field and rule, retain draft data, and do not perform a partial posting.
- Critical posting uses one SQLite transaction and a unique operation/idempotency key.
- If a transaction cannot complete, roll back all related rows and show a recoverable message.
- Conflicts are explicit work items assigned to an authorized reviewer; never use “last write wins” for money or stock.
- Delete is disabled for posted, approved, shipped, paid or audited records; use cancel/reverse/void with reason and authority.
- Attachment failures never leave a record claiming a document exists when it was not durably saved.
