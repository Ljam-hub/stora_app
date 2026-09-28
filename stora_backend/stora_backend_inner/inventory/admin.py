import csv
from django.contrib import admin
from django.db.models import Count
from django.http import HttpResponse
from django.utils.html import format_html

from stora_backend.admin_site import stora_admin_site

from .models import Category, LOW_STOCK_THRESHOLD, Product


class OwnerAdminMixin:
    """Mixin that auto-assigns owner on create and scopes querysets so
    each store owner only sees their own data. Superusers see everything."""

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        return qs.filter(owner=request.user)

    def save_model(self, request, obj, form, change):
        if not change and not getattr(obj, "owner_id", None):
            obj.owner = request.user
        super().save_model(request, obj, form, change)


class StockLevelFilter(admin.SimpleListFilter):
    """Mirrors the Alerts screen's "Low Stock" grouping as a filter."""

    title = "stock level"
    parameter_name = "stock_level"

    def lookups(self, request, model_admin):
        return (
            ("low", f"Low stock (< {LOW_STOCK_THRESHOLD})"),
            ("ok", "Healthy"),
        )

    def queryset(self, request, queryset):
        if self.value() == "low":
            return queryset.filter(stock__lt=LOW_STOCK_THRESHOLD)
        if self.value() == "ok":
            return queryset.filter(stock__gte=LOW_STOCK_THRESHOLD)
        return queryset


@admin.register(Category, site=stora_admin_site)
class CategoryAdmin(OwnerAdminMixin, admin.ModelAdmin):
    list_display = ("name", "owner", "is_hidden", "is_archived", "product_count")
    list_filter = ("is_hidden", "is_archived")
    search_fields = ("name", "owner__email")

    def get_queryset(self, request):
        return super().get_queryset(request).select_related("owner").annotate(products_count=Count("products"))

    def get_fields(self, request, obj=None):
        """Show the owner field only to superusers (for reassignment);
        regular store owners have it auto-assigned."""
        base = ["name", "is_hidden", "is_archived"]
        if request.user.is_superuser:
            base.insert(0, "owner")
        return base

    @admin.display(description="Products", ordering="products_count")
    def product_count(self, obj):
        return getattr(obj, "products_count", obj.products.count())


@admin.register(Product, site=stora_admin_site)
class ProductAdmin(OwnerAdminMixin, admin.ModelAdmin):
    list_display = ("name", "owner", "category", "price", "stock_display", "barcode")
    list_filter = ("category", StockLevelFilter)
    search_fields = ("name", "barcode", "owner__email")
    autocomplete_fields = ("category",)
    list_select_related = ("category", "owner")

    def get_fields(self, request, obj=None):
        """Show the owner field only to superusers."""
        base = ["name", "category", "price", "stock", "barcode", "image", "bio"]
        if request.user.is_superuser:
            base.insert(0, "owner")
        return base

    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        """Limit the category dropdown to categories owned by the current
        user so store owners can't accidentally pick another user's category."""
        if db_field.name == "category" and not request.user.is_superuser:
            kwargs["queryset"] = Category.objects.filter(owner=request.user)
        return super().formfield_for_foreignkey(db_field, request, **kwargs)

    actions = ["export_products_csv"]

    @admin.display(description="Stock", ordering="stock")
    def stock_display(self, obj):
        color = "#FF6B6B" if obj.is_low_stock else "#8E8798"
        return format_html(
            '<span style="color:{}; font-weight:700;">{}</span>', color, obj.stock
        )

    @admin.action(description="📥 Export selected products to CSV")
    def export_products_csv(self, request, queryset):
        response = HttpResponse(content_type="text/csv; charset=utf-8")
        response["Content-Disposition"] = 'attachment; filename="stora_products_export.csv"'
        response.write("\ufeff")
        writer = csv.writer(response)
        writer.writerow([
            "Product ID",
            "Product Name",
            "Store / Owner",
            "Category",
            "Price (PHP)",
            "Stock",
            "Barcode",
            "Low Stock?",
        ])
        for p in queryset.select_related("owner", "category"):
            store = p.owner.business_name or p.owner.email if p.owner else "—"
            cat = p.category.name if p.category else "Uncategorized"
            writer.writerow([
                f"#{p.id}",
                p.name,
                store,
                cat,
                f"{p.price:.2f}",
                p.stock,
                p.barcode or "",
                "Yes" if p.is_low_stock else "No",
            ])
        return response
