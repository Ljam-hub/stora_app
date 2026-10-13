import csv
from django.contrib import admin
from django.http import HttpResponse
from django.utils.html import format_html
from django.utils.safestring import mark_safe
from stora_backend.admin_site import stora_admin_site
from .models import Order, OrderItem


def mask_phone(phone):
    """Mask phone number for privacy protection in control panel."""
    if not phone:
        return "—"
    phone_str = str(phone).strip()
    if len(phone_str) <= 4:
        return "****"
    return phone_str[:2] + ("*" * max(1, len(phone_str) - 6)) + phone_str[-4:]


def mask_person_name(name):
    """Mask name for privacy protection in control panel."""
    if not name:
        return "—"
    name = name.strip()
    parts = name.split()
    masked_parts = []
    for part in parts:
        if len(part) <= 2:
            masked_parts.append(part[0] + "*")
        else:
            masked_parts.append(part[0] + ("*" * (len(part) - 2)) + part[-1])
    return " ".join(masked_parts)


def mask_address(addr):
    """Mask specific street/house numbers to protect residential privacy."""
    if not addr:
        return "—"
    addr_str = str(addr).strip()
    if len(addr_str) <= 8:
        return "****"
    parts = [p.strip() for p in addr_str.split(",") if p.strip()]
    if len(parts) > 1:
        return f"****, {', '.join(parts[1:])}"
    return addr_str[:3] + ("*" * max(4, len(addr_str) - 6)) + addr_str[-3:]


class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0
    fields = ("product", "product_name", "quantity", "unit_price", "subtotal_display")
    readonly_fields = ("subtotal_display",)
    autocomplete_fields = ("product",)

    @admin.display(description="Subtotal")
    def subtotal_display(self, obj):
        return f"₱{obj.subtotal:.2f}" if obj.pk else "—"


