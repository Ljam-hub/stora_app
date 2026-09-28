from decimal import Decimal

from django.conf import settings
from django.db import models
from django.utils import timezone


class Sale(models.Model):
    """A completed checkout. Mirrors Sale/SalesStore: a snapshot of what
    was sold, kept even if the underlying products later change."""

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="sales",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    total = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    order = models.ForeignKey(
        "orders.Order",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="sales",
    )
    customer_name = models.CharField(max_length=150, blank=True, default="Walk-in Customer")
    receipt_number = models.CharField(max_length=64, blank=True, default="")
    channel = models.CharField(max_length=20, default="in_store")

    class Meta:
        ordering = ["-created_at"]

    def save(self, *args, **kwargs):
        is_new = self.pk is None
        if (self.order_id or (self.receipt_number and self.receipt_number.startswith("ORD-"))) and self.channel != "online_order":
            self.channel = "online_order"
        super().save(*args, **kwargs)
        if is_new and not self.receipt_number:
            if self.order_id:
                self.receipt_number = f"ORD-{self.order_id}"
            else:
                self.receipt_number = f"POS-{self.pk}"
            super().save(update_fields=["receipt_number"])

    def __str__(self):
        items = list(self.items.all())
        if items:
            item_summary = ", ".join(f"{it.product_name} x{it.quantity}" for it in items[:3])
            if len(items) > 3:
                item_summary += f" +{len(items)-3} more"
            return f"{item_summary} (\u20b1{self.total:.2f})"
        return f"Sale #{self.pk} \u2014 {self.created_at:%Y-%m-%d %H:%M}"

    def recalculate_total(self):
        if self.order and self.order.counter_price is not None and self.order.counter_price > 0:
            self.total = self.order.counter_price
        else:
            total = sum((item.subtotal for item in self.items.all()), Decimal("0"))
            self.total = total
        self.save(update_fields=["total"])


class SaleItem(models.Model):
    """A single line item within a sale. unit_price and product_name are
    snapshotted at sale time (mirrors CartItem), so later product edits
    don't retroactively rewrite history."""

    sale = models.ForeignKey(Sale, on_delete=models.CASCADE, related_name="items")
    product = models.ForeignKey(
        "inventory.Product",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="sale_items",
    )
    product_name = models.CharField(max_length=150)
    quantity = models.PositiveIntegerField(default=1)
    unit_price = models.DecimalField(max_digits=10, decimal_places=2)

    @property
    def subtotal(self):
        return self.quantity * self.unit_price

    def __str__(self):
        return f"{self.product_name} x{self.quantity}"


class CustomerCredit(models.Model):
    """A walk-in customer credit (utang / loan) record managed by store owners."""

    STATUS_ACTIVE = "active"
    STATUS_SETTLED = "settled"
    STATUS_OVERDUE = "overdue"
    STATUS_CHOICES = [
        (STATUS_ACTIVE, "Active"),
        (STATUS_SETTLED, "Settled"),
        (STATUS_OVERDUE, "Overdue"),
    ]

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="customer_credits",
    )
    customer_name = models.CharField(max_length=150)
    customer_phone = models.CharField(max_length=32, blank=True, default="")
    total_amount = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    amount_paid = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    due_date = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_ACTIVE)
    notes = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "Customer Loan / Utang"
        verbose_name_plural = "Customer Loans / Utang"

    @property
    def balance(self):
        bal = self.total_amount - self.amount_paid
        return bal if bal > Decimal("0.00") else Decimal("0.00")

    @property
    def is_fully_paid(self):
        return self.balance <= Decimal("0.01")

    @property
    def is_overdue(self):
        if self.is_fully_paid:
            return False
        if not self.due_date:
            return False
        return self.due_date < timezone.localdate()

    def recalculate_totals(self):
        if hasattr(self, "_prefetched_objects_cache"):
            self._prefetched_objects_cache.pop("payments", None)
            self._prefetched_objects_cache.pop("items", None)
        paid = sum((p.amount for p in self.payments.all()), Decimal("0.00"))
        self.amount_paid = paid

        if self.items.exists() and self.total_amount == Decimal("0.00"):
            self.total_amount = sum((i.subtotal for i in self.items.all()), Decimal("0.00"))

        if self.is_fully_paid:
            self.status = self.STATUS_SETTLED
        elif self.is_overdue:
            self.status = self.STATUS_OVERDUE
        else:
            self.status = self.STATUS_ACTIVE

        self.save(update_fields=["amount_paid", "total_amount", "status", "updated_at"])

    def __str__(self):
        return f"{self.customer_name} \u2014 \u20b1{self.balance:.2f} ({self.get_status_display()})"


class CreditItem(models.Model):
    """An itemized breakdown of items charged to credit/loan."""

    credit = models.ForeignKey(CustomerCredit, on_delete=models.CASCADE, related_name="items")
    product = models.ForeignKey(
        "inventory.Product",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="credit_items",
    )
    product_name = models.CharField(max_length=150)
    quantity = models.PositiveIntegerField(default=1)
    unit_price = models.DecimalField(max_digits=10, decimal_places=2)

    @property
    def subtotal(self):
        return self.quantity * self.unit_price

    def __str__(self):
        return f"{self.product_name} x{self.quantity} (\u20b1{self.subtotal:.2f})"

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        if self.credit_id:
            self.credit.recalculate_totals()

    def delete(self, *args, **kwargs):
        credit = self.credit
        super().delete(*args, **kwargs)
        if credit:
            credit.recalculate_totals()


class CreditPayment(models.Model):
    """Payment transaction against an existing customer credit/loan."""

    credit = models.ForeignKey(CustomerCredit, on_delete=models.CASCADE, related_name="payments")
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    payment_method = models.CharField(max_length=32, default="cash")
    notes = models.CharField(max_length=255, blank=True, default="")
    paid_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ["-paid_at"]

    def __str__(self):
        return f"Payment \u20b1{self.amount:.2f} on {self.paid_at:%Y-%m-%d} ({self.credit.customer_name})"

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        self.credit.recalculate_totals()

    def delete(self, *args, **kwargs):
        credit = self.credit
        super().delete(*args, **kwargs)
        credit.recalculate_totals()

