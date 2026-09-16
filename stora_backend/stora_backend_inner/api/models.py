from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models


def chat_image_upload_path(instance, filename):
    return f"chat_images/{instance.sender_id}/{filename}"


class ChatMessage(models.Model):
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="sent_messages",
    )
    recipient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="received_messages",
    )
    order = models.ForeignKey(
        "orders.Order",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="chat_messages",
    )
    message = models.TextField(blank=True, default="")
    image = models.ImageField(upload_to=chat_image_upload_path, null=True, blank=True)
    is_read = models.BooleanField(default=False)
    is_unsent = models.BooleanField(default=False)
    deleted_by_users = models.ManyToManyField(
        settings.AUTH_USER_MODEL,
        blank=True,
        related_name="deleted_chat_messages",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]
        indexes = [
            models.Index(fields=["sender", "recipient", "created_at"]),
            models.Index(fields=["recipient", "is_read"]),
        ]

    def __str__(self):
        return f"{self.sender} -> {self.recipient}: {self.message[:30]}"



class BlockedCustomer(models.Model):
    BLOCK_SIDE_BOTH = "both"
    BLOCK_SIDE_CUSTOMER = "customer"
    BLOCK_SIDE_OWNER = "owner"
    BLOCK_SIDE_CHOICES = (
        (BLOCK_SIDE_BOTH, "Both Sides (Full Chat Block - Neither can message)"),
        (BLOCK_SIDE_CUSTOMER, "Customer Side Only (Customer cannot send messages)"),
        (BLOCK_SIDE_OWNER, "Owner Side Only (Owner cannot send messages)"),
    )

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="blocked_customers",
        null=True,
        blank=True,
        help_text="Store Owner (leave empty if blocking a customer globally across all stores)",
    )
    customer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="blocked_by_owners",
        null=True,
        blank=True,
        help_text="Customer (leave empty if blocking a store owner globally from messaging)",
    )
    block_side = models.CharField(
        max_length=20,
        choices=BLOCK_SIDE_CHOICES,
        default=BLOCK_SIDE_BOTH,
        help_text="Choose which side is blocked from sending messages.",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Blocked Customer/Owner"
        verbose_name_plural = "Blocked Customers/Owners"
        ordering = ["-created_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["owner", "customer"],
                name="uniq_blocked_customer_per_owner",
            )
        ]

    def clean(self):
        super().clean()
        if not self.owner and not self.customer:
            raise ValidationError("Please select at least an Owner, a Customer, or both to block.")
        existing = BlockedCustomer.objects.filter(owner=self.owner, customer=self.customer)
        if self.pk:
            existing = existing.exclude(pk=self.pk)
        if existing.exists():
            raise ValidationError("A block entry for this combination of Owner and Customer already exists.")

    def __str__(self):
        side_label = dict(self.BLOCK_SIDE_CHOICES).get(self.block_side, self.block_side)
        if self.owner and self.customer:
            return f"{self.owner} & {self.customer} ({side_label})"
        elif self.customer:
            return f"Blocked Customer (Global): {self.customer}"
        elif self.owner:
            return f"Blocked Store Owner (Global): {self.owner}"
        return f"Blocked Customer/Owner #{self.pk or ''}"


def report_attachment_upload_path(instance, filename):
    return f"report_attachments/{instance.reporter_id}/{filename}"


class UserReport(models.Model):
    STATUS_PENDING = "pending"
    STATUS_REVIEWED = "reviewed"
    STATUS_ACTION_TAKEN = "action_taken"
    STATUS_DISMISSED = "dismissed"

    STATUS_CHOICES = [
        (STATUS_PENDING, "Pending Review"),
        (STATUS_REVIEWED, "Under Review"),
        (STATUS_ACTION_TAKEN, "Action Taken (User Blocked)"),
        (STATUS_DISMISSED, "Dismissed"),
    ]

    REASON_HARASSMENT = "harassment"
    REASON_FRAUD = "fraud"
    REASON_INAPPROPRIATE = "inappropriate_content"
    REASON_SPAM = "spam"
    REASON_FAKE_ORDER = "fake_order"
    REASON_OTHER = "other"

    REASON_CHOICES = [
        (REASON_HARASSMENT, "Harassment / Abusive Behavior"),
        (REASON_FRAUD, "Fraud / Scam / Non-payment"),
        (REASON_INAPPROPRIATE, "Inappropriate Content / Photos"),
        (REASON_SPAM, "Spam / Unsolicited Messages"),
        (REASON_FAKE_ORDER, "Fake Order / Bogus Customer / Bogus Store"),
        (REASON_OTHER, "Other Violation"),
    ]

    reporter = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="filed_reports",
    )
    reported_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="received_reports",
    )
    reason = models.CharField(max_length=50, choices=REASON_CHOICES, default=REASON_OTHER)
    description = models.TextField(blank=True, default="")
    order = models.ForeignKey(
        "orders.Order",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="reports",
    )
    attachment = models.ImageField(upload_to=report_attachment_upload_path, null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_PENDING)
    admin_notes = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["status", "created_at"]),
            models.Index(fields=["reported_user", "status"]),
        ]

    def __str__(self):
        return f"Report #{self.id}: {self.reporter} -> {self.reported_user} ({self.get_reason_display()})"

