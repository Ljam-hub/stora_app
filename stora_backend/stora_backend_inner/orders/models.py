from datetime import timedelta
from django.conf import settings
from django.db import models, transaction
from django.utils import timezone
from inventory.models import Product
from sales.models import Sale, SaleItem


def default_order_expiry():
    return timezone.now() + timedelta(hours=24)


class Order(models.Model):
    """A pending order placed by a customer.
    Stock is not reserved until the owner accepts the order.
    The order may be auto‑declined after a timeout or manually declined/accepted/countered.
    """

    STATUS_PENDING = "pending"
    STATUS_ACCEPTED = "accepted"
    STATUS_DECLINED = "declined"
    STATUS_AUTO_DECLINED = "auto_declined"
    STATUS_COUNTER_OFFER = "counter_offer"
    STATUS_CHOICES = (
        (STATUS_PENDING, "Pending"),
        (STATUS_ACCEPTED, "Accepted"),
        (STATUS_DECLINED, "Declined"),
        (STATUS_AUTO_DECLINED, "Auto‑Declined"),
        (STATUS_COUNTER_OFFER, "Counter‑Offer"),
    )

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="pending_orders",
    )
    customer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="customer_orders",
    )
    customer_name = models.CharField(max_length=150, blank=True, default="")
    customer_phone = models.CharField(max_length=50, blank=True, default="")
    customer_address = models.TextField(blank=True, default="")
    notes = models.TextField(blank=True, default="")

    created_at = models.DateTimeField(auto_now_add=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_PENDING)
    decline_reason = models.CharField(max_length=255, blank=True, null=True)
    counter_notes = models.TextField(blank=True, default="")
    counter_price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)

    # Auto‑expire after 24 hours
    expires_at = models.DateTimeField(default=default_order_expiry)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["owner", "status"]),
            models.Index(fields=["customer", "status"]),
        ]

    def save(self, *args, **kwargs):
        if not self.expires_at:
            self.expires_at = default_order_expiry()
        super().save(*args, **kwargs)

    def __str__(self):
        return f"Order #{self.pk} – {self.get_status_display()}"

    def is_expired(self):
        return timezone.now() >= self.expires_at

    def accept(self):
        """Mark as accepted and decrement product stock for each line item.
        Validates stock availability and performs updates atomically.
        """
        if self.status != self.STATUS_PENDING and self.status != self.STATUS_COUNTER_OFFER:
            return None

        with transaction.atomic():
            items = list(self.items.select_related("product").all())
            locked_products = {}
            for item in items:
                if item.product_id:
                    if item.product_id not in locked_products:
                        product = Product.objects.select_for_update().get(pk=item.product_id)
                        locked_products[item.product_id] = product
                    else:
                        product = locked_products[item.product_id]

                    if product.stock < item.quantity:
                        raise ValueError(
                            f"Insufficient stock for '{item.product_name}'. Available: {product.stock}, requested: {item.quantity}."
                        )

            self.status = self.STATUS_ACCEPTED
            self.save(update_fields=["status"])

            for item in items:
                if item.product_id and item.product_id in locked_products:
                    product = locked_products[item.product_id]
                    product.stock -= item.quantity
                    product.save(update_fields=["stock", "updated_at"])

            total = self.counter_price if (self.counter_price is not None and self.counter_price > 0) else self.total_amount()
            sale = Sale.objects.create(owner=self.owner, total=total)
            for item in items:
                SaleItem.objects.create(
                    sale=sale,
                    product=item.product,
                    product_name=item.product_name,
                    quantity=item.quantity,
                    unit_price=item.unit_price,
                )
            return sale

    def decline(self, reason: str = None, auto: bool = False):
        """Mark as declined (manual or auto) with an optional reason."""
        if self.status != self.STATUS_PENDING and self.status != self.STATUS_COUNTER_OFFER:
            return
        self.status = self.STATUS_AUTO_DECLINED if auto else self.STATUS_DECLINED
        self.decline_reason = reason
        self.save(update_fields=["status", "decline_reason"])

    def counter_offer(self, notes: str = "", counter_price=None):
        """Propose a counter-offer to the customer."""
        if self.status != self.STATUS_PENDING:
            return
        self.status = self.STATUS_COUNTER_OFFER
        self.counter_notes = notes
        if counter_price is not None:
            self.counter_price = counter_price
        self.save(update_fields=["status", "counter_notes", "counter_price"])

    def total_amount(self):
        return sum(item.subtotal for item in self.items.all())


class OrderItem(models.Model):
    """A line item within a pending Order. Mirrors SaleItem but does not affect
    stock until the order is accepted.
    """

    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name="items")
    product = models.ForeignKey(
        "inventory.Product",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="order_items",
    )
    product_name = models.CharField(max_length=150)
    quantity = models.PositiveIntegerField(default=1)
    unit_price = models.DecimalField(max_digits=10, decimal_places=2)

    @property
    def subtotal(self):
        return self.quantity * self.unit_price

    def __str__(self):
        return f"{self.product_name} x{self.quantity}"
