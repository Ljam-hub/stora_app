from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone
from django.conf import settings
from datetime import timedelta
import uuid


class User(AbstractUser):
    """Extends Django's built-in user with the Register screen's business
    name. Email is unique so the Flutter login form can authenticate with
    it (username is still stored, set equal to email on register)."""

    email = models.EmailField(unique=True)
    business_name = models.CharField(max_length=150, blank=True)
    role = models.CharField(
        max_length=20,
        choices=(("owner", "Store Owner"), ("customer", "Customer")),
        default="owner",
    )
    fcm_token = models.CharField(max_length=255, blank=True, null=True)
    is_premium = models.BooleanField(default=False)
    premium_until = models.DateTimeField(null=True, blank=True)

    @property
    def trial_ends_at(self):
        return self.date_joined + timedelta(days=settings.FREE_TRIAL_DAYS)

    @property
    def is_trial_active(self):
        return timezone.now() < self.trial_ends_at

    @property
    def is_premium_active(self):
        return bool(self.is_premium and self.premium_until and timezone.now() < self.premium_until)

    @property
    def has_full_access(self):
        return self.is_premium_active or self.is_trial_active

    @property
    def days_left(self):
        if self.is_premium_active and self.premium_until:
            return max(0, (self.premium_until - timezone.now()).days)
        elif self.is_trial_active:
            return max(0, (self.trial_ends_at - timezone.now()).days)
        return 0

    def __str__(self):
        return self.business_name or self.email or self.username


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

