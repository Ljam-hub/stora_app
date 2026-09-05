from django.contrib import admin

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
    list_display = ("id", "owner", "created_at", "item_count", "total")
    date_hierarchy = "created_at"
    readonly_fields = ("total", "created_at")
    inlines = [SaleItemInline]

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

    @admin.display(description="Items")
    def item_count(self, obj):
        return obj.items.count()

    def save_related(self, request, form, formsets, change):
        # Recompute the snapshot total from the (possibly just-edited)
        # line items, same as the app does right after checkout.
        super().save_related(request, form, formsets, change)
        form.instance.recalculate_total()
