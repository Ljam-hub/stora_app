from datetime import timedelta
from decimal import Decimal
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
    STATUS_READY = "ready"
    STATUS_DECLINED = "declined"
    STATUS_AUTO_DECLINED = "auto_declined"
    STATUS_COUNTER_OFFER = "counter_offer"
    STATUS_CHOICES = (
        (STATUS_PENDING, "Pending"),
        (STATUS_ACCEPTED, "Accepted"),
        (STATUS_READY, "Ready for Pickup"),
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
        with transaction.atomic():
            order = Order.objects.select_for_update().get(pk=self.pk)
            if order.status != self.STATUS_PENDING and order.status != self.STATUS_COUNTER_OFFER:
                return None

            items = list(order.items.select_related("product").all())
            
            product_quantities = {}
            for item in items:
                if item.product_id:
                    product_quantities[item.product_id] = product_quantities.get(item.product_id, 0) + item.quantity
            
            locked_products = {}
            for pid, total_qty in product_quantities.items():
                try:
                    product = Product.objects.select_for_update().get(pk=pid)
                    locked_products[pid] = product
                except Product.DoesNotExist:
                    raise ValueError(f"Product ID {pid} is no longer available in inventory.")
                
                if product.stock < total_qty:
                    raise ValueError(
                        f"Insufficient stock for '{product.name}'. Available: {product.stock}, requested: {total_qty}."
                    )

            order.status = self.STATUS_ACCEPTED
            order.save(update_fields=["status"])
            self.status = self.STATUS_ACCEPTED

            for pid, product in locked_products.items():
                product.stock -= product_quantities[pid]
                product.save(update_fields=["stock", "updated_at"])

            total = order.counter_price if (order.counter_price is not None and order.counter_price > 0) else order.total_amount()
            cust_name = (order.customer_name or "").strip()
            if not cust_name and order.customer:
                if hasattr(order.customer, "get_display_name"):
                    cust_name = order.customer.get_display_name()
                else:
                    cust_name = f"{order.customer.first_name} {order.customer.last_name}".strip() or getattr(order.customer, "business_name", "")
            if not cust_name:
                cust_name = "Customer"

            sale = Sale.objects.create(
                owner=order.owner,
                total=total,
                order=order,
                customer_name=cust_name,
                receipt_number=f"ORD-{order.id}",
                channel="online_order",
            )
            for item in items:
                SaleItem.objects.create(
                    sale=sale,
                    product=item.product,
                    product_name=item.product_name,
                    quantity=item.quantity,
                    unit_price=item.unit_price,
                )
            return sale

    def mark_as_ready(self):
        """Mark an accepted order as ready for pickup."""
        if self.status != self.STATUS_ACCEPTED:
            return False
        self.status = self.STATUS_READY
        self.save(update_fields=["status"])
        return True

    def decline(self, reason: str = None, auto: bool = False):
        """Mark as declined (manual or auto) with an optional reason."""
        with transaction.atomic():
            order = Order.objects.select_for_update().get(pk=self.pk)
            if order.status != self.STATUS_PENDING and order.status != self.STATUS_COUNTER_OFFER:
                return
            order.status = self.STATUS_AUTO_DECLINED if auto else self.STATUS_DECLINED
            order.decline_reason = reason
            order.save(update_fields=["status", "decline_reason"])
            self.status = order.status
            self.decline_reason = order.decline_reason

    def counter_offer(self, notes: str = "", counter_price=None):
        """Propose a counter-offer to the customer."""
        with transaction.atomic():
            order = Order.objects.select_for_update().get(pk=self.pk)
            if order.status != self.STATUS_PENDING:
                return
            order.status = self.STATUS_COUNTER_OFFER
            order.counter_notes = notes
            if counter_price is not None:
                order.counter_price = counter_price
            order.save(update_fields=["status", "counter_notes", "counter_price"])
            self.status = order.status
            self.counter_notes = order.counter_notes
            self.counter_price = order.counter_price

    def total_amount(self):
        return sum((item.subtotal for item in self.items.all()), Decimal("0"))


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
