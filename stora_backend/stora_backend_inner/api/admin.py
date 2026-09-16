from django.contrib import admin
from django.shortcuts import get_object_or_404, redirect
from django.urls import path, reverse
from django.utils import timezone
from django.utils.html import format_html
from stora_backend.admin_site import stora_admin_site
from .models import ChatMessage, BlockedCustomer, UserReport


@admin.register(ChatMessage, site=stora_admin_site)
class ChatMessageAdmin(admin.ModelAdmin):
    list_display = ("id", "sender", "recipient", "order_link", "message_preview", "has_image", "is_read", "created_at")
    list_filter = ("is_read", "created_at")
    search_fields = ("sender__email", "recipient__email", "message")
    readonly_fields = ("created_at",)

    @admin.display(description="Order")
    def order_link(self, obj):
        if obj.order_id:
            return f"Order #{obj.order_id}"
        return "—"

    @admin.display(description="Message Preview")
    def message_preview(self, obj):
        if obj.message:
            return obj.message[:60] + ("..." if len(obj.message) > 60 else "")
        return "—"

    @admin.display(description="Photo?", boolean=True)
    def has_image(self, obj):
        return bool(obj.image)


@admin.register(BlockedCustomer, site=stora_admin_site)
class BlockedCustomerAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "block_scope_badge",
        "owner_display",
        "customer_display",
        "user_account_status",
        "created_at",
        "manage_actions",
    )
    list_display_links = ("id", "block_scope_badge", "owner_display", "customer_display")
    list_filter = ("created_at",)
    actions = ["unblock_selected_blocked_users"]
    search_fields = (
        "owner__email",
        "owner__business_name",
        "customer__email",
        "customer__first_name",
        "customer__last_name",
        "customer__username",
    )

    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path("<int:block_id>/unblock/", self.admin_site.admin_view(self.unblock_single_view), name="api_blockedcustomer_unblock"),
        ]
        return custom_urls + urls

    def unblock_single_view(self, request, block_id):
        obj = get_object_or_404(BlockedCustomer, pk=block_id)
        target = obj.customer or obj.owner
        name = ""
        if target:
            name = target.business_name or target.get_full_name() or target.username
            target.unblock_user()
        else:
            obj.delete()
        self.message_user(request, f"Successfully unblocked {name or 'user'} and restored account access.")
        return redirect(reverse("stora_admin:api_blockedcustomer_changelist"))

    @admin.action(description="🔓 Unblock selected user(s) & restore app access")
    def unblock_selected_blocked_users(self, request, queryset):
        count = 0
        for obj in queryset:
            target = obj.customer or obj.owner
            if target:
                target.unblock_user()
            else:
                obj.delete()
            count += 1
        self.message_user(request, f"Successfully unblocked {count} user(s) and restored account access.")

    def delete_model(self, request, obj):
        target = obj.customer or obj.owner
        if target:
            target.unblock_user()
        super().delete_model(request, obj)

    def delete_queryset(self, request, queryset):
        for obj in queryset:
            target = obj.customer or obj.owner
            if target:
                target.unblock_user()
        super().delete_queryset(request, queryset)

    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        from accounts.models import User
        if db_field.name == "owner":
            kwargs["queryset"] = User.objects.filter(role=User.ROLE_OWNER).order_by("business_name", "email")
            formfield = super().formfield_for_foreignkey(db_field, request, **kwargs)
            if formfield:
                formfield.label_from_instance = lambda obj: f"🏪 {obj.business_name or obj.get_full_name() or obj.username} ({obj.email})"
                formfield.empty_label = "— None (Global Block / Not store specific) —"
            return formfield
        elif db_field.name == "customer":
            kwargs["queryset"] = User.objects.filter(role=User.ROLE_CUSTOMER).order_by("first_name", "email")
            formfield = super().formfield_for_foreignkey(db_field, request, **kwargs)
            if formfield:
                formfield.label_from_instance = lambda obj: f"👤 {obj.get_full_name() or obj.username} ({obj.email})"
                formfield.empty_label = "— None (Global Store Owner Block) —"
            return formfield
        return super().formfield_for_foreignkey(db_field, request, **kwargs)

    @admin.display(description="Block Scope")
    def block_scope_badge(self, obj):
        if obj.owner and obj.customer:
            return format_html(
                '<span style="background: rgba(251, 191, 36, 0.16); color: #fbbf24; border: 1px solid rgba(251, 191, 36, 0.4); padding: 3px 8px; border-radius: 6px; font-size: 11px; font-weight: 700;">🏪 Store Level</span>'
            )
        elif obj.customer:
            return format_html(
                '<span style="background: rgba(239, 68, 68, 0.16); color: #f87171; border: 1px solid rgba(239, 68, 68, 0.4); padding: 3px 8px; border-radius: 6px; font-size: 11px; font-weight: 700;">🚫 Customer Global</span>'
            )
        elif obj.owner:
            return format_html(
                '<span style="background: rgba(239, 68, 68, 0.16); color: #f87171; border: 1px solid rgba(239, 68, 68, 0.4); padding: 3px 8px; border-radius: 6px; font-size: 11px; font-weight: 700;">🚫 Owner Global</span>'
            )
        return "—"

    @admin.display(description="Store Owner")
    def owner_display(self, obj):
        if obj.owner:
            name = obj.owner.business_name or obj.owner.get_full_name() or obj.owner.username
            return format_html(
                '<span style="color: #8bd3ca; font-weight: 700;">🏪 {}</span> <span style="color: #8bd3ca; font-size: 11px;">({})</span>',
                name,
                obj.owner.email,
            )
        return format_html('<span style="color: #9ca3af; font-style: italic;">All Stores (Global)</span>')

    @admin.display(description="Customer")
    def customer_display(self, obj):
        if obj.customer:
            name = obj.customer.get_full_name() or obj.customer.username
            return format_html(
                '<span style="color: #8bd3ca; font-weight: 700;">👤 {}</span> <span style="color: #8bd3ca; font-size: 11px;">({})</span>',
                name,
                obj.customer.email,
            )
        return format_html('<span style="color: #9ca3af; font-style: italic;">Owner Blocked Directly</span>')

    @admin.display(description="Account Access")
    def user_account_status(self, obj):
        target = obj.customer if obj.customer else obj.owner
        if not target:
            return "—"
        if getattr(target, "is_blocked", False) or not target.is_active:
            return format_html(
                '<span style="background: rgba(239, 68, 68, 0.2); color: #f87171; padding: 2px 7px; border-radius: 4px; font-weight: bold; font-size: 11px;">🚫 BLOCKED</span>'
            )
        return format_html(
            '<span style="background: rgba(16, 185, 129, 0.2); color: #34d399; padding: 2px 7px; border-radius: 4px; font-weight: bold; font-size: 11px;">Active In-App</span>'
        )

    @admin.display(description="Actions")
    def manage_actions(self, obj):
        edit_block_url = reverse("stora_admin:api_blockedcustomer_change", args=[obj.id])
        target_user = obj.customer or obj.owner
        user_url = reverse("stora_admin:accounts_user_change", args=[target_user.id]) if target_user else None
        unblock_url = reverse("stora_admin:api_blockedcustomer_unblock", args=[obj.id])
        user_btn = (
            format_html(
                '<a href="{}" style="display: inline-flex; align-items: center; gap: 4px; padding: 3px 8px; border-radius: 6px; font-size: 11px; font-weight: 700; color: #8bd3ca; background: rgba(139, 211, 202, 0.12); border: 1px solid rgba(139, 211, 202, 0.35); text-decoration: none; margin-left: 6px;" title="Manage user profile">👤 User Account &rarr;</a>',
                user_url,
            )
            if user_url
            else ""
        )
        unblock_btn = format_html(
            '<a href="{}" style="display: inline-flex; align-items: center; gap: 4px; padding: 3px 8px; border-radius: 6px; font-size: 11px; font-weight: 700; color: #34d399; background: rgba(16, 185, 129, 0.15); border: 1px solid rgba(16, 185, 129, 0.45); text-decoration: none; margin-left: 6px;" onclick="return confirm(\'Are you sure you want to unblock this user and restore their account access?\');" title="Unblock user and restore account">🔓 Unblock</a>',
            unblock_url,
        )
        return format_html(
            '<div style="display: inline-flex; align-items: center;">'
            '<a href="{}" style="display: inline-flex; align-items: center; gap: 4px; padding: 3px 8px; border-radius: 6px; font-size: 11px; font-weight: 700; color: #fbbf24; background: rgba(251, 191, 36, 0.12); border: 1px solid rgba(251, 191, 36, 0.35); text-decoration: none;" title="Edit block settings">⚙️ Edit Block</a>'
            '{}'
            '{}'
            '</div>',
            edit_block_url,
            user_btn,
            unblock_btn,
        )

    def save_model(self, request, obj, form, change):
        super().save_model(request, obj, form, change)
        target = obj.customer if obj.customer and not obj.owner else (obj.owner if obj.owner and not obj.customer else None)
        if target:
            target.block_user(reason="Blocked by administrator via Blocked Users registry")


