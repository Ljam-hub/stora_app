import csv
from django.contrib import admin
from django.http import HttpResponse
from django.utils import timezone
from django.utils.html import format_html
from django.utils.safestring import mark_safe

from stora_backend.admin_site import stora_admin_site

from .models import Sale, SaleItem, CustomerCredit, CreditItem, CreditPayment


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
    actions = ["recalculate_selected_sales", "export_sales_csv"]

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

        badge = mark_safe("")
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

        account_sub = mark_safe("")
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
        if not obj.owner:
            return format_html('<span style="color: #888888; font-style: italic;">\u2014</span>')
        name = getattr(obj.owner, "business_name", None) or getattr(obj.owner, "email", None) or getattr(obj.owner, "username", "\u2014")
        return format_html(
            '<span style="font-weight: 600; color: #f5f8f8;">{}</span>',
            name,
        )

    @admin.display(description="Total", ordering="total")
    def total_display(self, obj):
        val = f"\u20b1{obj.total:.2f}" if obj.total is not None else "\u20b10.00"
        return format_html(
            '<span style="font-family: var(--stora-font-mono); font-weight: 700; color: #4ade80;">{}</span>',
            val,
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
            format_html(
                '<span style="font-weight: 700; color: #ffffff;">{}</span> <span style="color: #FF6B00; font-weight: 600;">(x{})</span>',
                it.product_name,
                it.quantity,
            )
            for it in items
        ]
        return mark_safe(", ".join(parts))

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

    @admin.action(description="📥 Export selected sales to CSV")
    def export_sales_csv(self, request, queryset):
        response = HttpResponse(content_type="text/csv; charset=utf-8")
        response["Content-Disposition"] = 'attachment; filename="stora_sales_export.csv"'
        response.write("\ufeff")
        writer = csv.writer(response)
        writer.writerow([
            "Sale ID",
            "Receipt Number",
            "Channel",
            "Date",
            "Store / Owner",
            "Customer / Buyer",
            "Products Sold",
            "Total Quantity",
            "Total Amount (PHP)",
        ])
        for sale in queryset.select_related("owner", "order", "order__customer").prefetch_related("items"):
            items = list(sale.items.all())
            summary = "; ".join(f"{it.product_name} (x{it.quantity} @ ₱{it.unit_price})" for it in items)
            total_qty = sum(it.quantity for it in items)
            store = (sale.owner.business_name or sale.owner.email) if sale.owner else "—"
            c_name = (sale.customer_name or "").strip()
            if not c_name and sale.order:
                c_name = (sale.order.customer_name or "").strip()
                if not c_name and sale.order.customer:
                    c_name = sale.order.customer.email
            if not c_name:
                c_name = "Walk-in Customer" if sale.channel == "pos" else "Online Buyer"
            receipt = sale.receipt_number or f"POS-{sale.pk}"
            writer.writerow([
                f"#{sale.id}",
                receipt,
                sale.get_channel_display() if hasattr(sale, "get_channel_display") else sale.channel,
                sale.created_at.strftime("%Y-%m-%d %H:%M"),
                store,
                c_name,
                summary,
                total_qty,
                f"{(sale.total or 0):.2f}",
            ])
        return response

    def save_related(self, request, form, formsets, change):
        # Recompute the snapshot total from the (possibly just-edited)
        # line items, same as the app does right after checkout.
        super().save_related(request, form, formsets, change)
        form.instance.recalculate_total()


class CreditItemInline(admin.TabularInline):
    model = CreditItem
    extra = 0
    fields = ("product", "product_name", "quantity", "unit_price", "subtotal_display")
    readonly_fields = ("subtotal_display",)
    autocomplete_fields = ("product",)

    @admin.display(description="Subtotal")
    def subtotal_display(self, obj):
        return f"\u20b1{obj.subtotal:.2f}" if obj.pk else "\u2014"


class CreditPaymentInline(admin.TabularInline):
    model = CreditPayment
    extra = 0
    fields = ("amount", "payment_method", "notes", "paid_at")


