# ADR-0003: Multi-Client Independent Flutter Apps (`stora_owner` & `stora_customer`)

## Status
Accepted

## Context
STORA serves two fundamentally distinct personas:
1. **Store Owners / Merchants**: Need fast barcode scanning, high-density inventory tables, POS checkout, offline debt tracking, sales analytics, and business QR setup.
2. **Shoppers / Customers**: Need geolocation map discovery, visual product browsing, multi-store shopping cart, order tracking, and peer chat.

We considered:
1. **Single Unified Super-App** with dynamic role toggling.
2. **Dual Dedicated Mobile Applications** (`stora_owner` and `stora_customer`) sharing an underlying backend API.

A single unified app would have caused bloated APK binary size (bundling POS camera barcode ML libraries, thermal receipt printing, heavy map rendering, and dual UI layouts into one package), high security risk (accidental permission escalation if a customer bypassed role checks), and confused user onboarding.

## Decision
We chose **Dual Dedicated Flutter Applications**:
- `stora_owner`: Tailored specifically for merchant ergonomics, dark-mode default for eye comfort during long shifts, rapid tactile actions, and offline POS resilience.
- `stora_customer`: Tailored for discovery, light/dark responsive shopping experience, clean navigation, and location-based order flows.
- Both clients communicate with the unified Django REST API (`stora_backend`) using role-scoped API tokens.

## Consequences
- **Positive**:
  - Smaller APK sizes (~25MB each vs ~50MB+ unified).
  - Clear security boundary: Customer app contains zero merchant ledger modification logic or owner admin views.
  - Independent release cycles: Customer UI improvements can be published to app stores without risking store owner POS stability.
- **Negative / Trade-offs**:
  - Shared models (e.g. `Product`, `Order`) require duplicate Dart definitions across the two Flutter codebases unless extracted into a shared internal Dart package.