@admin.register(UserReport, site=stora_admin_site)
class UserReportAdmin(admin.ModelAdmin):
    list_select_related = ("reporter", "reported_user")
    list_display = (
        "id",
        "reporter_display",
        "reported_user_display",
        "reason",
        "status_badge",
        "order_link",
        "has_attachment",
        "created_at",
    )
    list_display_links = ("id", "reporter_display", "reported_user_display", "reason")
    list_filter = ("status", "reason", "created_at")
    search_fields = (
        "reporter__email",
        "reporter__business_name",
        "reported_user__email",
        "reported_user__business_name",
        "description",
        "admin_notes",
    )
    readonly_fields = ("created_at", "updated_at", "attachment_preview")
    actions = [
        "block_reported_users",
        "unblock_reported_users",
        "dismiss_reports",
        "mark_as_reviewed",
    ]

    @admin.display(description="Reporter")
    def reporter_display(self, obj):
        u = obj.reporter
        name = u.business_name if u.role == "owner" and u.business_name else f"{u.first_name} {u.last_name}".strip() or u.username
        role_color = "#FF6B00" if u.role == "owner" else "#00875A"
        role_label = "Store Owner" if u.role == "owner" else "Customer"
        return format_html(
            '<span style="color: #8bd3ca; font-weight: 700;">{}</span> <span style="font-size: 11px; background: {}; color: #fff; padding: 2px 6px; border-radius: 4px; margin-left: 4px;">{}</span>',
            name,
            role_color,
            role_label,
        )

    @admin.display(description="Reported User")
    def reported_user_display(self, obj):
        u = obj.reported_user
        name = u.business_name if u.role == "owner" and u.business_name else f"{u.first_name} {u.last_name}".strip() or u.username
        role_color = "#FF6B00" if u.role == "owner" else "#00875A"
        role_label = "Store Owner" if u.role == "owner" else "Customer"
        active_badge = "" if u.is_active else ' <span style="font-size: 11px; background: #EF4444; color: #fff; padding: 2px 6px; border-radius: 4px; font-weight: bold;">🚫 BLOCKED</span>'
        return format_html(
            '<span style="color: #8bd3ca; font-weight: 700;">{}</span> <span style="font-size: 11px; background: {}; color: #fff; padding: 2px 6px; border-radius: 4px; margin-left: 4px;">{}</span>{}',
            name,
            role_color,
            role_label,
            format_html(active_badge),
        )

    @admin.display(description="Status")
    def status_badge(self, obj):
        colors = {
            UserReport.STATUS_PENDING: ("#F59E0B", "#332408", "Pending Review"),
            UserReport.STATUS_REVIEWED: ("#38BDF8", "#102A3D", "Under Review"),
            UserReport.STATUS_ACTION_TAKEN: ("#EF4444", "#3A1620", "User Blocked"),
            UserReport.STATUS_DISMISSED: ("#9CA3AF", "#1F1A28", "Dismissed"),
        }
        fg, bg, label = colors.get(obj.status, ("#9CA3AF", "#1F1A28", obj.status))
        return format_html(
            '<span style="display: inline-block; padding: 3px 8px; border-radius: 12px; font-size: 11px; font-weight: bold; background: {}; color: {}; border: 1px solid {};">{}</span>',
            bg,
            fg,
            fg,
            label,
        )

    @admin.display(description="Order")
    def order_link(self, obj):
        if obj.order_id:
            return f"Order #{obj.order_id}"
        return "—"

    @admin.display(description="Evidence?", boolean=True)
    def has_attachment(self, obj):
        return bool(obj.attachment)

    @admin.display(description="Attachment Preview")
    def attachment_preview(self, obj):
        if obj.attachment:
            return format_html(
                '<a href="{}" target="_blank"><img src="{}" style="max-height: 200px; border-radius: 8px; border: 1px solid #332A40;" /></a>',
                obj.attachment.url,
                obj.attachment.url,
            )
        return "No photo attached"

    @admin.action(description="🚫 Block / Suspend Reported User(s)")
    def block_reported_users(self, request, queryset):
        count = 0
        skipped = 0
        now = timezone.now()
        now_str = now.strftime("%Y-%m-%d %H:%M:%S UTC")
        for report in queryset:
            reported_user = report.reported_user
            if reported_user == request.user or reported_user.is_staff or reported_user.is_superuser or getattr(reported_user, "role", None) == "admin":
                skipped += 1
                continue
            reported_user.block_user(reason=f"Suspended due to report #{report.id}: {report.get_reason_display()}")
            count += 1
            report.status = UserReport.STATUS_ACTION_TAKEN
            report.admin_notes += f"\nBlocked by admin {request.user.username} on {now_str}."
            report.updated_at = now
            report.save(update_fields=["status", "admin_notes", "updated_at"])

        msg = f"Successfully blocked {count} user(s) and marked reports as Action Taken."
        if skipped:
            msg += f" (Skipped {skipped} administrative user(s) to protect system access.)"
        self.message_user(request, msg)

    @admin.action(description="✅ Unblock / Reactivate Reported User(s)")
    def unblock_reported_users(self, request, queryset):
        count = 0
        now = timezone.now()
        now_str = now.strftime("%Y-%m-%d %H:%M:%S UTC")
        for report in queryset:
            reported_user = report.reported_user
            reported_user.unblock_user()
            count += 1
            report.status = UserReport.STATUS_REVIEWED
            report.admin_notes += f"\nUnblocked by admin {request.user.username} on {now_str}."
            report.updated_at = now
            report.save(update_fields=["status", "admin_notes", "updated_at"])
        self.message_user(request, f"Successfully unblocked {count} user(s).")

    @admin.action(description="❌ Dismiss Selected Report(s)")
    def dismiss_reports(self, request, queryset):
        updated = queryset.update(status=UserReport.STATUS_DISMISSED, updated_at=timezone.now())
        self.message_user(request, f"Marked {updated} report(s) as Dismissed.")

    @admin.action(description="🔍 Mark as Reviewed / Investigating")
    def mark_as_reviewed(self, request, queryset):
        updated = queryset.update(status=UserReport.STATUS_REVIEWED, updated_at=timezone.now())
        self.message_user(request, f"Marked {updated} report(s) as Under Review.")

