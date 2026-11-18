# Business requirements

## Scope status

The attached master brief describes manufacturing, while both supplied codebases implement microfinance. The items below preserve the 25 requested capabilities as a candidate scope. Status describes evidence in local code, not approval to build a manufacturer system. “Conditional” means the capability is requested by the brief but needs a business-owner scope decision and process discovery.

## Capability register

| # | Capability | Local-source evidence / current state | Candidate requirement and exit condition |
|---:|---|---|---|
| 1 | Company profile and administration | MFI branding, settings, branches, users/roles | Maintain legal identity, locations, policy and access. Confirm whether one entity or multiple companies/branches. |
| 2 | Product catalogue and specifications | MFI loan products with amount, term, rate, method and fee; no industrial catalogue | If manufacturing, version controlled product families/specifications with units, approvals and attachments. Populate only from approved source data. |
| 3 | Customer and supplier management | Borrower CRM; no procurement suppliers | Separate customer, supplier and contact records; support dedupe, status, contacts and documents. Roles and required legal/tax identifiers need confirmation. |
| 4 | CRM and enquiry management | Lead creation, stage and communication logs | Preserve MFI lead flow; conditional manufacturer enquiry requires source, product interest, owner, follow-up date and outcome. Define lifecycle and SLA. |
| 5 | Sales quotations and approvals | Loan quote/calculator exists; no commercial quotation | Manufacturer quote lines snapshot product revision, qty, unit price, tax, validity and terms. Approval thresholds and discount rules require confirmation. |
| 6 | Sales orders | Loan applications and approvals exist; no goods order | Confirmed customer order created from accepted quote; snapshot items, delivery and cancellation rules. |
| 7 | Purchase orders and procurement | No supplier purchasing | Request/approval/PO/receipt flow with supplier, line quantities, expected date and revisions. Approval authority and matching rules need confirmation. |
| 8 | Raw material inventory | No manufacturing stock | Item master, units, lots, locations, receipts/issues/transfers/counts and immutable movements. Define valuation and traceability. |
| 9 | Warehouse and stock management | No warehouse module | Multiple locations/bins, reservations and stock availability. Define whether lot/serial/expiry tracking applies. |
| 10 | Manufacturing and production planning | No production evidence | Approved production order and planned material/labor steps. Define capacity, routing, make-to-order/stock policies and scheduling. |
| 11 | Job cards and machine allocation | No job cards/machines | Assign authorized operation, resource, operator, planned and actual times; enforce prerequisites and safe close. Confirm equipment model. |
| 12 | Production output and wastage | No production evidence | Record good/rework/scrap quantity and reason against job/operation; reconcile material consumption. Define units and tolerances. |
| 13 | Quality inspection and defects | No quality module | Inspection plan, measured values, disposition, defect/corrective action and sign-off. Applicable standards/sampling plans unknown. |
| 14 | Packaging and finished goods | No packaging evidence | Package approved output, capture package IDs/contents/weights and stock posting. Packaging types unknown. |
| 15 | Dispatch and delivery | No dispatch evidence | Pick/pack, shipment, carrier, proof of delivery, shortage/damage and returns. Define delivery partners and evidence. |
| 16 | Invoicing and accounts | Loan repayments exist, not sales accounting | Invoice, credit/debit adjustments, receivable/payable and ledger/export. Confirm tax/accounting policies and system of record. |
| 17 | Payment and balances | Simulated borrower payments | MFI collection remains simulated. Manufacturer payment needs provider/bank reconciliation, receipts, allocation, refund and outstanding rules. |
| 18 | Employee management | Employee/HRM tables and screens | Employee identity, job/branch, documents and status; define privacy and retention. |
| 19 | Attendance and leave | Attendance, geofence, correction and leave | Preserve with policy versioning and approvals; define offline capture, location consent and payroll integration. |
| 20 | Dashboards and reporting | Portfolio dashboards/reports | Role-scoped, reproducible metrics sourced from ledgers; mark stale data on offline devices. Define canonical KPIs. |
| 21 | Notifications and reminders | WhatsApp/OTP simulation | In-app local queue first; optional channels require explicit provider, consent, retry and delivery states. |
| 22 | Documents and attachments | KYC, employee and loan files | Attachment metadata, encrypted private storage, checksums, access audit, export and retention. No sensitive IDs in filenames/logs. |
| 23 | Audit logs and approvals | Approval, attendance request and sync logs | Append-only actor/time/before-after/reason history for critical decisions; no mutable audit rows from ordinary user flows. |
| 24 | Backup and restore | No complete controlled mobile backup workflow established | Versioned, encrypted, integrity-checked backup/import with preview, rollback and documented recovery. |
| 25 | Settings and configuration | Loan policy, holidays, branch rules | Validated typed settings with effective date, revision and change approval. Avoid mutable global rules with no history. |

## Global business rules

1. Preserve existing MFI functions if the business confirms that scope; otherwise plan a separate migration and data disposition.
2. Core capture, approvals, reports, document rendering and data export must work without network access on a single authorized device.
3. SQLite files are per device. Shared multi-user work requires an explicit synchronization/server boundary and conflict policy.
4. Store monetary values as integer minor units plus ISO currency; store measured quantity as integer-scaled units plus unit code/scale. Never use floating point for posted amounts.
5. Draft records may be edited with version history; posted financial/stock events are corrected by reversal and replacement, not deletion.
6. Every approval transition is role-authorized, state-validated, timestamped and auditable. UI visibility is not authorization.
7. Offline actions have stable operation IDs and idempotent local application. A future server must acknowledge or reject individual operations deterministically.
8. Personal data and attachments have purpose, consent/legal basis, retention and access controls approved by the organization.

## Explicit exclusions until confirmed

No manufacturing product attributes, BOMs, machine capacities, inspection standards, inventory valuation method, sales tax behavior, supplier terms, public visitor funnel or production plan are confirmed by the local site. These must be elicited from the business owner and records before implementation.
