from datetime import timedelta
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
from django.utils import timezone
from django.utils.html import format_html

from stora_backend.admin_site import stora_admin_site

from .models import User, PasswordResetToken, PaymentProof, SubscriptionConfig, StoreLocation, AIInsight, EmailVerificationCode, PendingRegistration


@admin.register(User, site=stora_admin_site)
class UserAdmin(DjangoUserAdmin):
    fieldsets = DjangoUserAdmin.fieldsets + (
        ("Store & Role info", {"fields": ("role", "business_name", "avatar", "fcm_token", "is_email_verified")}),
        ("Subscription", {"fields": ("is_premium", "premium_until")}),
        ("Moderation & App Access", {"fields": ("is_blocked", "block_reason")}),
    )
    list_display = (
        "email",
        "owner_customer_name",
        "role_badge",
        "account_status_badge",
        "is_email_verified",
        "subscription_status",
        "subscription_expiration",
        "formatted_last_login",
    )
    search_fields = ("username", "email", "business_name", "first_name", "last_name")
    list_filter = ("role", "is_blocked", "is_email_verified", "is_premium", "is_staff", "is_active")
    actions = ["block_selected_users", "unblock_selected_users"]

    @admin.display(description="Verified", boolean=True, ordering="is_email_verified")
    def is_email_verified(self, obj):
        return obj.is_email_verified

    @admin.display(description="Last Login", ordering="last_login")
    def formatted_last_login(self, obj):
        if obj.last_login:
            return obj.last_login.strftime("%Y-%m-%d %H:%M")
        return "-"

    @admin.display(description="Status", ordering="is_blocked")
    def account_status_badge(self, obj):
        if getattr(obj, "is_blocked", False) or not obj.is_active:
            reason = f': {obj.block_reason}' if obj.block_reason else ''
            return format_html(
                '<span style="background: rgba(239, 68, 68, 0.2); color: #f87171; padding: 3px 10px; border-radius: 6px; font-weight: 800; font-size: 11px; border: 1px solid rgba(239, 68, 68, 0.45); display: inline-flex; align-items: center; justify-content: center; margin: 0 auto;" title="Blocked{}">BLOCKED</span>',
                reason,
            )
        return format_html(
            '<span style="background: rgba(16, 185, 129, 0.22); color: #34d399; padding: 3px 10px; border-radius: 6px; font-weight: 800; font-size: 11px; border: 1px solid rgba(52, 211, 153, 0.5); box-shadow: 0 0 8px rgba(16, 185, 129, 0.2); display: inline-flex; align-items: center; justify-content: center; margin: 0 auto;">Active</span>'
        )

    @admin.action(description="Block selected users (disable app access)")
    def block_selected_users(self, request, queryset):
        count = queryset.update(is_blocked=True, is_active=False)
        self.message_user(request, f"{count} user(s) have been blocked from the app.")

    @admin.action(description="Unblock selected users (restore app access)")
    def unblock_selected_users(self, request, queryset):
        count = queryset.update(is_blocked=False, is_active=True)
        self.message_user(request, f"{count} user(s) have been unblocked and granted app access.")

    @admin.display(description="Owner/Customer Name", ordering="business_name")
    def owner_customer_name(self, obj):
        if obj.role == "owner":
            return obj.business_name or f"{obj.first_name} {obj.last_name}".strip() or obj.username
        elif obj.role == "customer":
            return f"{obj.first_name} {obj.last_name}".strip() or obj.business_name or obj.username
        else:
            name = f"{obj.first_name} {obj.last_name}".strip()
            return f"{name} (Admin)" if name else "Administrator"

    @admin.display(description="Role", ordering="role")
    def role_badge(self, obj):
        from django.utils.html import format_html
        if obj.is_superuser or obj.is_staff or obj.role == "admin":
            return format_html('<span class="user-badge user-badge--admin">Admin</span>')
        elif obj.role == "owner":
            return format_html('<span class="user-badge user-badge--owner">Owner</span>')
        return format_html('<span class="user-badge user-badge--customer">Customer</span>')

    @admin.display(description="Subscription")
    def subscription_status(self, obj):
        from django.utils.html import format_html
        if obj.role == "admin":
            return format_html(
                '<span class="user-badge user-badge--admin">Admin</span>'
            )
        if obj.role == "customer":
            return format_html(
                '<span class="user-badge user-badge--customer">Customer</span>'
            )
        if obj.is_premium_active:
            days = obj.days_left
            return format_html(
                '<span class="user-badge user-badge--premium">Premium ({}d)</span>',
                days,
            )
        elif obj.is_trial_active:
            days = obj.days_left
            return format_html(
                '<span class="user-badge user-badge--trial">Trial ({}d)</span>',
                days,
            )
        elif obj.is_premium:
            return format_html(
                '<span class="user-badge user-badge--expired">Expired</span>'
            )
        else:
            return format_html(
                '<span class="user-badge user-badge--free">Free</span>'
            )

    @admin.display(description="Expires On")
    def subscription_expiration(self, obj):
        from django.utils.html import format_html
        if obj.is_premium and obj.premium_until:
            return format_html('<span class="user-expiration">{}</span>', obj.premium_until.strftime("%Y-%m-%d %H:%M"))
        return "-"

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        # Non-superuser staff can only see their own account
        return qs.filter(pk=request.user.pk)

    def has_add_permission(self, request):
        # Only superusers can create users via admin
        return request.user.is_superuser

    def has_delete_permission(self, request, obj=None):
        # Only superusers can delete users
        return request.user.is_superuser

    def get_fieldsets(self, request, obj=None):
        if request.user.is_superuser:
            return super().get_fieldsets(request, obj)
        # Non-superuser staff can only edit their own basic info and avatar
        return (
            (None, {"fields": ("username", "email", "avatar")}),
            ("Store info", {"fields": ("business_name",)}),
        )

    def get_readonly_fields(self, request, obj=None):
        if request.user.is_superuser:
            return super().get_readonly_fields(request, obj)
        # Non-superusers can't change their username/email from admin
        return ("username", "email")


