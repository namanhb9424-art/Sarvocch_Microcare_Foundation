# Proposed SQLite schema

## Scope and conventions

This is a proposed target schema, not a migration already implemented. The local sources are MFI code; manufacturing tables below are conditional on scope confirmation. The source database has 24 web tables and Flutter has 25, including `cloud_connections`. Both use SQLite and store financial values in REAL; their CREATE TABLE statements mostly omit foreign keys, CHECK constraints and indexes. Website schema: `/Users/vaidik/sarvocch_repo/app.py:107-171`; Flutter: `/Users/vaidik/sarvocch_repo/sarvocch_app/lib/data/database_helper.dart:93-539`.

Common column conventions:

- Primary keys: local integer `id`; assign globally unique `public_id` UUID for sync/import, unique and immutable.
- Timestamps: UTC ISO-8601 text (`created_at`, `updated_at`); business dates separate ISO date strings.
- Money: signed 64-bit integer `amount_minor` plus ISO-4217 `currency_code`; INR paise where INR is confirmed. Store rate as integer basis points or explicitly scaled decimal with declared scale. Do not use REAL for money.
- Quantity: integer `quantity_scaled`, `unit_code`, `scale` (e.g., milli-units only where business approves); reject incompatible units.
- Booleans: INTEGER NOT NULL CHECK(value IN (0,1)); enums constrained by lookup/reference table or CHECK.
- Soft deletion only for mutable master/draft rows: `archived_at`, `archived_by`, `archive_reason`. Posted ledgers are append-only.
- Every table includes tenant/company or branch scope only if multi-entity ownership is confirmed. Offline device IDs are distinct from user IDs.

## Shared platform, identity and governance tables

These tables support either selected business domain. Organization and device models are conditional on deployment topology; keep a single-organization implementation simple if only one legal entity is confirmed.

| Table | Columns and constraints |
|---|---|
| organizations | id PK, public_id UQ, legal_name, display_name, jurisdiction_code, base_currency_code, timezone, status, created_at. Do not infer legal/tax values. |
| devices | id PK, public_id UQ, user_id FK, platform, app_instance_id, provisioned_at, last_seen_at, credential_expires_at, revoked_at, revoked_by FK, status. Unique app_instance_id; no secret material in this table. |
| auth_sessions | id PK, public_id UQ, user_id FK, device_id FK, created_at, expires_at, ended_at, last_activity_at, session_state. Tokens remain in platform-protected storage, not as plaintext DB columns. |
| audit_events | id PK, public_id UQ, operation_id UQ, actor_user_id FK, device_id FK nullable, actor_role_snapshot, action_code, entity_type, entity_public_id, prior_state_hash, next_state_hash, reason_code, occurred_at, correlation_id. Append-only triggers/use-case restrictions; never store full secrets or unnecessary PII. |
| approval_policies | id PK, public_id UQ, code UQ, entity_type, action_code, scope_type, threshold_minor nullable, currency_code nullable, required_role_id FK, effective_from/to, revision, status, approved_by FK. Rules are versioned; numeric thresholds require currency. |
| approval_requests | id PK, public_id UQ, entity_type, entity_public_id, requested_action, submitted_by FK, submitted_at, state, policy_revision FK, decided_at. Decisions belong in append-only `application_decisions` or a generic approval decision table. |
| approval_decisions | id PK, approval_request_id FK, actor_user_id FK, action, remarks, decided_at, prior_state, next_state, operation_id UQ. Maker-checker and scope checks happen before insertion. |
| notification_outbox | id PK, public_id UQ, recipient_ref, channel, template_code, consent_id FK, payload_ref, status, created_at, retry_after, attempts, expires_at. Store minimum content; avoid sensitive message text. |
| notification_attempts | id PK, notification_id FK, attempt_no, attempted_at, result_code, provider_reference, next_retry_at. Unique notification + attempt number; no access token or full recipient secret. |
| backup_manifests | id PK, public_id UQ, app_version, schema_version, created_at, created_by FK, file_count, byte_length, sha256, encryption_algorithm, key_reference, backup_state, verified_at, restored_at. The actual key is held separately in protected storage. |
| import_jobs | id PK, public_id UQ, created_by FK, source_schema_version, started_at, finished_at, state, counts_json, reconciliation_hash, failure_code. Import source is staged and access-restricted. |

## Verified MFI domain target (if existing product is retained)

