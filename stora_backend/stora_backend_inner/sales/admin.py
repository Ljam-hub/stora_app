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
    list_display = ("id", "products_display", "total_quantity", "total", "owner", "created_at")
    list_display_links = ("id", "products_display")
    date_hierarchy = "created_at"
    readonly_fields = ("total", "created_at")
    inlines = [SaleItemInline]
    actions = ["recalculate_selected_sales"]

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        return qs.filter(owner=request.user)

    def save_model(self, request, obj, form, change):
        if not change and not getattr(obj, "owner_id", None):
            obj.owner = request.user
        super().save_model(request, obj, form, change)

    def get_fields(self, request, obj=None):
        """Show owner field only to superusers."""
        base = []
        if request.user.is_superuser:
            base.append("owner")
        base.extend(["total", "created_at"])
        return base

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
