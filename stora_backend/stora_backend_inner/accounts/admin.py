from datetime import timedelta
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
from django.utils import timezone

from stora_backend.admin_site import stora_admin_site

from .models import User, PasswordResetToken, PaymentProof, SubscriptionConfig


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
            return format_html(
                '<span style="background-color: #241D38; color: #9B87F5; padding: 3px 8px; border-radius: 6px; font-weight: 700; font-size: 11px;">🏪 Store Owner</span>'
            )
        return format_html(
            '<span style="background-color: #132D1B; color: #4ADE80; padding: 3px 8px; border-radius: 6px; font-weight: 700; font-size: 11px;">🛒 Customer</span>'
        )

    @admin.display(description="Subscription Status")
    def subscription_status(self, obj):
        if obj.is_premium_active:
            days = obj.days_left
            return f"🌟 Premium ({days} days left)"
        elif obj.is_trial_active:
            days = obj.days_left
            return f"Free Trial ({days} days left)"
        elif obj.is_premium:
            return "⚠️ Premium Expired (Reverted to Free - First 20 items)"
        else:
            return "Free Plan (Expired - First 20 items)"

    @admin.display(description="Expires On")
    def subscription_expiration(self, obj):
        if obj.is_premium and obj.premium_until:
            return obj.premium_until.strftime("%Y-%m-%d %H:%M")
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
    list_display = ("monthly_price", "gcash_number", "gcash_name", "updated_at")
    fields = ("monthly_price", "gcash_number", "gcash_name")

    def has_add_permission(self, request):
        return not SubscriptionConfig.objects.exists()

    def has_delete_permission(self, request, obj=None):
        return False


