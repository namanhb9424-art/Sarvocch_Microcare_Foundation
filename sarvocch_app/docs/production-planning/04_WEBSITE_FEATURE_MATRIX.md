# Website vs. Flutter feature matrix

## Coverage definition

There is no external public company website. The denominator below is the 20 operational navigation modules defined by the local website code in /Users/vaidik/sarvocch_repo/app.py:58-80. A module counts structurally covered when the Flutter source has a route or corresponding screen. This measures screen/module presence only, not behavior, security, offline correctness or release quality.

**Structural coverage: 17 / 20 = 85.0%.** Missing as standalone equivalents are website user administration and sync dashboard; employee directory is partial within Flutter HRM. If counting the existing field-level matrix instead, 31 / 42 rows are tagged MATCHED + VERIFIED = 73.8%. Ten rows are MISSING_IN_FLUTTER and one row has a malformed status value. The field-level number is a static prior matrix count, not a runtime result.

## Navigation-level matrix

| Website module | Website functionality | Flutter status | Gap/improvement |
|---|---|---|---|
| Dashboard | Portfolio KPIs, branches, pipeline | Partially implemented | Existing docs note hardcoded/unfinished analytics; recompute from ledger |
| Customer portal | Borrower balances, next due, payment and NOC | Partially implemented | Payment actions are simulation; isolate only customer's loans |
| CRM | Lead list, profile, communication, stage | Partially implemented | Add durable follow-up task ownership, duplicate prevention and scope-safe search |
| New KYC | Bilingual borrower dossier and upload | Partially implemented | Map all website fields; sensitive-data storage and consent policy needed |
| Pre-GRT | Group roster, seven checks, review | Partially implemented | Group batch loan path and atomicity need explicit verification |
| New application | Product, amount, term, cash flow, docs and declarations | Partially implemented | Match server validation and persist immutable submitted snapshot |
| Applications | Stage queue and detail | Partially implemented | Enforce transition graph and approval authority in domain layer |
| Loans/EMI | Loan schedule, repayments, settlement | Partially implemented | Exact money, transactional posting, receipt/refund/reversal flows |
| KYC verify | Aadhaar/PAN/Voter ID checks | Partially implemented | Current checks are local simulations/format checks; real verification provider unconfirmed |
| Calculator | Flat/reducing EMI estimate | Implemented as screen | Keep quote estimate separate from authoritative booked schedule |
| Products | Loan product settings | Implemented as screen | Snapshot product terms; avoid editing terms of issued loans |
| Field operations | Assignment, GPS, collection | Partially implemented | Persist captured offline events and resolve duplicate/conflicting collection |
| Offline sync | Sync page, queue review and upload | Missing standalone page | Provider/service exists in source; no routed screen; backend protocol/integrity needs redesign |
| WhatsApp | OTP and messaging hub | Partially implemented | Current OTP simulation is not a delivered/verifiable external message |
| Employee directory | Employees and onboarding docs | Partially implemented | No equivalent standalone route in Flutter; matrix records directory gaps |
| HRM | Leave, attendance and performance | Partially implemented | Verify each approval workflow and payroll calculation before claiming parity |
| Attendance | Punch-in/out and regularization | Partially implemented | GPS can be unavailable/spoofed; record accuracy/source and allow approved correction |
| Branches | Branch master and portfolio | Implemented as screen | Validate branch scoping and role access beyond drawer visibility |
| Settings | Policy thresholds/holidays | Implemented as screen | Validate bound ranges, audit revisions and effective dates |
| Users & roles | User list and role assignment | Missing | Add user lifecycle, custom roles, multi-role assignment and disable/revoke workflow |

Status labels are static source review classifications, not test claims. The master brief's manufacturing requirements are “requires verification / scope decision”; no local site evidence supports those modules. They are not silently counted as implemented by finance loan-product screens.

## Feature evidence and parity gaps

The local parity CSV identifies these missing items: group batch application, branch create/edit, staff directory, leave workflow, performance ratings, WhatsApp send/verify, printable KYC dossier and loan passbook (docs/requirements/WEB_FLUTTER_PARITY_MATRIX.csv). Review these claims against current widget/provider code before implementation; records marked matched also need behavior-level validation.

## Manufacturing module disposition

| Brief feature | Evidence in local source | Status |
|---|---|---|
| Company profile and product specifications | Only finance-portal branding and loan products | Requires scope decision |
| Supplier/customer enquiry and quotation | Borrower CRM / loan applications exist; supplier and B2B quoting do not | Missing for manufacturing; domain unclear |
| Procurement/raw materials/warehouse | No tables, routes, templates or provider | Missing / unverified |
| BOM/routing/job cards/production/wastage | No local evidence | Missing / unverified |
| Quality/defects/packaging/dispatch | No local evidence | Missing / unverified |
| Invoice/accounts/payables | Loan payments exist but not sales invoices or general ledger | Missing for manufacturer; domain unclear |

No public visitor/customer segmentation was found in the templates. The customer role is an authenticated borrower role; it must not be interpreted as a public visitor or B2B customer account.