@admin.register(PasswordResetToken, site=stora_admin_site)
class PasswordResetTokenAdmin(admin.ModelAdmin):
    list_display = ("user", "owner_customer_name", "token", "token_status", "created_at", "used")
    list_filter = ("used", "created_at")
    search_fields = ("user__email", "user__username", "user__business_name", "token")
    readonly_fields = ("token", "created_at")

    @admin.display(description="Owner/Customer Name")
    def owner_customer_name(self, obj):
        user = obj.user
        if not user:
            return "—"
        if getattr(user, "role", "") == "owner":
            return user.business_name or f"{user.first_name} {user.last_name}".strip() or user.username
        elif getattr(user, "role", "") == "customer":
            return f"{user.first_name} {user.last_name}".strip() or user.business_name or user.username
        return f"{user.first_name} {user.last_name}".strip() or user.username or "Admin"

    @admin.display(description="Status")
    def token_status(self, obj):
        if obj.used:
            return "✅ Used"
        elif obj.is_valid():
            return "⏳ Active (Valid for 1 hr)"
        else:
            return "❌ Expired"


@admin.register(PaymentProof, site=stora_admin_site)
class PaymentProofAdmin(admin.ModelAdmin):
    list_display = ("user", "owner_customer_name", "reference_number", "amount", "status", "submitted_at", "reviewed_at")
    list_filter = ("status", "submitted_at")
    search_fields = ("reference_number", "user__email", "user__business_name", "user__username")
    actions = ["approve_selected", "reject_selected"]

    @admin.display(description="Owner/Customer Name")
    def owner_customer_name(self, obj):
        user = obj.user
        if not user:
            return "—"
        if getattr(user, "role", "") == "owner":
            return user.business_name or f"{user.first_name} {user.last_name}".strip() or user.username
        elif getattr(user, "role", "") == "customer":
            return f"{user.first_name} {user.last_name}".strip() or user.business_name or user.username
        return f"{user.first_name} {user.last_name}".strip() or user.username or "Admin"

    @admin.action(description="Approve selected payment proofs (Grants 31 Days Premium)")
    def approve_selected(self, request, queryset):
        count = 0
        for proof in queryset:
            proof.approve()
            count += 1
        self.message_user(request, f"Approved {count} payment proof(s). Premium access granted for 31 days.")

    @admin.action(description="Reject selected payment proofs")
    def reject_selected(self, request, queryset):
        now = timezone.now()
        count = queryset.update(status=PaymentProof.STATUS_REJECTED, reviewed_at=now)
        self.message_user(request, f"Rejected {count} payment proof(s).")

    def save_model(self, request, obj, form, change):
        if obj.status == PaymentProof.STATUS_APPROVED:
            if not change or form.initial.get("status") != PaymentProof.STATUS_APPROVED:
                obj.approve()
                return
        super().save_model(request, obj, form, change)


