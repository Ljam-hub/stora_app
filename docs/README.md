# STORA Documentation & Group 4 Deliverables

This directory contains the complete architectural, testing, and compliance documentation for the **STORA** mobile retail management platform (Day 22 · Topics 13–16: "Draw it, then prove it").

---

## 1. System Overview
STORA provides a resilient, modern retail operating system for micro-merchants (sari-sari stores) and neighborhood consumers in the Philippines, built on Flutter (`stora_owner` and `stora_customer`) and Django REST Framework (`stora_backend`).

---

## 2. Topic 13 · C4 & UML Diagrams
- **System Context Diagram**: Merchant, Shopper, GCash QR, and Firebase integrations.
- **Container Diagram**: Dual Flutter clients, Django REST API on Render, and PostgreSQL 16.
- **UML Diagrams**: Fast Checkout Sequence, Store Use-Case, and relational ERD matching the database schema.
- Reference: [ARCHITECTURE.md](../ARCHITECTURE.md)

---

## 3. Topic 14 · Architecture Decision Records (ADRs)
Stored in [`docs/adr/`](adr/):
1. [`0001-use-django-rest-api.md`](adr/0001-use-django-rest-api.md) — Django REST Framework over GraphQL.
2. [`0002-relational-postgres-with-sqlite-dev.md`](adr/0002-relational-postgres-with-sqlite-dev.md) — PostgreSQL ACID transactions for utang credit ledgers.
3. [`0003-flutter-multi-client-architecture.md`](adr/0003-flutter-multi-client-architecture.md) — Dual dedicated mobile applications over monolithic app.
4. [`0004-offline-resilience-local-caching.md`](adr/0004-offline-resilience-local-caching.md) — Offline SQLite/Drift caching and sync queues.
5. [`0005-ra10173-data-privacy-and-role-isolation.md`](adr/0005-ra10173-data-privacy-and-role-isolation.md) — Philippine Data Privacy Act compliance & tenant isolation.
6. [`0006-hybrid-jwt-firebase-authentication.md`](adr/0006-hybrid-jwt-firebase-authentication.md) — Firebase credential exchange with backend JWT tokens.

---

## 4. Topic 15 · User Acceptance Testing (UAT) & Consent
Stored in [`docs/uat/`](uat/):
- [`UAT_PLAN_AND_CRITERIA.md`](uat/UAT_PLAN_AND_CRITERIA.md) — 10-participant testing protocol with pre-set acceptance criteria ("4 of 5 merchants unaided in <90s", 100% pass rate achieved).
- [`INFORMED_CONSENT_FORM_RA10173.md`](uat/INFORMED_CONSENT_FORM_RA10173.md) — Participant informed consent form compliant with RA 10173.

---

## 5. Topic 16 · Accessibility Audit & Fixes
Stored in [`docs/accessibility/`](accessibility/):
- [`A11Y_AUDIT_AND_FIXES.md`](accessibility/A11Y_AUDIT_AND_FIXES.md) — 5 high-value WCAG 2.1 AA fixes (15.8:1 contrast ratio, 54dp `_MenuTile` touch targets, screen reader labels, scalable text) and honest barcode viewfinder gap disclosure.

---

## 6. STORA Presentation Deck & Speaker Notes (PDF)

The full 19-slide presentation matching the syllabus and styled in STORA's exact design theme, accompanied by exhaustive defense speaker notes:

- **PDF Deck**: [docs/presentation/stora_group4_presentation.pdf](presentation/stora_group4_presentation.pdf) (19 widescreen pages, 16:9, dark retail theme)
- **Speaker Notes PDF**: [docs/presentation/stora_group4_speaker_notes.pdf](presentation/stora_group4_speaker_notes.pdf) (12-page comprehensive defense guide with verbatim scripts, panel Q&A, and technical deep-dives)
- **Markdown Notes**: [docs/presentation/PRESENTATION_SPEAKER_NOTES.md](presentation/PRESENTATION_SPEAKER_NOTES.md)
