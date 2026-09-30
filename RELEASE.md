# Stora Release v1.2.1

**Release Tag:** `v1.2.1`  
**Date:** September 30, 2026  
**Artifacts:** 
- `Stora-Customer.apk` (56.0 MB)
- `Stora-Owner.apk` / `Stora.apk` (80.7 MB)

---

## 🚀 Overview

Release `v1.2.1` introduces full GCash / mobile payment and QR code configuration, direct on-screen digital paper receipt viewing for customer and owner apps, unified stock alerts tab navigation, optimistic instant product creation and editing, standardized 1.5-second feedback guides, and hardened account lifecycle protection in the Django Admin backend.

---

## 📱 Mobile Applications

### 🛍️ Stora Customer (`v1.2.1`)
- **Direct Digital Receipt Viewer:** Tapping the receipt icon on order cards now opens an authentic on-screen digital paper receipt displaying itemized breakdown, store details, totals, and payment method without forcing the system print dialog.
- **Store Payment & QR Code at Checkout:** Customers can view the store's GCash / mobile payment number with a 1-tap Copy action (+ 1.5s SnackBar guide) and tap to view enlarged store payment QR codes.
- **High-Contrast Stock Visibility:** Overhauled product detail stock badge with vivid neon status dots and high-contrast bold indicators for healthy stock, low stock (<5), and sold-out states.
- **Shop Category Badge Fix:** Removed redundant overlapping store name badge on shop cards, making all product category names 100% visible and unclipped.
- **Smooth Store Carousel:** Added bouncing scroll physics to the Available Stores horizontal carousel.
- **Snappy 1.5s SnackBars:** Standardized all SnackBar notification durations to 1.5 seconds.

### 🏪 Stora Owner (`v1.2.1`)
- **Store Payment & QR Code Setup:** Created `StorePaymentScreen` accessible from Profile and Store Location settings. Owners can configure their GCash/Maya number, account name, and upload/preview/change their payment QR code from camera or gallery.
- **Unified Alerts & Stock Status Screen:** 
  - Tapping **"Low stock"** or **"In stock"** on the Home dashboard switches directly to the Alerts tab (no duplicate route stacked on top of the shell).
  - Added filter tabs: **Low Stock**, **In Stock**, and **All Items**. In-stock healthy inventory items can now be viewed, reviewed, and edited right alongside stock alerts.
- **Instant Product Add & Edit (0ms UI Lag):** Implemented optimistic state updates in `InventoryStore`. In-memory products and local SQLite database update instantly, dismissing modals with 0ms lag while background synchronization safely syncs changes to the server.
- **Snappy 1.5s SnackBars:** Standardized all feedback guides to 1.5 seconds (including store online/offline toggle, GPS locking, and product saved notifications).

---

## 🗄️ Backend & Admin Portal (`stora_backend`)

### 💳 Store Payment Fields & APIs
- Added `payment_phone_number`, `payment_account_name`, and `payment_qr_code` (ImageField) to `StoreLocation`.
- Serializers and endpoints (`/stores/my-location/` and `/stores/`) support multipart uploads and deliver absolute URLs (`payment_qr_url`).

### 🛡️ Account Deletion & Crucial Sales Data Protection
- **ProtectedError Fix:** Resolved foreign-key constraint crash during account deletion by ensuring products and categories are atomically cleaned up before user deletion.
- **Soft Deactivation Admin Actions:** Added `deactivate_users_and_close_stores` and `activate_users_and_open_stores` to Django Admin to safely hide closed stores (`is_open=False`, `is_visible=False`) while fully preserving historical sales and revenue records.
- **Synchronized Status:** Automated synchronization between user active status and store visibility.

### 🎨 Django Admin UI Polish
- **Password Visibility Toggle:** Added interactive show/hide password eye icon with SVG assets on the admin login page (`/admin/login/`).
- **Clean Changelist Search:** Eliminated redundant outside search icon on the changelist toolbar.