@admin.register(Order, site=stora_admin_site)
class OrderAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "products_summary",
        "items_count",
        "total_amount_display",
        "status_badge",
        "payment_badge",
        "owner_display",
        "customer_display",
        "customer_phone_display",
        "created_at",
    )
    list_display_links = ("id", "products_summary")
    list_filter = ("status", "payment_method", "created_at", "owner")
    date_hierarchy = "created_at"
    search_fields = (
        "id",
        "customer_name",
        "owner__email",
        "owner__business_name",
    )
    readonly_fields = (
        "status_badge",
        "payment_badge",
        "total_amount_display",
        "customer_phone_protected",
        "customer_address_protected",
        "created_at",
        "expires_at",
    )
    inlines = [OrderItemInline]
    actions = ["export_orders_csv"]

    @admin.display(description="Store / Owner")
    def owner_display(self, obj):
        if not obj.owner:
            return format_html('<span style="color: #888888; font-style: italic;">\u2014</span>')
        return obj.owner.business_name or obj.owner.email

    @admin.display(description="Customer (Protected)", ordering="customer_name")
    def customer_display(self, obj):
        raw = obj.customer_name or (obj.customer.get_full_name() if obj.customer else "") or "Guest"
        return mask_person_name(raw)

    @admin.display(description="Customer Phone (Protected)")
    def customer_phone_display(self, obj):
        if obj.customer_phone:
            return format_html(
                '<span style="color: #94a3b8; font-family: monospace; font-size: 12px;">{}</span>',
                mask_phone(obj.customer_phone),
            )
        return format_html('<span style="color: #888888; font-style: italic;">—</span>')

    @admin.display(description="Phone Number (Protected)")
    def customer_phone_protected(self, obj):
        return mask_phone(obj.customer_phone)

    @admin.display(description="Delivery Address (Protected)")
    def customer_address_protected(self, obj):
        return mask_address(obj.customer_address)

    @admin.display(description="Products Ordered")
    def products_summary(self, obj):
        items = list(obj.items.all())
        if not items:
            return format_html('<span style="color: #888888; font-style: italic;">No items</span>')
        parts = [
            format_html(
                '<span style="font-weight: 700; color: #ffffff;">{}</span> '
                '<span style="color: #FF6B00; font-weight: 600;">(x{})</span>',
                it.product_name,
                it.quantity,
            )
            for it in items
        ]
        return mark_safe(", ".join(parts))

    @admin.display(description="Total Qty")
    def items_count(self, obj):
        items = list(obj.items.all())
        total_qty = sum(it.quantity for it in items)
        distinct_types = len(items)
        if distinct_types > 1 and total_qty != distinct_types:
            return f"{total_qty} items ({distinct_types} products)"
        return f"{total_qty} item{'s' if total_qty != 1 else ''}"

    @admin.display(description="Status")
    def status_badge(self, obj):
        colors = {
            Order.STATUS_PENDING: ("#8bd3ca", "#1a3435", "Pending"),
            Order.STATUS_ACCEPTED: ("#4ade80", "#132d1b", "Accepted"),
            Order.STATUS_READY: ("#38bdf8", "#0c2d48", "Ready for Pickup"),
            Order.STATUS_DECLINED: ("#f87171", "#3a1620", "Declined"),
            Order.STATUS_AUTO_DECLINED: ("#aab8bb", "#262d30", "Auto-Declined"),
            Order.STATUS_COUNTER_OFFER: ("#fbbf24", "#332408", "Counter-Offer"),
        }
        text_color, bg_color, label = colors.get(
            obj.status, ("#f5f8f8", "#262d30", obj.status)
        )
        return format_html(
            '<span style="background-color: {}; color: {}; padding: 4px 10px; '
            'border-radius: 6px; font-weight: 700; font-size: 11px;">{}</span>',
            bg_color,
            text_color,
            label,
        )

    @admin.display(description="Payment Method")
    def payment_badge(self, obj):
        if obj.payment_method == Order.PAYMENT_METHOD_GCASH:
            return format_html(
                '<span style="background-color: #1e3a8a; color: #93c5fd; padding: 4px 8px; '
                'border-radius: 6px; font-weight: 700; font-size: 11px;">📱 GCash</span>'
            )
        return format_html(
            '<span style="background-color: #064e3b; color: #6ee7b7; padding: 4px 8px; '
            'border-radius: 6px; font-weight: 700; font-size: 11px;">💵 Cash on Pickup</span>'
        )

    @admin.display(description="Total Amount")
    def total_amount_display(self, obj):
        if not obj.pk:
            return "—"
        if (
            obj.status in (Order.STATUS_ACCEPTED, Order.STATUS_READY, Order.STATUS_COUNTER_OFFER)
            and obj.counter_price is not None
            and obj.counter_price > 0
        ):
            val = f"\u20b1{obj.counter_price:.2f}"
            return format_html(
                '<span style="font-family: var(--stora-font-mono); font-weight: 700; color: #fbbf24;">{}</span> '
                '<span style="font-size: 10px; color: #fbbf24; font-weight: 700; background: rgba(251, 191, 36, 0.15); padding: 2px 5px; border-radius: 4px;">COUNTER</span>',
                val,
            )
        val = f"\u20b1{obj.total_amount():.2f}"
        return format_html(
            '<span style="font-family: var(--stora-font-mono); font-weight: 700; color: #4ade80;">{}</span>',
            val,
        )

    def get_queryset(self, request):
        qs = super().get_queryset(request).select_related("owner", "customer").prefetch_related("items")
        if request.user.is_superuser:
            return qs
        return qs.filter(owner=request.user)

    def get_fields(self, request, obj=None):
        """Show the owner field only to superusers, keep customer contact info protected."""
        base = [
            "customer_display",
            "customer_phone_protected",
            "customer_address_protected",
            "notes",
            "payment_method",
            "payment_badge",
            "status",
            "status_badge",
            "decline_reason",
            "counter_notes",
            "counter_price",
            "total_amount_display",
            "created_at",
            "expires_at",
        ]
        if request.user.is_superuser:
            base.insert(0, "owner")
        return base

    @admin.action(description="📥 Export selected orders to CSV (Sanitized)")
    def export_orders_csv(self, request, queryset):
        response = HttpResponse(content_type="text/csv; charset=utf-8")
        response["Content-Disposition"] = 'attachment; filename="stora_orders_export.csv"'
        response.write("\ufeff")
        writer = csv.writer(response)
        writer.writerow([
            "Order ID",
            "Created Date",
            "Store / Owner",
            "Customer (Protected)",
            "Contact Phone (Protected)",
            "Delivery Area (Protected)",
            "Items Summary",
            "Total Quantity",
            "Total Amount (PHP)",
            "Payment Method",
            "Status",
            "Notes",
        ])
        for order in queryset.select_related("owner", "customer").prefetch_related("items"):
            items = list(order.items.all())
            summary = "; ".join(f"{it.product_name} (x{it.quantity} @ ₱{it.unit_price})" for it in items)
            total_qty = sum(it.quantity for it in items)
            amt = (
                order.counter_price
                if (order.counter_price is not None and order.status in (Order.STATUS_ACCEPTED, Order.STATUS_READY, Order.STATUS_COUNTER_OFFER))
                else order.total_amount()
            )
            store = (order.owner.business_name or order.owner.email) if order.owner else "—"
            raw_c_name = order.customer_name or (order.customer.get_full_name() if order.customer else "Guest")
            c_name = mask_person_name(raw_c_name)
            writer.writerow([
                f"#{order.id}",
                order.created_at.strftime("%Y-%m-%d %H:%M"),
                store,
                c_name,
                mask_phone(order.customer_phone),
                mask_address(order.customer_address),
                summary,
                total_qty,
                f"{amt:.2f}",
                order.get_payment_method_display(),
                order.get_status_display(),
                order.notes or "",
            ])
        return response

    def accept_orders(self, request, queryset):
        from api.fcm import notify_order_status_change
        accepted_count = 0
        for order in queryset:
            if order.status in (Order.STATUS_PENDING, Order.STATUS_COUNTER_OFFER):
                try:
                    order.accept()
                    notify_order_status_change(order, "accepted")
                    accepted_count += 1
                except Exception:
                    pass
        if hasattr(self, "message_user"):
            self.message_user(request, f"Successfully accepted {accepted_count} order(s).")

    def mark_ready_orders(self, request, queryset):
        from api.fcm import notify_order_status_change
        ready_count = 0
        for order in queryset:
            if order.status == Order.STATUS_ACCEPTED:
                order.mark_as_ready()
                notify_order_status_change(order, "ready")
                ready_count += 1
        if hasattr(self, "message_user"):
            self.message_user(request, f"Successfully marked {ready_count} order(s) as Ready for Pickup.")

    def decline_orders(self, request, queryset):
        from api.fcm import notify_order_status_change
        declined_count = 0
        for order in queryset:
            if order.status in (Order.STATUS_PENDING, Order.STATUS_COUNTER_OFFER):
                order.decline(reason="Declined via Admin Portal")
                notify_order_status_change(order, "declined", extra_msg="Declined via Admin Portal")
                declined_count += 1
        if hasattr(self, "message_user"):
            self.message_user(request, f"Successfully declined {declined_count} order(s).")


