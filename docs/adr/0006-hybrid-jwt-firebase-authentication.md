# ADR-0006: Hybrid Firebase Authentication and JWT Token Session Management

## Status
Accepted

## Context
Mobile apps require secure, friction-free authentication. Customers prefer fast email/phone verification and OAuth options, while merchants require rock-solid session durability without being logged out during middle-of-the-day POS shifts.

We evaluated:
1. **Django Session Cookies**: Traditional session IDs stored in HTTP-only cookies.
2. **Pure Custom JWT Authentication**: Custom token issuance and refresh rotation built entirely in DRF.
3. **Hybrid Firebase Auth + Backend JWT Verification**: Firebase handles mobile credential validation and secure token exchange, while Django validates tokens and manages domain user records.

Standard session cookies struggle with mobile app cross-origin state and background sync workers. Pure custom JWT requires maintaining custom phone OTP SMS gateways and password hashing infrastructure.

## Decision
We chose a **Hybrid Authentication Model**:
- Mobile clients authenticate against Firebase Authentication (or Django JWT endpoints via `/api/auth/token/`).
- The Django backend validates the bearer token via middleware using `firebase-admin` SDK or `rest_framework_simplejwt`.
- Authenticated requests generate stateless JWT access tokens (valid for 60 minutes) paired with secure refresh tokens stored in encrypted local storage (`flutter_secure_storage`).

## Consequences
- **Positive**:
  - Eliminates server session state storage, enabling horizontal scaling of backend API instances on cloud platforms (Render).
  - Secure credential storage on mobile devices with biometric unlock support where available.
  - Native support for email verification status checks (`is_email_verified`) to safeguard user accounts.
- **Negative / Trade-offs**:
  - Token revocation requires maintaining a short-lived token blacklist in Redis/cache for immediate session termination upon password change or account deletion.
