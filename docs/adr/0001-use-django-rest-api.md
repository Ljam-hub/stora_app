# ADR-0001: Use Django REST Framework (DRF) as the Core Backend API

## Status
Accepted

## Context
STORA powers two Flutter mobile clients: `stora_owner` (for retail store management, inventory, POS, and utang tracking) and `stora_customer` (for store discovery, catalog browsing, and ordering). The backend must support rapid feature iteration, robust transactional data integrity (especially for store credit ledgers and real-time inventory counts), fine-grained role-based access control, and low-latency mobile networking.

The engineering team considered:
1. **Django REST Framework (DRF)** with Python
2. **GraphQL** (e.g., Graphene / Apollo)
3. **FastAPI** with SQLAlchemy

While GraphQL provides flexible client querying, mobile clients with intermittent 3G/4G connectivity in retail settings suffer from query-payload parsing overhead, complex client-side caching, and difficulty in setting up standard HTTP caching headers and CDN proxies. FastAPI offered high raw throughput but lacked built-in authentication, mature admin panels for system oversight, and battle-tested ORM migration tools needed for rapid schema changes.

## Decision
We chose **Django REST Framework (DRF)** using predictable RESTful JSON endpoints.
- DRF provides built-in serializers with strict validation rules, automatic API documentation, and robust transaction management.
- Standard HTTP status codes (200, 201, 400, 401, 403, 404, 409) simplify mobile network interceptors and error logging.
- Django's built-in Admin portal gives operations and support teams immediate data inspection capability without building separate web management dashboards.

## Consequences
- **Positive**:
  - Predictable resource-based endpoints (`/api/products/`, `/api/orders/`, `/api/pos/checkout/`, `/api/utang/`) simplify contract tests between backend and mobile engineers.
  - Django ORM handles ACID transactions seamlessly for atomic stock decrements during checkout.
  - High developer velocity and reliable schema migrations via `manage.py migrate`.
- **Negative / Trade-offs**:
  - Over-fetching can occur when mobile views only need a subset of entity fields; mitigated by dedicated lightweight serializer views (e.g., list views vs detailed views).
  - WebSockets or background push notifications (Firebase Cloud Messaging) are required for instant customer-owner order status sync rather than GraphQL subscriptions.
