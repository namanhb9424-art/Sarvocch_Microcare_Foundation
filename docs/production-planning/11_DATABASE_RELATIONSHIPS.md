# Database relationships and integrity

## Verified current model

The website schema defines 24 tables; Flutter defines those concepts plus `cloud_connections`. Current tables are largely connected by integer columns in application code rather than SQL FOREIGN KEY clauses. `get_db()` opens SQLite without enabling `PRAGMA foreign_keys=ON` (website app.py:174-179). Thus apparent links such as application→customer, payment→loan and member→group are conventions, not enforced relational constraints.

## Proposed relationship map: retained MFI scope

```mermaid
erDiagram
  USERS ||--o{ EMPLOYEES : account
  BRANCHES ||--o{ EMPLOYEES : assigns
  BRANCHES ||--o{ CUSTOMERS : serves
  CUSTOMERS ||--o| KYC_CASES : verifies
  CUSTOMERS ||--o{ GROUP_MEMBERS : joins
  LENDING_GROUPS ||--o{ GROUP_MEMBERS : contains
  CUSTOMERS ||--o{ LOAN_APPLICATIONS : requests
  LOAN_PRODUCT_VERSIONS ||--o{ LOAN_APPLICATIONS : offered
  LOAN_APPLICATIONS ||--o{ APPLICATION_DECISIONS : reviewed
  LOAN_APPLICATIONS ||--o| LOANS : books
  LOANS ||--|{ REPAYMENT_SCHEDULE : schedules
  LOANS ||--o{ FINANCIAL_TRANSACTIONS : receives
  FINANCIAL_TRANSACTIONS ||--o{ PAYMENT_ALLOCATIONS : allocates
  REPAYMENT_SCHEDULE ||--o{ PAYMENT_ALLOCATIONS : settles
  FIELD_TASKS ||--o{ FIELD_EVENTS : captures
  FIELD_EVENTS ||--o| FINANCIAL_TRANSACTIONS : posts
  USERS ||--o{ AUDIT_EVENTS : acts
```

Each arrow represents an enforced foreign key in a single device database. Cross-device identity uses `public_id`; local integer IDs are implementation keys only.

## Proposed relationship map: conditional manufacturing scope

```mermaid
erDiagram
  PARTIES ||--o{ PARTY_CONTACTS : has
  PRODUCT_FAMILIES ||--|{ PRODUCT_REVISIONS : versions
  PRODUCT_REVISIONS ||--o{ PRODUCT_SPECIFICATIONS : describes
  SPECIFICATION_DEFINITIONS ||--o{ PRODUCT_SPECIFICATIONS : defines
  ENQUIRIES ||--o{ ENQUIRY_LINES : requests
  ENQUIRIES ||--o{ FOLLOW_UPS : tracks
  ENQUIRIES ||--o{ QUOTATIONS : prices
  QUOTATIONS ||--|{ QUOTATION_LINES : contains
  QUOTATIONS ||--o| SALES_ORDERS : accepted_as
  SALES_ORDERS ||--|{ SALES_ORDER_LINES : contains
  PURCHASE_ORDERS ||--|{ PURCHASE_ORDER_LINES : contains
  INVENTORY_ITEMS ||--o{ INVENTORY_MOVEMENTS : moves
  INVENTORY_ITEMS ||--o{ BOM_LINES : component
  PRODUCT_REVISIONS ||--o{ BILLS_OF_MATERIALS : may_use
  BILLS_OF_MATERIALS ||--|{ BOM_LINES : defines
  SALES_ORDERS ||--o{ PRODUCTION_ORDERS : may_fulfil
  PRODUCTION_ORDERS ||--|{ JOB_CARDS : schedules
  JOB_CARDS ||--o{ PRODUCTION_EVENTS : records
  QUALITY_INSPECTIONS ||--o{ QUALITY_MEASUREMENTS : records
  SALES_ORDERS ||--o{ SHIPMENTS : fulfills
  SHIPMENTS ||--|{ SHIPMENT_LINES : contains
  SALES_ORDERS ||--o{ INVOICES : bills
  INVOICES ||--|{ INVOICE_LINES : contains
  PAYMENT_RECEIPTS ||--o{ PAYMENT_ALLOCATIONS : allocates
  INVOICES ||--o{ PAYMENT_ALLOCATIONS : settles
```

Optional relationships are omitted where order policy is unknown (for example, make-to-stock production or direct invoices). Define them only after process discovery.

## Integrity rules

- Turn foreign-key enforcement on for every opened database connection; fail app initialization if the expected pragma is off.
- Restrict deletion: master records referenced by history are archived; posted events use reversal/correction records.
- Scope every query by active user permission and branch/site ownership. A valid FK does not provide authorization.
- Use unique `public_id` and operation/idempotency key constraints to make repeat import/sync safe.
- Monetary totals reconcile from immutable line/transaction rows; schedule allocations cannot exceed allowed transaction amount or balance without a documented exception.
- Inventory availability is derived from posted movements minus active reservations, within the same transaction that reserves or consumes stock.
- Every approval row records actor, role snapshot, timestamp, state before/after, reason and affected business revision.
- Use `ON DELETE RESTRICT` for financial, inventory, approval and audit dependencies. Cascades are acceptable only for disposable draft children with explicit, reviewed deletion semantics.
- Test orphan detection and reconciliation queries as release gates. No cascade may silently remove a posted record.
