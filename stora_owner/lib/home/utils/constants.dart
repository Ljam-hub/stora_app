/// Shared inventory stock ceiling — used by both the stepper buttons and
/// the Add/Edit product form validator so the two can never disagree.
const int kMaxStock = 99;

/// Free plan's total product count ceiling — checked wherever a new
/// product can be added (Dashboard's "Add Product" button, Inventory's
/// FAB) so hitting it consistently routes to the upgrade screen instead
/// of silently letting the count climb past the number shown on the
/// Free plan card.
const int kFreePlanProductLimit = 20;

/// Premium plan's monthly price (₱) — shown on SubscriptionScreen and
/// must match the amount UploadGcashProofScreen asks the owner to send,
/// so both reference this instead of repeating the number.
const int kPremiumMonthlyPrice = 70;
