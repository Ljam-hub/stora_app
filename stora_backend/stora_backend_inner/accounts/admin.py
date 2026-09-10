from datetime import timedelta
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
from django.utils import timezone
from django.utils.html import format_html

from stora_backend.admin_site import stora_admin_site

from .models import User, PasswordResetToken, PaymentProof, SubscriptionConfig, StoreLocation, AIInsight


@admin.register(User, site=stora_admin_site)
class UserAdmin(DjangoUserAdmin):
    fieldsets = DjangoUserAdmin.fieldsets + (
        ("Store & Role info", {"fields": ("role", "business_name", "fcm_token")}),
        ("Subscription", {"fields": ("is_premium", "premium_until")}),
    )
    list_display = (
        "username",
        "email",
        "role_badge",
        "business_name",
        "subscription_status",
        "subscription_expiration",
        "last_login",
        "is_staff",
        "is_active",
    )
    search_fields = ("username", "email", "business_name")
    list_filter = ("role", "is_premium", "is_staff", "is_active")

    @admin.display(description="Role")
    def role_badge(self, obj):
        from django.utils.html import format_html
        if obj.role == "owner":
            return format_html('<span class="user-badge user-badge--owner">Store Owner</span>')
        return format_html('<span class="user-badge user-badge--customer">Customer</span>')

    @admin.display(description="Subscription")
    def subscription_status(self, obj):
        from django.utils.html import format_html
        if obj.is_premium_active:
            days = obj.days_left
            return format_html(
                '<span class="user-badge user-badge--premium">Premium ({}d left)</span>',
                days,
            )
        elif obj.is_trial_active:
            days = obj.days_left
            return format_html(
                '<span class="user-badge user-badge--trial">Trial ({}d left)</span>',
                days,
            )
        elif obj.is_premium:
            return format_html(
                '<span class="user-badge user-badge--expired">Expired</span>'
            )
        else:
            return format_html(
                '<span class="user-badge user-badge--free">Free Plan</span>'
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
        # Non-superuser staff can only edit their own basic info
        return (
            (None, {"fields": ("username", "email")}),
            ("Store info", {"fields": ("business_name",)}),
        )

    def get_readonly_fields(self, request, obj=None):
        if request.user.is_superuser:
            return super().get_readonly_fields(request, obj)
        # Non-superusers can't change their username/email from admin
        return ("username", "email")


@admin.register(PasswordResetToken, site=stora_admin_site)
class PasswordResetTokenAdmin(admin.ModelAdmin):
    list_display = ("user", "token", "token_status", "created_at", "used")
    list_filter = ("used", "created_at")
    search_fields = ("user__email", "user__username", "token")
    readonly_fields = ("token", "created_at")

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
    list_display = ("user", "reference_number", "amount", "status", "submitted_at", "reviewed_at")
    list_filter = ("status", "submitted_at")
    search_fields = ("reference_number", "user__email", "user__business_name", "user__username")
    actions = ["approve_selected", "reject_selected"]

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
    list_display = ("owner", "latitude", "longitude", "address", "is_visible", "updated_at")
    search_fields = ("owner__email", "owner__business_name", "address")
    list_filter = ("is_visible",)


@admin.register(AIInsight, site=stora_admin_site)
class AIInsightAdmin(admin.ModelAdmin):
    list_display = ("title", "owner", "category", "priority", "action_label", "is_dismissed", "created_at")
    list_filter = ("category", "priority", "is_dismissed", "created_at")
    search_fields = ("title", "description", "owner__email", "owner__business_name")



