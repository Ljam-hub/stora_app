from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone
from django.conf import settings
from datetime import timedelta
import secrets
import uuid


class User(AbstractUser):
    """Extends Django's built-in user with the Register screen's business
    name. Email is unique so the Flutter login form can authenticate with
    it (username is still stored, set equal to email on register)."""

    ROLE_ADMIN = "admin"
    ROLE_OWNER = "owner"
    ROLE_CUSTOMER = "customer"
    ROLE_CHOICES = (
        (ROLE_ADMIN, "Administrator"),
        (ROLE_OWNER, "Store Owner"),
        (ROLE_CUSTOMER, "Customer"),
    )

    email = models.EmailField(unique=True)
    business_name = models.CharField(max_length=150, blank=True)
    role = models.CharField(
        max_length=20,
        choices=ROLE_CHOICES,
        default=ROLE_OWNER,
    )
    is_email_verified = models.BooleanField(default=False)
    fcm_token = models.CharField(max_length=255, blank=True, null=True)
    is_premium = models.BooleanField(default=False)
    premium_until = models.DateTimeField(null=True, blank=True)
    avatar = models.ImageField(upload_to="avatars/", null=True, blank=True)
    is_blocked = models.BooleanField(
        default=False,
        help_text="Designates whether this user (customer or owner) is blocked from using the app.",
    )
    block_reason = models.CharField(
        max_length=255,
        blank=True,
        default="",
        help_text="Reason why the user was blocked.",
    )

    @property
    def is_admin_role(self):
        return bool(self.role == self.ROLE_ADMIN or self.is_superuser)

    @property
    def trial_ends_at(self):
        if self.role != self.ROLE_OWNER:
            return None
        return self.date_joined + timedelta(days=settings.FREE_TRIAL_DAYS)

    @property
    def is_trial_active(self):
        if self.role != self.ROLE_OWNER:
            return False
        if not self.trial_ends_at:
            return False
        return timezone.now() < self.trial_ends_at

    @property
    def is_premium_active(self):
        if self.role == self.ROLE_ADMIN:
            return True
        return bool(self.is_premium and self.premium_until and timezone.now() < self.premium_until)

    @property
    def has_full_access(self):
        if self.role in (self.ROLE_ADMIN, self.ROLE_CUSTOMER):
            return True
        return self.is_premium_active or self.is_trial_active

    @property
    def days_left(self):
        if self.role != self.ROLE_OWNER:
            return 0
        if self.is_premium_active and self.premium_until:
            return max(0, (self.premium_until - timezone.now()).days)
        elif self.is_trial_active and self.trial_ends_at:
            return max(0, (self.trial_ends_at - timezone.now()).days)
        return 0

    def save(self, *args, **kwargs):
        if self.is_superuser or self.is_staff:
            self.role = self.ROLE_ADMIN
        elif self.role == self.ROLE_ADMIN:
            self.is_staff = True
        super().save(*args, **kwargs)

    def get_display_name(self):
        if self.role in (self.ROLE_OWNER, self.ROLE_ADMIN) and self.business_name:
            return self.business_name
        name = f"{self.first_name} {self.last_name}".strip()
        if name:
            return name
        if self.business_name:
            return self.business_name
        if self.role == self.ROLE_CUSTOMER:
            order_name = (
                self.customer_orders.exclude(customer_name="")
                .order_by("-created_at")
                .values_list("customer_name", flat=True)
                .first()
            )
            if order_name:
                return order_name
        return self.username or self.email

    def __str__(self):
        return self.get_display_name()


class PendingRegistration(models.Model):
    """Holds unverified registrations. The User account is ONLY created
    once the 6-digit email verification code is confirmed."""
    email = models.EmailField(unique=True)
    password = models.CharField(max_length=255)
    role = models.CharField(max_length=20, choices=User.ROLE_CHOICES, default=User.ROLE_CUSTOMER)
    business_name = models.CharField(max_length=150, blank=True, default="")
    first_name = models.CharField(max_length=150, blank=True, default="")
    last_name = models.CharField(max_length=150, blank=True, default="")
    code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()

    class Meta:
        ordering = ['-created_at']

    def is_valid(self):
        return timezone.now() < self.expires_at

    @classmethod
    def create_or_update_pending(cls, email, password, role, business_name="", first_name="", last_name="", validity_minutes=15):
        from django.contrib.auth.hashers import make_password
        cls.purge_expired()
        hashed = make_password(password) if not password.startswith(('pbkdf2_', 'argon2', 'bcrypt')) else password
        code = f"{secrets.randbelow(900000) + 100000}"
        expires_at = timezone.now() + timedelta(minutes=validity_minutes)
        obj, _ = cls.objects.update_or_create(
            email=email.strip().lower(),
            defaults={
                "password": hashed,
                "role": role,
                "business_name": business_name.strip(),
                "first_name": first_name.strip(),
                "last_name": last_name.strip(),
                "code": code,
                "expires_at": expires_at,
            }
        )
        return obj

    @classmethod
    def purge_expired(cls):
        # Auto-purge pending registrations older than 24 hours
        threshold = timezone.now() - timedelta(hours=24)
        cls.objects.filter(created_at__lt=threshold).delete()

    def __str__(self):
        return f"Pending {self.role}: {self.email} (code: {self.code})"