| Table | Columns and constraints |
|---|---|
| users | id PK, public_id UQ, username UQ, password_hash, display_name, status, must_change_password, created_at, disabled_at; never store plaintext password. |
| roles / permissions / user_roles / role_permissions | roles(id, code UQ, name, active); permissions(id, code UQ, description); user_roles(user_id, role_id, scope_type, scope_id, starts_at, ends_at, granted_by); role_permissions(role_id, permission_id, effect). Composite uniqueness; FKs; deny by default. |
| employees | id PK, public_id UQ, user_id FK nullable UQ, employee_code UQ, name, phone, email, designation, branch_id FK, manager_id FK, joined_on, status, salary_minor nullable, currency_code, created_at, archived_at. Salary access restricted. |
| branches | id PK, public_id UQ, code UQ, name UQ, address, phone, head_employee_id FK, latitude_scaled, longitude_scaled, geofence_radius_m CHECK > 0, active, created_at. |
| customers | id PK, public_id UQ, name, phone, date_of_birth, address fields, branch_id FK, agent_user_id FK, lifecycle_status, created_at, archived_at. Unique phone policy must account for household/shared phone and consent; do not assume global uniqueness without approval. |
| customer_identity | id PK, customer_id FK, id_type, encrypted_value, masked_last4, verification_status, verified_at, consent_record_id FK; unique active identity type per customer. Raw identity values encrypted and minimized. |
| consents | id PK, public_id UQ, subject_type/id, purpose_code, notice_version, captured_at, captured_by, method, withdrawn_at; immutable events, no overwrite. |
| customer_contacts | id PK, customer_id FK, contact_type, value, verified_at, preferred, consent_record_id FK; normalized phone/email and verification state. |
| communications | id PK, public_id UQ, customer_id FK, channel, direction, outcome, note, follow_up_at, actor_user_id FK, created_at; notes redact sensitive data. |
| loan_products / loan_product_versions | product id/code/name/status; version id/product_id FK/revision/effective dates, rate_scaled/rate_scale, amount bounds minor, tenure bounds/unit, method, fee rule, approval metadata. Immutable approved versions. |
| kyc_cases / kyc_answers / kyc_family_members | case id/customer FK/status/version/timestamps/reviewer; answers use controlled field code + typed value or normalized columns; family rows case FK/name/age/relation/education/occupation. Avoid storing the same sensitive field in multiple tables. |
| documents | id, public_id UQ, owner_type/id, document_type, local_relative_path, sha256, mime_type, byte_length CHECK >=0, encryption_key_ref, capture metadata, created_at, retention_until, deleted_at. No public URL for private files. |
| groups / group_members / group_reviews | group id/code/branch FK/center/status; membership group/customer FK/sequence/joined/left; unique active customer per group as policy allows; review id/group/version/checklist/status/reviewer/remarks/time. |
| applications / application_cashflows / application_documents | application id/public_id/customer/product_version FK/branch/status/requested_minor/currency/tenure/purpose/submitted_at; cashflow category/income_minor/expense_minor/period; document links and required state. Snapshot all terms and submitted values. |
| application_decisions | id/application FK/stage/action/amount_minor/reason/remarks/actor_user_id/actor_role/time/previous_state/new_state; append-only, unique operation_id. |
| loans | id/public_id/application_id FK UQ/customer/product_version FK/principal_minor/currency/contract_rate_scaled/rate_scale/tenure/method/disbursed_at/status/closed_at. Contract snapshot immutable. |
| repayment_schedule | id/loan_id FK/installment_no/due_date/principal_minor/interest_minor/fee_minor/total_minor/balance_minor/status; unique loan + installment. Generated and versioned before disbursement. |
| financial_transactions / allocations | transaction id/public_id/idempotency_key UQ/type/status/currency/amount_minor/effective_at/actor; allocation transaction FK/schedule FK/amount_minor. Posted rows immutable; reversal references original transaction. |
| attendance_events / attendance_corrections / leaves | event id/user FK/event type/captured_at/location scaled/accuracy/source/device; correction request and approval states; leave range CHECK and reason. Location retention configurable. |
| field_tasks / field_events | task id/customer FK/assignee FK/type/due/status; event public_id/task FK/operation_id UQ/captured_at/notes/amount_minor/receipt reference. Collection event links to financial transaction. |
| settings / setting_revisions / holidays | key UQ/value typed/schema_version; revision actor/effective dates/reason; holiday date PK/name. Never keep only mutable global values for governed policies. |

## Conditional manufacturing domain (only after approval)

