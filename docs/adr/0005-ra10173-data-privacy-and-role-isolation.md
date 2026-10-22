# ADR-0005: Compliance with Philippine Data Privacy Act of 2012 (RA 10173) and Role-Based Data Isolation

## Status
Accepted

## Context
STORA collects personal identifiable information (PII) including customer full names, mobile contact numbers, physical delivery addresses, GPS coordinates, purchase histories, and informal financial credit ledgers. Under the **Philippine Data Privacy Act of 2012 (Republic Act No. 10173)** and the **Cybercrime Prevention Act of 2012 (RA 10175)**, platforms processing personal data are legally mandated to implement technical and organizational security measures ensuring data confidentiality, integrity, user consent, and right to erasure.

We evaluated:
1. **Shared Database Tenant Model without Field Masking**: Owners and admins can view complete user profiles.
2. **End-to-End Role-Based Isolation & PII Shielding**: Backend views enforce user ownership filters, customer phone numbers and delivery notes are accessible only to the fulfilling store for the duration of the active order, and verification codes/passwords are never logged or exposed.

## Decision
We implemented strict **Privacy by Design and Role Isolation**:
- Explicit informed consent and privacy notice modal links are integrated directly into the login screens of both `stora_owner` and `stora_customer`.
- Backend endpoints enforce database-level row-level security (RLS) and Django query filters (`filter(user=request.user)` and `filter(store=request.user.store)`).
- Customers have an explicit "Delete Account" action (right to erasure / right to be forgotten under RA 10173), permanently purging authentication records, personal contact info, and token sessions.
- In-transit communication is strictly secured using TLS 1.3 encryption.

## Consequences
- **Positive**:
  - Full legal defensibility before technical panel judges, compliance auditors, and National Privacy Commission (NPC) regulations.
  - Zero risk of cross-merchant data leakage or unauthorized data scraping between competitor stores.
  - User trust is established upfront with transparent consent dialogues.
- **Negative / Trade-offs**:
  - Customer profile deletion requires cascading de-identification (anonymizing historical sales receipts while preserving anonymous numerical revenue totals so merchant sales history balances remain intact).