@admin.register(CustomerCredit, site=stora_admin_site)
class CustomerCreditAdmin(admin.ModelAdmin):
    list_display = (
        "id_display",
        "customer_display",
        "phone_display",
        "total_display",
        "paid_display",
        "balance_display",
        "status_badge",
        "due_date_display",
        "owner_display",
        "created_at",
    )
    list_display_links = ("id_display", "customer_display")
    search_fields = (
        "id",
        "customer_name",
        "customer_phone",
        "notes",
        "owner__email",
        "owner__business_name",
        "items__product_name",
    )
    list_filter = ("status", "due_date", "created_at", "owner")
    date_hierarchy = "created_at"
    readonly_fields = ("balance_display", "created_at", "updated_at")
    inlines = [CreditItemInline, CreditPaymentInline]
    actions = ["mark_selected_as_settled", "recalculate_selected_credits", "export_credits_csv"]

    def get_queryset(self, request):
        qs = (
            super()
            .get_queryset(request)
            .select_related("owner")
            .prefetch_related("items", "payments")
        )
        if request.user.is_superuser:
            return qs
        return qs.filter(owner=request.user)

    def save_model(self, request, obj, form, change):
        if not change and not getattr(obj, "owner_id", None):
            obj.owner = request.user
        super().save_model(request, obj, form, change)

    def save_related(self, request, form, formsets, change):
        super().save_related(request, form, formsets, change)
        form.instance.recalculate_totals()

    def get_fields(self, request, obj=None):
        base = []
        if request.user.is_superuser:
            base.append("owner")
        base.extend([
            "customer_name",
            "customer_phone",
            "total_amount",
            "amount_paid",
            "balance_display",
            "status",
            "due_date",
            "notes",
            "created_at",
            "updated_at",
        ])
        return base

    @admin.display(description="ID", ordering="id")
    def id_display(self, obj):
        return format_html(
            '<span style="font-weight: 800; color: #8bd3ca; font-size: 13px;">#LOAN-{}</span>',
            obj.pk,
        )

    @admin.display(description="Customer Name", ordering="customer_name")
    def customer_display(self, obj):
        name = (obj.customer_name or "Unknown Customer").strip()
        items = list(obj.items.all())
        items_summary = ""
        if items:
            summary = ", ".join(f"{it.product_name} (x{it.quantity})" for it in items[:2])
            if len(items) > 2:
                summary += f" +{len(items)-2} more"
            items_summary = format_html(
                '<div style="font-size: 11px; color: #829396; margin-top: 2px;">{}</div>',
                summary,
            )
        return format_html(
            '<div><span style="font-weight: 700; color: #ffffff; font-size: 13px;">{}</span>{}</div>',
            name,
            items_summary,
        )

    @admin.display(description="Phone", ordering="customer_phone")
    def phone_display(self, obj):
        if not obj.customer_phone:
            return format_html('<span style="color: #64748b; font-style: italic;">\u2014</span>')
        return format_html(
            '<span style="font-family: monospace; color: #94a3b8; font-size: 12px;">{}</span>',
            obj.customer_phone,
        )

    @admin.display(description="Total Credit", ordering="total_amount")
    def total_display(self, obj):
        val = f"\u20b1{obj.total_amount:.2f}" if obj.total_amount is not None else "\u20b10.00"
        return format_html(
            '<span style="font-weight: 700; color: #f1f5f9;">{}</span>',
            val,
        )

    @admin.display(description="Paid", ordering="amount_paid")
    def paid_display(self, obj):
        val = f"\u20b1{obj.amount_paid:.2f}" if obj.amount_paid is not None else "\u20b10.00"
        return format_html(
            '<span style="font-weight: 600; color: #4ade80;">{}</span>',
            val,
        )

    @admin.display(description="Balance")
    def balance_display(self, obj):
        bal = obj.balance
        if bal <= 0:
            return format_html('<span style="font-weight: 700; color: #4ade80;">\u20b10.00</span>')
        val = f"\u20b1{bal:.2f}"
        return format_html(
            '<span style="font-weight: 700; color: #f43f5e; font-size: 13px;">{}</span>',
            val,
        )

    @admin.display(description="Status", ordering="status")
    def status_badge(self, obj):
        today = timezone.localdate()
        if obj.is_fully_paid:
            return format_html(
                '<span style="background: rgba(74, 222, 128, 0.15); color: #4ade80; border: 1px solid rgba(74, 222, 128, 0.35); padding: 3px 8px; border-radius: 6px; font-weight: 700; font-size: 11px; display: inline-flex; align-items: center; gap: 4px;">\u2713 SETTLED</span>'
            )
        if obj.due_date and obj.due_date < today:
            return format_html(
                '<span style="background: rgba(239, 68, 68, 0.18); color: #ef4444; border: 1px solid rgba(239, 68, 68, 0.4); padding: 3px 8px; border-radius: 6px; font-weight: 700; font-size: 11px; display: inline-flex; align-items: center; gap: 4px;">\u26a0 OVERDUE</span>'
            )
        if obj.due_date and (obj.due_date - today).days <= 3:
            days = (obj.due_date - today).days
            label = "DUE TODAY" if days == 0 else f"DUE IN {days}D"
            return format_html(
                '<span style="background: rgba(245, 158, 11, 0.18); color: #f59e0b; border: 1px solid rgba(245, 158, 11, 0.4); padding: 3px 8px; border-radius: 6px; font-weight: 700; font-size: 11px; display: inline-flex; align-items: center; gap: 4px;">\u23f0 {}</span>',
                label,
            )
        return format_html(
            '<span style="background: rgba(56, 189, 248, 0.15); color: #38bdf8; border: 1px solid rgba(56, 189, 248, 0.35); padding: 3px 8px; border-radius: 6px; font-weight: 700; font-size: 11px; display: inline-flex; align-items: center; gap: 4px;">\u2022 ACTIVE</span>'
        )

    @admin.display(description="Due Date", ordering="due_date")
    def due_date_display(self, obj):
        if not obj.due_date:
            return format_html('<span style="color: #64748b; font-style: italic;">No deadline</span>')
        today = timezone.localdate()
        diff = (obj.due_date - today).days
        if diff < 0:
            sub = f"{abs(diff)} day{'s' if abs(diff) != 1 else ''} late"
            color = "#ef4444"
        elif diff == 0:
            sub = "Due today"
            color = "#f59e0b"
        else:
            sub = f"In {diff} day{'s' if diff != 1 else ''}"
            color = "#829396"

        return format_html(
            '<div>'
            '<span style="font-weight: 600; color: #f1f5f9;">{}</span>'
            '<div style="font-size: 11px; color: {}; font-weight: 500;">{}</div>'
            '</div>',
            obj.due_date.strftime("%b %d, %Y"),
            color,
            sub,
        )

    @admin.display(description="Store / Owner", ordering="owner__business_name")
    def owner_display(self, obj):
        if not obj.owner:
            return format_html('<span style="color: #888888; font-style: italic;">\u2014</span>')
        name = getattr(obj.owner, "business_name", None) or getattr(obj.owner, "email", None) or getattr(obj.owner, "username", "\u2014")
        return format_html(
            '<span style="font-weight: 600; color: #f5f8f8;">{}</span>',
            name,
        )

    @admin.action(description="\u2713 Mark selected loans as settled")
    def mark_selected_as_settled(self, request, queryset):
        count = 0
        for credit in queryset:
            remaining = credit.balance
            if remaining > 0:
                CreditPayment.objects.create(
                    credit=credit,
                    amount=remaining,
                    payment_method="admin_adjustment",
                    notes="Settled via Admin Action",
                )
            credit.status = CustomerCredit.STATUS_SETTLED
            credit.save(update_fields=["status"])
            count += 1
        self.message_user(request, f"Marked {count} loan(s) as settled.")

    @admin.action(description="\u21bb Recalculate selected loan balances")
    def recalculate_selected_credits(self, request, queryset):
        for credit in queryset:
            credit.recalculate_totals()
        self.message_user(request, f"Recalculated {queryset.count()} loan record(s).")

    @admin.action(description="📥 Export selected loans to CSV")
    def export_credits_csv(self, request, queryset):
        response = HttpResponse(content_type="text/csv; charset=utf-8")
        response["Content-Disposition"] = 'attachment; filename="stora_utang_credits_export.csv"'
        response.write("\ufeff")
        writer = csv.writer(response)
        writer.writerow([
            "Credit ID",
            "Created Date",
            "Due Date",
            "Store / Owner",
            "Customer Name",
            "Contact Phone",
            "Total Utang (PHP)",
            "Amount Paid (PHP)",
            "Remaining Balance (PHP)",
            "Status",
            "Notes",
        ])
        for credit in queryset.select_related("owner"):
            store = (credit.owner.business_name or credit.owner.email) if credit.owner else "—"
            due = credit.due_date.strftime("%Y-%m-%d") if credit.due_date else "No deadline"
            writer.writerow([
                f"#{credit.id}",
                credit.created_at.strftime("%Y-%m-%d %H:%M"),
                due,
                store,
                credit.customer_name,
                credit.customer_phone or "",
                f"{(credit.total_amount or 0):.2f}",
                f"{(credit.amount_paid or 0):.2f}",
                f"{(credit.balance or 0):.2f}",
                credit.get_status_display(),
                credit.notes or "",
            ])
        return response

