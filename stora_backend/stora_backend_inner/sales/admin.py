from django.contrib import admin
from django.utils.html import format_html

from stora_backend.admin_site import stora_admin_site

from .models import Sale, SaleItem


class SaleItemInline(admin.TabularInline):
    model = SaleItem
    extra = 0
    fields = ("product", "product_name", "quantity", "unit_price", "subtotal_display")
    readonly_fields = ("subtotal_display",)
    autocomplete_fields = ("product",)

    @admin.display(description="Subtotal")
    def subtotal_display(self, obj):
        return f"\u20b1{obj.subtotal:.2f}" if obj.pk else "\u2014"


@admin.register(Sale, site=stora_admin_site)
class SaleAdmin(admin.ModelAdmin):
    list_display = (
        "id_display",
        "products_display",
        "customer_display",
        "total_quantity",
        "total_display",
        "owner_display",
        "created_at",
    )
    list_display_links = ("id_display", "products_display")
    search_fields = (
        "id",
        "receipt_number",
        "customer_name",
        "order__id",
        "order__customer_name",
        "owner__email",
        "owner__business_name",
        "items__product_name",
    )
    list_filter = ("channel", "created_at", "owner")
    date_hierarchy = "created_at"
    readonly_fields = ("total_display", "receipt_number", "order_link", "created_at")
    inlines = [SaleItemInline]
    actions = ["recalculate_selected_sales"]

    def get_queryset(self, request):
        qs = (
            super()
            .get_queryset(request)
            .select_related("owner", "order", "order__customer")
            .prefetch_related("items")
        )
        if request.user.is_superuser:
            return qs
        return qs.filter(owner=request.user)

    def save_model(self, request, obj, form, change):
        if not change and not getattr(obj, "owner_id", None):
            obj.owner = request.user
        super().save_model(request, obj, form, change)

    def get_fields(self, request, obj=None):
        """Show owner field only to superusers, include buyer/customer details."""
        base = []
        if request.user.is_superuser:
            base.append("owner")
        base.extend([
            "customer_name",
            "receipt_number",
            "channel",
            "order_link",
            "total_display",
            "created_at",
        ])
        return base

    @admin.display(description="ID", ordering="id")
    def id_display(self, obj):
        receipt = obj.receipt_number or f"POS-{obj.pk}"
        return format_html(
            '<div>'
            '<span style="font-weight: 800; color: #8bd3ca; font-size: 13px;">#{}</span>'
            '<div style="font-size: 10.5px; font-family: monospace; color: #829396; letter-spacing: 0.02em;">{}</div>'
            '</div>',
            obj.pk,
            receipt,
        )

    @admin.display(description="Customer / Buyer", ordering="customer_name")
    def customer_display(self, obj):
        name = (obj.customer_name or "").strip()
        if not name and obj.order:
            name = (obj.order.customer_name or "").strip()
            if not name and obj.order.customer:
                name = obj.order.customer.email

        is_walk_in = not name or name.lower() == "walk-in customer"
        if is_walk_in:
            return format_html(
                '<span style="display: inline-flex; align-items: center; gap: 6px; color: #b4c2c5; font-size: 12.5px;">'
                '<span>🏪</span> <span style="font-weight: 500;">Walk-in Customer</span>'
                '</span>'
            )

        badge = ""
        if obj.order_id or obj.channel == "online_order":
            if obj.order_id:
                badge = format_html(
                    '<a href="/admin/orders/order/{}/change/" style="font-size: 10px; font-weight: 700; padding: 2px 6px; border-radius: 4px; background: rgba(56, 189, 248, 0.15); color: #38bdf8; border: 1px solid rgba(56, 189, 248, 0.35); text-decoration: none; margin-left: 6px;">ORD #{}</a>',
                    obj.order_id,
                    obj.order_id,
                )
            else:
                badge = format_html(
                    '<span style="font-size: 10px; font-weight: 700; padding: 2px 6px; border-radius: 4px; background: rgba(56, 189, 248, 0.15); color: #38bdf8; border: 1px solid rgba(56, 189, 248, 0.35); margin-left: 6px;">ONLINE</span>'
                )

        account_sub = ""
        if obj.order and obj.order.customer:
            account_sub = format_html(
                '<div style="font-size: 11px; color: #8bd3ca; font-weight: 600; margin-top: 2px;">{}</div>',
                obj.order.customer.email,
            )

        return format_html(
            '<div>'
            '<div style="display: flex; align-items: center; gap: 4px;">'
            '<span style="font-weight: 700; color: #ffffff; font-size: 13px;">{}</span>{}'
            '</div>'
            '{}'
            '</div>',
            name,
            badge,
            account_sub,
        )

    @admin.display(description="Store / Owner", ordering="owner__business_name")
    def owner_display(self, obj):
        name = obj.owner.business_name or obj.owner.email
        return format_html(
            '<span style="font-weight: 600; color: #f5f8f8;">{}</span>',
            name,
        )

    @admin.display(description="Total", ordering="total")
    def total_display(self, obj):
        return format_html(
            '<span style="font-family: var(--stora-font-mono); font-weight: 700; color: #4ade80;">₱{:.2f}</span>',
            obj.total,
        )

    @admin.display(description="Originating Online Order")
    def order_link(self, obj):
        if not obj.order_id:
            return format_html('<span style="color: #888888; font-style: italic;">None (In-Store POS Sale)</span>')
        return format_html(
            '<a href="/admin/orders/order/{}/change/" style="color: #8bd3ca; font-weight: 700;">View Order #{} &rarr;</a>',
            obj.order_id,
            obj.order_id,
        )

    @admin.display(description="Products Sold")
    def products_display(self, obj):
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
    def total_quantity(self, obj):
        items = list(obj.items.all())
        total_qty = sum(it.quantity for it in items)
        distinct_types = len(items)
        if distinct_types > 1 and total_qty != distinct_types:
            return f"{total_qty} pcs ({distinct_types} products)"
        return f"{total_qty} pc{'s' if total_qty != 1 else ''}"

    @admin.action(description="↻ Recalculate selected sale totals")
    def recalculate_selected_sales(self, request, queryset):
        updated_count = 0
        for sale in queryset:
            sale.recalculate_total()
            updated_count += 1
        self.message_user(request, f"Recalculated totals for {updated_count} sale(s).")

    def save_related(self, request, form, formsets, change):
        # Recompute the snapshot total from the (possibly just-edited)
        # line items, same as the app does right after checkout.
        super().save_related(request, form, formsets, change)
        form.instance.recalculate_total()
