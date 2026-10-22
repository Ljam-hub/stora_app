# ADR-0004: Offline Resilience with Local SQLite/Drift Caching and Sync Queues

## Status
Accepted

## Context
Philippine neighborhood retail stores (sari-sari stores) frequently experience spotty, throttled, or interrupted mobile data and Wi-Fi connectivity. If a store owner cannot ring up cash sales, check stock, or record a customer's utang credit while the internet is down, the app is unusable in real-world retail environments.

We considered:
1. **Cloud-Only Architecture**: Require an active network connection for all operations.
2. **Local Storage with Optimistic UI & Sync Queue**: Cache essential catalog and inventory data locally using SQLite / Drift / SharedPreferences and queue mutations for background synchronization upon reconnection.

## Decision
We implemented **Offline-First Resilience**:
- Read operations for POS catalogs, inventory lists, and customer profiles query local SQLite / in-memory reactive stores (`InventoryStore`, `CartStore`, `UtangStore`) first.
- POS checkouts when offline are assigned temporary local UUIDs, marked as `pending_sync`, and written to local database tables.
- A background `ConnectivityService` listens to connectivity state changes; when network access is restored, queued mutations replay to the Django backend.

## Consequences
- **Positive**:
  - Store owners can continue serving in-store walk-in customers and ringing up orders with zero latency even during network outages.
  - Significantly reduced mobile data consumption since cached product images and static metadata do not re-fetch repeatedly.
- **Negative / Trade-offs**:
  - Potential merge conflicts if product stock is modified concurrently from multiple devices (resolved by last-write-wins with backend timestamp validation and stock reconciliation notices).