class EmailVerificationCode(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='email_verifications')
    code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    used = models.BooleanField(default=False)

    class Meta:
        ordering = ['-created_at']

    def is_valid(self):
        if self.used:
            return False
        return timezone.now() < self.expires_at

    @classmethod
    def generate_code(cls, user, validity_minutes=15):
        cls.objects.filter(user=user, used=False).update(used=True)
        code = f"{secrets.randbelow(900000) + 100000}"
        expires_at = timezone.now() + timedelta(minutes=validity_minutes)
        return cls.objects.create(user=user, code=code, expires_at=expires_at)

    def __str__(self):
        return f"Verification code {self.code} for {self.user.email} (used={self.used})"


class PasswordResetToken(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='reset_tokens')
    token = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    used = models.BooleanField(default=False)

    def is_valid(self):
        if self.used:
            return False
        return timezone.now() < self.created_at + timedelta(hours=1)

    def __str__(self):
        return f'Reset token for {self.user.email}'


class PaymentProof(models.Model):
    STATUS_PENDING = "pending"
    STATUS_APPROVED = "approved"
    STATUS_REJECTED = "rejected"
    STATUS_CHOICES = (
        (STATUS_PENDING, "Pending"),
        (STATUS_APPROVED, "Approved"),
        (STATUS_REJECTED, "Rejected"),
    )

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="payment_proofs",
    )
    reference_number = models.CharField(max_length=100)
    screenshot = models.ImageField(upload_to="payment_proofs/")
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default=STATUS_PENDING,
    )
    submitted_at = models.DateTimeField(auto_now_add=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-submitted_at"]

    def __str__(self):
        return f"PaymentProof #{self.id} ({self.user.email} - {self.reference_number}) [{self.status}]"

    def approve(self):
        now = timezone.now()
        self.status = self.STATUS_APPROVED
        self.reviewed_at = now
        self.save(update_fields=["status", "reviewed_at"])

        user = self.user
        user.is_premium = True
        base_time = user.premium_until if (user.premium_until and user.premium_until > now) else now
        user.premium_until = base_time + timedelta(days=31)
        user.save(update_fields=["is_premium", "premium_until"])


class SubscriptionConfig(models.Model):
    monthly_price = models.DecimalField(max_digits=8, decimal_places=2, default=70.00, help_text="Monthly premium price in PHP")
    gcash_number = models.CharField(max_length=50, default="0917 000 0070", help_text="GCash receiver mobile number")
    gcash_name = models.CharField(max_length=100, default="STORA Admin", help_text="GCash receiver account name")
    qr_code = models.ImageField(
        upload_to="subscription_qr/",
        null=True,
        blank=True,
        help_text="Upload custom GCash / InstaPay QR code image",
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Subscription Pricing & Settings"
        verbose_name_plural = "Subscription Pricing & Settings"

    def __str__(self):
        return f"₱{self.monthly_price}/mo (GCash: {self.gcash_number} - {self.gcash_name})"

    @classmethod
    def get_config(cls):
        config, _ = cls.objects.get_or_create(
            id=1,
            defaults={
                "monthly_price": 70.00,
                "gcash_number": "0917 000 0070",
                "gcash_name": "STORA Admin",
            },
        )
        return config


class StoreLocation(models.Model):
    owner = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="location",
    )
    latitude = models.FloatField(default=14.5995)
    longitude = models.FloatField(default=120.9842)
    address = models.CharField(max_length=255, blank=True, default="")
    is_visible = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.owner.business_name or self.owner.email} ({self.latitude}, {self.longitude})"


class AIInsight(models.Model):
    PRIORITY_HIGH = "high"
    PRIORITY_MEDIUM = "medium"
    PRIORITY_LOW = "low"
    PRIORITY_CHOICES = (
        (PRIORITY_HIGH, "High"),
        (PRIORITY_MEDIUM, "Medium"),
        (PRIORITY_LOW, "Low"),
    )

    CATEGORY_INVENTORY = "inventory"
    CATEGORY_SALES = "sales"
    CATEGORY_PRICING = "pricing"
    CATEGORY_GROWTH = "growth"
    CATEGORY_CHOICES = (
        (CATEGORY_INVENTORY, "Inventory"),
        (CATEGORY_SALES, "Sales"),
        (CATEGORY_PRICING, "Pricing"),
        (CATEGORY_GROWTH, "Growth"),
    )

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="ai_insights",
    )
    title = models.CharField(max_length=200)
    description = models.TextField()
    category = models.CharField(max_length=30, choices=CATEGORY_CHOICES, default=CATEGORY_INVENTORY)
    priority = models.CharField(max_length=20, choices=PRIORITY_CHOICES, default=PRIORITY_MEDIUM)
    action_label = models.CharField(max_length=80, blank=True, default="View Details")
    action_target = models.CharField(max_length=80, blank=True, default="inventory")
    is_dismissed = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"[{self.priority.upper()}] {self.title} - {self.owner.email}"


