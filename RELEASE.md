# Stora Release v1.2.0

**Release Tag:** `v1.2.0`  
**Date:** September 29, 2026  
**Artifacts:** 
- `Stora-Customer.apk` (56.0 MB)
- `Stora-Owner.apk` / `Stora.apk` (80.7 MB)

---

## 🚀 Overview

Release `v1.2.0` delivers comprehensive UI fluidity and performance optimizations, tactile haptic feedback, smart lifecycle battery and data saving, customer shopping enhancements, store owner inventory power tools, and Django admin portal data export capabilities.

---

## 📱 Mobile Applications

### 🛍️ Stora Customer (`v1.2.0`)
- **60–120 FPS Fluidity & Navigation:** Removed GPU-intensive 24px backdrop blur filters and implemented in-memory screen instance caching (`late final List<Widget> _screens`) for instant, zero-delay tab switching.
- **Accidental Deletion Recovery:** Added floating SnackBar with a 1-tap **"Undo"** action that restores removed cart items and their previous quantities with micro-haptic feedback.
- **Direct Cart Access:** Added an explicit **"View Cart"** button on the product details sheet showing the live cart item count.
- **Battery & Network Saver:** Integrated `WidgetsBindingObserver` in chat to automatically pause the 4-second polling timer when the app is minimized or backgrounded, resuming seamlessly upon return.
- **Cleaner Map Discovery:** Streamlined store map chips and markers for smoother browsing of local sari-sari stores.

### 🏪 Stora Owner (`v1.2.0`)
- **Tactile POS Keypad:** Added native `HapticFeedback` across number pad inputs, barcode scans, checkout presses, and a polished 1-tap item removal button with tooltips.
- **Interactive Stock StatCards:** Dashboard stock cards now feature ink ripple feedback and route directly to alerts and inventory management with 1 tap.
- **Live Inventory Filter Pills:** Added quick-filter pills (`All Items`, `Low Stock (<5)`, `Out of Stock`) with live counts and instant client-side filtering.
- **Order Action Haptics:** Physical confirmation vibrations for Accept, Mark Ready for Pickup, Decline, and Counter-Offer actions.
- **Chat Lifecycle Saver:** Polling automatically pauses during app inactivity, preventing background battery drain.

---

## 🗄️ Backend & Admin Portal (`stora_backend`)

### ⚡ Database & Query Optimization
- **N+1 SQL Queries Eliminated:** Resolved multiple foreign-key query cascades by adding `select_related("owner", "customer", "user")` across `OrderAdmin`, `CategoryAdmin`, `ProductAdmin`, `PaymentProofAdmin`, and `StoreLocationAdmin`.
- **Category Product Count:** Replaced iterative count queries with `Count("products")` annotation, dropping 50+ queries to **1 single query** and enabling sortable product counts.

### 📊 1-Tap CSV / Excel Data Exports
- Added UTF-8 BOM CSV export actions for:
  - **Processed Sales:** Sale ID, Receipt #, Channel, Date, Store, Buyer, Items, Qty, Total (PHP).
  - **Orders:** Order ID, Date, Store, Customer, Contact, Delivery Address, Items, Total (PHP), Status.
  - **Customer Debt / Utang:** Credit ID, Created Date, Due Date, Store, Customer, Contact, Total Utang, Paid, Balance, Status.
  - **Inventory Products:** Product ID, Name, Store, Category, Price, Stock, Barcode, Low Stock.
  - **Payment Proofs:** Proof ID, Submitted Date, Store, Reference #, Amount, Status, Reviewed Date.

### 🛡️ Moderation & Form Stability Fixes
- **Add Order Page Crash Fix:** Resolved `ValueError` on unsaved order instances in `total_amount_display()`.
- **Payment Proof Approval Fix:** Fixed status guard bypass so approvals properly credit 31 days of premium to store owners.
- **User Block/Unblock Sync:** Bidirectionally synchronized `is_active` and `is_blocked` to allow clean unblocking.
- **Date Hierarchy:** Added drill-down navigation bars (`Year > Month > Day`) on Sales, Orders, Credits, and Payment Proofs.
- **Dashboard Revenue Metrics:** Real-time visibility into Platform Subscription Revenue and Platform Gross Merchandise Volume (GMV).
