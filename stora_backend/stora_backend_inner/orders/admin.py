from django.contrib import admin
from django.utils.html import format_html
from stora_backend.admin_site import stora_admin_site
from .models import Order, OrderItem


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
        "owner_display",
        "customer_name",
        "created_at",
    )
    list_display_links = ("id", "products_summary")
    list_filter = ("status", "created_at", "owner")
    search_fields = (
        "id",
        "customer_name",
        "customer_phone",
        "customer_address",
        "owner__email",
        "owner__business_name",
    )
    readonly_fields = (
        "status_badge",
        "total_amount_display",
        "created_at",
        "expires_at",
    )
    fields = (
        "owner",
        "customer",
        "customer_name",
        "customer_phone",
        "customer_address",
        "notes",
        "status",
        "status_badge",
        "decline_reason",
        "counter_notes",
        "counter_price",
        "total_amount_display",
        "created_at",
        "expires_at",
    )
    inlines = [OrderItemInline]
    actions = ["accept_orders", "mark_ready_orders", "decline_orders"]

    @admin.display(description="Store / Owner")
    def owner_display(self, obj):
        return obj.owner.business_name or obj.owner.email

    @admin.display(description="User Account")
    def customer_account(self, obj):
        if obj.customer:
            return format_html(
                '<span style="color: #8bd3ca; font-weight: 600;">{}</span>',
                obj.customer.email,
            )
        return format_html('<span style="color: #888888; font-style: italic;">Guest</span>')

    @admin.display(description="Products Ordered")
    def products_summary(self, obj):
        items = list(obj.items.all())
        if not items:
            return format_html('<span style="color: #888888; font-style: italic;">No items</span>')
        parts = [
            f'<span style="font-weight: 700; color: #ffffff;">{it.product_name}</span> '
            f'<span style="color: #FF6B00; font-weight: 600;">(x{it.quantity})</span>'
            for it in items
        ]
        return format_html(", ".join(parts))

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

    @admin.display(description="Total Amount")
    def total_amount_display(self, obj):
        return f"₱{obj.total_amount():.2f}"

    def get_queryset(self, request):
        qs = super().get_queryset(request).prefetch_related("items")
        if request.user.is_superuser:
            return qs
        return qs.filter(owner=request.user)

    @admin.action(description="✓ Accept selected orders (deduct stock & create sales)")
    def accept_orders(self, request, queryset):
        accepted_count = 0
        for order in queryset:
            if order.status in (Order.STATUS_PENDING, Order.STATUS_COUNTER_OFFER):
                order.accept()
                accepted_count += 1
        self.message_user(
            request, f"Successfully accepted {accepted_count} order(s)."
        )

    @admin.action(description="📦 Mark selected orders as Ready for Pickup")
    def mark_ready_orders(self, request, queryset):
        ready_count = 0
        for order in queryset:
            if order.status == Order.STATUS_ACCEPTED:
                order.mark_as_ready()
                ready_count += 1
        self.message_user(
            request, f"Successfully marked {ready_count} order(s) as Ready for Pickup."
        )

    @admin.action(description="✗ Decline selected orders")
    def decline_orders(self, request, queryset):
        declined_count = 0
        for order in queryset:
            if order.status in (Order.STATUS_PENDING, Order.STATUS_COUNTER_OFFER):
                order.decline(reason="Declined via Admin Portal")
                declined_count += 1
        self.message_user(
            request, f"Successfully declined {declined_count} order(s)."
        )
