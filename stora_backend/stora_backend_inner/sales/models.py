from decimal import Decimal

from django.conf import settings
from django.db import models


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
