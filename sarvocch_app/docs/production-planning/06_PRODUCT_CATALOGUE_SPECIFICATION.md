# Product catalogue specification

## Evidence boundary

The local website is a microfinance operations portal. Its product catalogue contains loan products, not manufactured goods. No public catalogue, transformer specifications, images, variants, applications or customisation options were found in the supplied source. Consequently, no industrial product values are asserted here. The manufacturing catalogue below is a capture model for discovery, and must be configured only after the business owner supplies an approved catalogue.

## Current loan-product record

Verified in website app.py schema and product routes (source repository at /Users/vaidik/sarvocch_repo; app.py:116-117, 682-707; Flutter equivalent in sarvocch_app/lib/data/database_helper.dart):

| Field | Current type/meaning | Current rule or gap |
|---|---|---|
| id | Integer primary key | Server and device generated IDs may collide if naïvely merged. |
| name | Text | Unique business identity is not enforced. |
| rate | REAL | Financial rate representation/period/nominal-vs-effective semantics need confirmation. |
| min_amt, max_amt | REAL | Loan bounds; product-level validation in application flow. |
| min_tenure, max_tenure | Integer | Unit is months by UI convention; store unit explicitly in future model. |
| method | Text | Values include reducing and flat. |
| fee_pct | REAL | Fee basis, tax inclusion and effective date need confirmation. |
| active | Integer boolean | No historical versioning. |
| admin_only, group_only | Integer booleans | Added by web migration, absent from initial CREATE TABLE; access policy should be explicit. |

For a booked loan, retain a versioned terms snapshot on the application and loan. Editing a product must not rewrite signed or disbursed terms. Quotes must be distinguishable from approved offers and booked contracts.

## Conditional manufacturer catalogue model

If the owner confirms manufacturing scope, use a product family plus revisioned specification model. Keep attributes typed and unit-bearing; do not place all values in a free-form JSON blob. Initial generic fields:

| Entity | Candidate fields | Constraint / intent |
|---|---|---|
| ProductFamily | id, code, name, description, category_id, lifecycle_status, created_at, updated_at | Unique code; status draft/active/retired; no engineering defaults inferred. |
| ProductRevision | id, product_family_id, revision_code, effective_from, effective_to, approval_status, approved_by, approved_at, notes | Unique family + revision; approved revisions immutable; one current approved revision per family. |
| SpecificationDefinition | id, code, label, data_type, unit_code, allowed_values, min_value, max_value, required, sort_order | Controlled by authorized product administrator; unit and precision required for numeric values. |
| ProductSpecification | id, product_revision_id, specification_definition_id, value_text/value_integer/value_scaled/value_boolean, source, verified_at | Exactly one typed value column populated; unique revision + definition; validation must check definition type/range. |
| ProductMedia | id, product_revision_id, attachment_id, media_kind, alt_text, display_order, public_visibility | Media stored in attachment subsystem, with rights/source and retention metadata. |
| ProductCategory | id, parent_id, code, name, display_order, active | Optional hierarchy; unique code. |
| ProductOption | id, product_revision_id, code, label, option_type, required, rule_definition | Only use after real variants/options and compatibility rules are documented. |

Product classes, technical values, units, test standards, certifications, customer customisation and photos remain open business inputs. Catalogue publication should select an approved revision and approved media only. Public visibility is a future capability: current website customer accounts are authenticated borrowers, not public catalogue users.

## Catalogue acceptance criteria

- Every product revision has a stable code, lifecycle state, approval history and effective dates.
- Every numeric specification includes a unit and declared precision; invalid combinations are rejected.
- A revised product retains prior approved versions and linked quote/order snapshots.
- Search/filter uses approved fields and does not expose internal costing or supplier records to visitors.
- Missing engineering facts display as missing; the UI never supplies invented values.
- Loan product edits preserve existing application and loan snapshots if MFI scope remains active.
