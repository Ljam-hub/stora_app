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

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"Sale #{self.pk} \u2014 {self.created_at:%Y-%m-%d %H:%M}"

    def recalculate_total(self):
        total = sum((item.subtotal for item in self.items.all()), start=0)
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