Generic proposed fields below do not assert any Sarvoch product, material, specification, accounting policy or factory process. IDs, timestamps, money, quantity and lifecycle conventions follow the section above. Add organization_id/branch_id where the company confirms legal/entity separation.

| Table | Proposed columns, keys and constraints |
|---|---|
| parties | id, public_id UQ, party_type customer/supplier/both, legal_name, display_name, status, tax_identifier_encrypted nullable, created_at, archived_at. Do not assume tax fields until jurisdiction confirms. |
| party_contacts | id, party_id FK, name, role, phone, email, is_primary, consent_id FK; indexes party_id and normalized phone. |
| product_families | id, public_id UQ, code UQ, name, category_id FK nullable, description, lifecycle_status, created_at. |
| product_revisions | id, product_family_id FK, revision_code, effective_from/to, approval_status, approved_by FK, approved_at, notes; UQ family + revision. |
| specification_definitions | id, code UQ, label, data_type, unit_code, decimal_scale, min/max scaled, required, allowed_values_ref, active. |
| product_specifications | id, product_revision_id FK, definition_id FK, value_text/integer/scaled/boolean, source, verified_at; UQ revision + definition; CHECK exactly one typed value set. |
| product_media | id, product_revision_id FK, document_id FK, kind, alt_text, display_order, publication_status. |
| enquiries | id, public_id UQ, party_id FK nullable, source, contact_snapshot, status, owner_user_id FK, received_at, requested_date, notes, closed_reason. |
| enquiry_lines | id, enquiry_id FK, product_revision_id FK nullable, description, quantity_scaled, unit_code, scale, requested_spec_snapshot; never assume customer requested a catalog item if free-text. |
| follow_ups | id, enquiry_id FK, assigned_to FK, due_at, channel, outcome, note, completed_at; index status + due_at + assignee. |
| quotations | id, public_id UQ, enquiry_id FK, party_id FK, quote_number UQ, revision, status, currency_code, valid_until, terms_snapshot, subtotal_minor, tax_minor, total_minor, created_by FK, approved_by FK. |
| quotation_lines | id, quotation_id FK, line_no, product_revision_id FK nullable, description_snapshot, quantity_scaled, unit_code, scale, unit_price_minor, discount_minor, tax_code, line_total_minor; unique quote + line. |
| sales_orders | id, public_id UQ, order_number UQ, quotation_id FK nullable, party_id FK, status, currency_code, accepted_at, delivery_address_snapshot, promised_date, total_minor. |
| sales_order_lines | id, sales_order_id FK, line_no, product_revision_id FK nullable, product_snapshot, quantity_scaled, unit_code, scale, unit_price_minor, tax_minor, line_total_minor, fulfillment_state; unique order + line. |
| suppliers | Optional view/subtype over parties; supplier_code UQ, onboarding_status, payment_terms_code. Add fields only after procurement discovery. |
| purchase_requests | id, public_id UQ, request_number UQ, requester_id FK, status, needed_by, reason, created_at, approved_by FK nullable. |
| purchase_request_lines | id, request_id FK, line_no, item_id FK, description_snapshot, quantity_scaled, unit_code, needed_by, estimated_unit_cost_minor nullable. |
| purchase_orders | id, public_id UQ, po_number UQ, supplier_party_id FK, revision, status, currency_code, ordered_at, expected_at, terms_snapshot, subtotal_minor, tax_minor, total_minor, approved_by FK. |
| purchase_order_lines | id, purchase_order_id FK, line_no, item_id FK, description_snapshot, ordered_qty_scaled, unit_code, unit_price_minor, tax_minor, received_qty_scaled, status; unique PO + line. |
| inventory_items | id, public_id UQ, item_code UQ, item_type, description, base_unit_code, quantity_scale, tracking_policy, active. Technical definitions need owner input. |
| warehouses / stock_locations | warehouse id/code/name/status; location id/warehouse FK/code/parent_id FK/location_type; unique location code per warehouse. |
| inventory_lots | id, item_id FK, lot_code, supplier_party_id FK nullable, received_at, expiry_at nullable, quality_status; unique item + lot when lot tracking applies. |
| inventory_movements | id, public_id UQ, operation_id UQ, item_id FK, lot_id FK nullable, from_location_id FK nullable, to_location_id FK nullable, quantity_scaled CHECK >0, unit_code, movement_type, source_type/id, actor_id FK, posted_at, reversal_of FK nullable. Append-only. |
| stock_reservations | id, public_id UQ, item_id FK, lot_id FK nullable, location_id FK, source_type/id, quantity_scaled CHECK >0, status, expires_at; active reservations constrain availability transactionally. |
| bills_of_materials | id, public_id UQ, product_revision_id FK, revision, status, effective dates, approved_by FK. Required only if BOM confirmed. |
| bom_lines | id, bom_id FK, line_no, component_item_id FK, quantity_scaled, unit_code, scrap_allowance_scaled, optional_flag; unique BOM + line. |
| routings / routing_operations | routing id/product_revision_id FK/revision/status; operation id/routing FK/sequence/code/description/resource_type/setup_time/cycle_time/quality_plan_id FK nullable. Times in integer units. |
| production_orders | id, public_id UQ, order_number UQ, source_order_id FK nullable, product_revision_id FK, bom_id FK, routing_id FK, planned_qty_scaled, completed_qty_scaled, status, planned_start/end, approved_by FK. |
| job_cards | id, public_id UQ, production_order_id FK, operation_id FK, sequence, assigned_employee_id FK nullable, machine_resource_id FK nullable, planned_qty_scaled, status, started_at, completed_at; unique order + sequence. |
| production_events | id, public_id UQ, operation_id UQ, job_card_id FK, event_type, good_qty_scaled, rework_qty_scaled, scrap_qty_scaled, reason_code, actor_id FK, captured_at. Append-only output/wastage facts. |
| machine_resources | id, code UQ, name, resource_type, status, availability_calendar_ref, maintenance_state. Define machine data only after operational discovery. |
| quality_plans / quality_checks | plan id/code/revision/status; check id/plan FK/specification_definition_id FK/method/sampling rule/limits. Standards remain configuration requiring approval. |
| quality_inspections | id, public_id UQ, source_type/id, plan_id FK, inspector_id FK, status, inspected_at, disposition, notes. |
| quality_measurements | id, inspection_id FK, check_id FK, sampled_unit, value_scaled/text, unit_code, result, defect_code nullable; immutable measurement record. |
| nonconformances | id, public_id UQ, inspection_id FK nullable, source_type/id, severity, description, containment, disposition, owner_id FK, status, closed_at. |
| packages / package_lines | package id/public_id UQ/package_code UQ/order_id FK/status/sealed_at; line id/package FK/item_id FK/lot_id FK/quantity_scaled/unit. |
| shipments / shipment_lines | shipment id/public_id UQ/shipment_number UQ/order_id FK/carrier/tracking_ref/status/dispatched_at/delivered_at/proof_document_id FK; line shipment FK/order_line FK/quantity_scaled. |
| invoices / invoice_lines | invoice id/public_id UQ/invoice_number UQ/party_id FK/order_id FK nullable/currency/status/issued_at/due_at/subtotal_minor/tax_minor/total_minor; lines snapshot item/qty/price/tax. Legal numbering/tax require jurisdiction confirmation. |
| ledger_accounts / ledger_entries | account id/code UQ/name/type; entry id/public_id UQ/journal_id FK/account_id FK/debit_minor/credit_minor/currency/posted_at; journal must balance per currency and posted entries immutable. Requires accounting policy approval. |
| payment_receipts / payment_allocations | receipt id/public_id UQ/party_id FK/currency/amount_minor/method/reference/status/received_at; allocation receipt FK/invoice FK/amount_minor; sums cannot exceed receipt or open invoice balance. |

## Constraints and indexes

Enable foreign keys on every SQLite connection and verify them during initialization. Add indexes to all foreign keys and common filters: status + created date; branch/site + status; assigned employee + due date; party phone/name normalized search; product code; order/PO/quote number; movement item + location + timestamp; lot code; audit actor + timestamp. Enforce unique operation IDs, business numbers, line sequences and active product revisions. Use CHECK constraints for nonnegative quantities/amounts where domain permits, valid ranges, paired nullable values, status enums and exactly-one typed specification value.

Use short transactions for approval/posting: validate state, insert immutable event rows, update projections/reservations, commit. Rebuildable balances and dashboard totals are projections over append-only movements; never treat a cached total as the sole source of truth.

## Data retention and seed data

Seed only non-sensitive lookup data and an explicitly isolated demo dataset. Production initialization must not create demo users or real-looking customer records. Do not migrate prototype passwords, mock payment card data, or abandoned temporary secrets. Preserve required financial/audit records according to a retention schedule approved for the legal entity; support privacy erasure through controlled redaction or key destruction where legally allowed without altering ledger evidence.
