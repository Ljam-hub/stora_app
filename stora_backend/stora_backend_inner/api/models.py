from django.conf import settings
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
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="blocked_customers",
    )
    customer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="blocked_by_owners",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["owner", "customer"],
                name="uniq_blocked_customer_per_owner",
            )
        ]

    def __str__(self):
        return f"{self.owner} blocked {self.customer}"


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