@admin.register(SubscriptionConfig, site=stora_admin_site)
class SubscriptionConfigAdmin(admin.ModelAdmin):
    list_display = ("monthly_price", "gcash_number", "gcash_name", "qr_code_display", "updated_at")
    fields = ("monthly_price", "gcash_number", "gcash_name", "qr_code")

    @admin.display(description="GCash QR Code")
    def qr_code_display(self, obj):
        if obj.qr_code:
            return format_html(
                '<a href="{0}" target="_blank">'
                '<img src="{0}" style="height: 48px; width: 48px; object-fit: contain; border-radius: 6px; border: 1px solid #3b82f6; background: #fff; padding: 2px;" title="Click to view full QR code" />'
                '</a>',
                obj.qr_code.url,
            )
        return format_html('<span style="color: #94a3b8; font-style: italic; font-size: 12px;">Default (Bundled)</span>')

    def has_add_permission(self, request):
        return not SubscriptionConfig.objects.exists()

@admin.register(StoreLocation, site=stora_admin_site)
class StoreLocationAdmin(admin.ModelAdmin):
    list_display = ("owner", "business_name_col", "latitude", "longitude", "address", "is_visible", "updated_at")
    search_fields = ("owner__email", "owner__business_name", "address")
    list_filter = ("is_visible",)

    @admin.display(description="Business Name")
    def business_name_col(self, obj):
        return obj.owner.business_name or "—"


@admin.register(AIInsight, site=stora_admin_site)
class AIInsightAdmin(admin.ModelAdmin):
    list_display = ("title", "owner", "category", "priority", "action_label", "is_dismissed", "created_at")
    list_filter = ("category", "priority", "is_dismissed", "created_at")
    search_fields = ("title", "description", "owner__email", "owner__business_name")


@admin.register(EmailVerificationCode, site=stora_admin_site)
class EmailVerificationCodeAdmin(admin.ModelAdmin):
    list_display = ("user", "owner_customer_name", "code", "created_at", "expires_at", "used", "is_valid_display")
    search_fields = ("user__email", "user__username", "user__business_name", "code")
    list_filter = ("used", "created_at")

    @admin.display(description="Owner/Customer Name")
    def owner_customer_name(self, obj):
        user = obj.user
        if not user:
            return "—"
        if getattr(user, "role", "") == "owner":
            return user.business_name or f"{user.first_name} {user.last_name}".strip() or user.username
        elif getattr(user, "role", "") == "customer":
            return f"{user.first_name} {user.last_name}".strip() or user.business_name or user.username
        return f"{user.first_name} {user.last_name}".strip() or user.username or "Admin"

    @admin.display(description="Valid?", boolean=True)
    def is_valid_display(self, obj):
        return obj.is_valid()


@admin.register(PendingRegistration, site=stora_admin_site)
class PendingRegistrationAdmin(admin.ModelAdmin):
    list_display = ("email", "role_badge", "owner_customer_name", "code", "created_at", "expires_at", "is_valid_display")
    search_fields = ("email", "business_name", "first_name", "last_name", "code")
    list_filter = ("role", "created_at")

    @admin.display(description="Role")
    def role_badge(self, obj):
        from django.utils.html import format_html
        if obj.role == "owner":
            return format_html('<span class="user-badge user-badge--owner">Store Owner (Pending)</span>')
        return format_html('<span class="user-badge user-badge--customer">Customer (Pending)</span>')

    @admin.display(description="Owner/Customer Name")
    def owner_customer_name(self, obj):
        if obj.role == "owner":
            return obj.business_name or f"{obj.first_name} {obj.last_name}".strip() or "—"
        return f"{obj.first_name} {obj.last_name}".strip() or "—"

    @admin.display(description="Valid?", boolean=True)
    def is_valid_display(self, obj):
        return obj.is_valid()




