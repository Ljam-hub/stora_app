from django.contrib import admin
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
    list_display = ("id", "owner", "customer", "created_at")
    list_filter = ("created_at",)
    search_fields = ("owner__email", "owner__business_name", "customer__email")


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
            '<strong>{}</strong> <span style="font-size: 11px; background: {}; color: #fff; padding: 2px 6px; border-radius: 4px; margin-left: 4px;">{}</span>',
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
            '<strong>{}</strong> <span style="font-size: 11px; background: {}; color: #fff; padding: 2px 6px; border-radius: 4px; margin-left: 4px;">{}</span>{}',
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
            if reported_user.is_active:
                reported_user.is_active = False
                reported_user.save(update_fields=["is_active"])
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
            if not reported_user.is_active:
                reported_user.is_active = True
                reported_user.save(update_fields=["is_active"])
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

