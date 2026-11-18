# Role and permission design

## Existing roles and target posture

The Flask source defines five roles: admin, manager, underwriter, field_agent and customer. `PERMS` is a server-side module map in app.py:47-80. Flutter uses `UserModel.can` for its current MFI module grants. The current customer role represents an authenticated borrower, not a public visitor. Employee role assignment does not currently equal a granular permission system.

The manufacturing roles in the brief are proposed only. Use capability permissions and organizational scope, not hard-coded role names. An employee may hold multiple roles. Granting multiple roles combines permissions only within that employee's branch/site/record scope and risk limits. Never grant approval of a record the same user created where separation of duties is required.

## Proposed permission codes

Each action should be independently representable: `view`, `create`, `edit_draft`, `submit`, `approve`, `reject`, `post`, `reverse`, `delete_draft`, `export`, `print`, `view_financial`, `administer`. Scope attributes: own, assigned, team, branch/site, all. Restrict sensitive fields within a record separately (identity numbers, bank data, salary, cost/margin).

## Capability matrix

Legend: V view, C create, E edit draft, A approve/reject, P post/reverse, X export/print, F financial details, G administer; `*` means scope restricted. Proposed mappings require approval.

| Current/proposed role | Customer/enquiry | Quote/order | Procurement/stock | Production/quality | Dispatch | Finance | HR/attendance | Audit/settings/users |
|---|---|---|---|---|---|---|---|---|
| Owner / Super Admin (proposed) | VCE* | VCEAFP* | VCEAFP* | VCEAFP* | VCEAFP* | VFXG* | VCEAG* | VXG |
| Administrator (proposed; current admin closest) | VCE* | VCEAFP* | VCEAFP* | VCEAFP* | VCEAFP* | VFX* | VCE* | VX* |
| Sales Manager (proposed) | VCE* | VCEAFP* | V* | V* | V* | VFX* | V* | V* |
| Sales Executive (proposed) | VCE* | VCE* | V* | V* | V* | V limited | own attendance | V* |
| Production Manager (proposed) | V* | V* | V* | VCEAP* | V* | V* | V* | V* |
| Production Operator (proposed) | assigned V* | order V* | assigned stock V* | assigned VCE* | V* | none | own attendance | none |
| Store Manager (proposed) | V* | V* | VCEAP* | V* | VCE* | cost limited | V* | V* |
| Purchase Manager (proposed) | supplier VCE* | V* | VCEAP* | material V* | none | supplier cost V* | V* | V* |
| Quality Inspector (proposed) | V* | V* | quarantine V* | VCEAP* | release checks V* | none | own attendance | V* |
| Packing Manager (proposed) | V* | order V* | finished stock V* | output V* | VCE* | none | team attendance | V* |
| Dispatch Manager (proposed) | V* | order V* | pick V* | release V* | VCEAP* | invoice status limited | team attendance | V* |
| Accounts Manager (proposed) | V* | quote/order totals V* | PO totals V* | cost summary V* | shipment V* | VCEAPFX* | payroll totals only | V* |
| HR Manager (proposed) | none | none | none | none | none | payroll restricted | VCEAPX* | user fields limited |
| Auditor / Viewer (proposed) | read-only scoped | read-only scoped | read-only scoped | read-only scoped | read-only scoped | read-only approved | read-only scoped | VX read-only |
| Current MFI underwriter | MFI CRM/KYC V* | loan applications VEA* | N/A | N/A | N/A | scoped loan values | N/A | audit limited |
| Current MFI field_agent | assigned CRM/field VCE* | assigned application V* | N/A | N/A | N/A | collection post with limits | own attendance | none |
| Current MFI customer | own borrower portal V* | own loan request V* | N/A | N/A | N/A | own balance/payment view | none | none |

This is a draft capability map, not proof of exact current website permissions. A permission evaluation must check both permission and scope on every use case and server route. Deny by default.

## Permission lifecycle and separation of duties

- Store roles, permission grants and user-role assignments as versioned records with effective dates, actor and reason.
- Support multiple roles but surface the active operating context; never use role switching as privilege escalation.
- Use record-level scope checks in repositories/use cases and server handlers.
- High-risk transitions (approve, disburse/post, stock adjustment, invoice void, export sensitive data, restore) require re-authentication or step-up where threat model warrants it.
- Enforce maker-checker rules on material/financial approvals. A role that can create cannot automatically approve its own record.
- Revoke sessions/keys when employee is disabled, role is removed or device is reported lost.
- Public visitor, borrower/customer, employee, supplier contact and administrator are distinct identity classes; only public visitor is unauthenticated and should see explicitly published data.

## Current Flutter MFI enforcement

The route table maps every authenticated route to an explicit MFI module grant;
unknown routes fail closed. The navigation drawer uses the same role-to-module
grants, so a hidden menu item and a direct route attempt produce the same
decision. Managers can open portfolio reports, which consume the branch-scoped
loan snapshot. This remains module-level authorization: each data provider must
still enforce current account status, record assignment, branch/customer scope,
and transition-specific rules inside the database operation. Runtime role and
scope verification remains a release gate.
