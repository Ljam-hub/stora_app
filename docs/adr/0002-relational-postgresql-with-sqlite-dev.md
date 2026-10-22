# ADR-0002: Relational PostgreSQL Engine for Production and SQLite for Local Development

## Status
Accepted

## Context
Retail store transactions in the Philippines revolve around interconnected entities: store owners, store locations, inventory stock, customer carts, and critical credit tracking (the informal *utang* debt ledger). In an utang ledger, balances must never drift due to race conditions or partial writes; transactions, interest calculations, and repayments must adhere to strict ACID compliance.

We evaluated:
1. **Relational Database (PostgreSQL)**
2. **Document / NoSQL Database (MongoDB / Cloud Firestore)**

NoSQL would have allowed flexible schema storage for arbitrary product variants, but lacks strict relational foreign key constraints, atomic multi-document transactions across stores and debt ledgers without high operational overhead, and makes financial audits error-prone.

## Decision
We chose a **Relational SQL Architecture**:
- **PostgreSQL** in production (hosted on Render managed cloud database).
- **SQLite3** for lightweight zero-setup local developer workflows and CI automated test execution.
- Django ORM abstracts SQL dialect differences, enforcing constraints (`ForeignKey(on_delete=PROTECT)`, unique constraints, and check constraints on non-negative inventory balances).

## Consequences
- **Positive**:
  - Full ACID compliance prevents financial inconsistencies when recording POS cash/credit payments.
  - Complex aggregation queries (daily gross revenue, top selling items, outstanding credit by customer) run efficiently using relational joins and SQL indices.
  - Schema migrations are tracked in source control, versioned, and reversible.
- **Negative / Trade-offs**:
  - Requires database migration downtime planning or non-blocking schema migration patterns during production updates.
  - SQLite lacks certain advanced Postgres features (such as `Distinct on` or specific JSONB operators), requiring test suites to run against SQLite-compatible queries or containerized Postgres for staging.
