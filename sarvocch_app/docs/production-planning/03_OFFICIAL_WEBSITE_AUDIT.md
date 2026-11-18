# Website/source audit

## Scope and source of truth

The user clarified that the website is local source in /Users/vaidik/sarvocch_repo and no Sarvoch website is available online. This audit therefore uses that local Git-tracked Flask application as the website reference. External search results for similarly named companies are not used as evidence.

Verified source baseline: repo branch feature/flutter-mobile-app, commit df56cb71e2104e742217a658e6b20af6db1c5fc3. README.md calls the app a “Micro Finance Portal (prototype)” and says KYC, payment gateway, eNACH and WhatsApp are mocked. No verified public corporate domain, public product-catalogue website, public enquiry form or manufacturer profile is present in the local code. The portal is authenticated and server-rendered. The available online/offline details are build/deploy configuration, not proof of an active public deployment.

## Page and workflow inventory

The source NAV list defines 20 modules (app.py:58-80). Main pages and workflow endpoints are:

| Area | Routes/templates | Observable behavior |
|---|---|---|
| Identity/session | /login, /logout, /change-password, /crm/<id>/login-slip | User login, logout, password change, one-time printed customer login slip |
| Dashboard | /dashboard, /dashboard/details | Portfolio KPIs and drill-down filters |
| Lending products | /products, /calculator, /api/emi | Loan-product parameters, EMI estimate |
| CRM | /crm, /crm/new, /crm/<id>, /log, /stage | Customer lead, lifecycle, communications and linked loan data |
| KYC | /kyc-form/new, /crm/<id>/kyc-form, /kyc-form/print, /kyc, /api/kyc/verify | Bilingual borrower dossier, attachments, local verification queue and format/checksum validation |
| Origination | /apply, /applications, /applications/<id>, /applications/<id>/action | Cash-flow-based loan application and staged approval/disbursement |
| Servicing | /loans, /loans/<id>, /pay/<id>, /settle, /autopay, /autopay/run, PDFs | Schedule, mock payment, settlement, mandate simulation, sanction/NOC/passbook print views |
| Group lending | /pregrt, /pregrt/new, /pregrt/<id>, /review, /print, /apply | Group formation, manager review and group application |
| Field/attendance | /field, /field/assign, /field/task/<id>/done, /attendance, /attendance/punch, /attendance/request, /api/location, /api/nearby | Visit itinerary, cash collection, branch-geofenced attendance, correction request |
| Organization/HR | /branches, branch details, /employees, /hrm, leave/performance actions, print view | Branches, employees, leave and ratings |
| Communications/sync | /whatsapp, /whatsapp/<id>/send, /verify, /sync, /api/sync | WhatsApp link/OTP simulation and mobile transaction queue ingestion |
| Administration | /settings, /users, /users/<id>/role | Lending policy controls, role updates |
| PWA | /sw.js, /manifest.json, /offline | Service worker, install manifest and offline fallback |

Route handlers are implemented in app.py:494-2907; HTML is in templates/. Product listings are MFI loan products, not industrial products (app.py:682-707; templates/products.html). There are no manufacturing, raw-material, procurement, quality-inspection, packing or dispatch pages.

## Form and CTA behavior

The operational UI is primarily a staff portal, not a public prospect/enquiry funnel. Forms submit to Flask POST handlers, flash success/error messages, and redirect to detail/list views. KYC and loan forms validate server-side and do not write their main records if validation errors remain (app.py:1893-2098, 2214-2337). Password, OTP, payment, KYC verification, mandate and sync workflows have demo/mock or prototype aspects. Exact visible control inventory is in 05_WEBSITE_FIELD_DICTIONARY.md.

## Assets, navigation and interactions

Static source includes CSS, JavaScript, icons and a service worker. templates/base.html loads Bootstrap and Bootstrap Icons from jsDelivr, so first load depends on external resources unless cached. Map views link to Google Maps; WhatsApp communication uses a click-to-chat URL. The service worker caches successful GET responses and falls back to /offline (static/sw.js); this is not proof that POST-based create/approve/pay workflows work offline. There are no source assets evidencing factory photography, technical data sheets, catalogues or company certifications.

## Verified facts vs. blockers

- **Verified:** internal finance portal; 20 navigation entries; five code roles; local SQLite server database; mock integrations; several print/PDF workflows.
- **Requires business confirmation:** whether the organization is intended to operate as a microfinance entity, a manufacturer, or both. The website code cannot substantiate the manufacturing brief.
- **Unverified:** any public domain, public visitor/registered-customer marketing pages, catalogue/downloads, public enquiry form, current company legal profile, certifications or product engineering specifications.
- **Inaccessible/not applicable:** no live deployment was supplied, so browser interaction and production success/failure states cannot be independently observed. Source routes/templates were inspected instead.

## Website-source citations

Use repository-relative references in the source repo: README.md:1-5; app.py:1-5, 47-80, 494-2907; templates/base.html; static/sw.js; docs/requirements/WEB_FLUTTER_PARITY_MATRIX.csv. These are local source paths, not public URLs.
