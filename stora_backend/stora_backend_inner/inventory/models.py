from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

# Mirrors kMaxStock in the Flutter app — the +/- steppers and the
# Add/Edit product form both clamp to this ceiling on the client, and the
# backend enforces the same limit.
MAX_STOCK = 99

# Mirrors the "low stock" threshold used by the Dashboard/Alerts screens.
LOW_STOCK_THRESHOLD = 5

DEFAULT_CATEGORIES = [
    "Snacks",
    "Drinks",
    "Household",
    "Personal Care",
    "Others",
]


class Category(models.Model):
    """A product category, scoped to one store owner. Mirrors CategoryStore:
    categories can be hidden from the filter-chip row without being deleted
    (products already assigned to a hidden category keep it)."""

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="categories",
    )
    name = models.CharField(max_length=100)
    is_hidden = models.BooleanField(
        default=False,
        help_text="Hide from the filter-chip row without deleting.",
    )
    is_archived = models.BooleanField(
        default=False,
        help_text="Removed from the picker; kept so existing products still have a category.",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name_plural = "Categories"
        ordering = ["name"]
        constraints = [
            models.UniqueConstraint(
                fields=["owner", "name"],
                name="uniq_category_per_owner",
            ),
        ]

    def __str__(self):
        return self.name


def product_image_upload_path(instance, filename):
    return f"products/{instance.pk or 'new'}/{filename}"


class Product(models.Model):
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="products",
    )
    name = models.CharField(max_length=150)
    category = models.ForeignKey(
        Category, on_delete=models.PROTECT, related_name="products"
    )
    price = models.DecimalField(
        max_digits=10, decimal_places=2, validators=[MinValueValidator(0)]
    )
    stock = models.PositiveIntegerField(
        default=0, validators=[MaxValueValidator(MAX_STOCK)]
    )
    barcode = models.CharField(max_length=64, blank=True, null=True)
    image = models.ImageField(upload_to=product_image_upload_path, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]
        constraints = [
            models.UniqueConstraint(
                fields=["owner", "barcode"],
                name="uniq_barcode_per_owner",
                condition=models.Q(barcode__isnull=False) & ~models.Q(barcode=""),
            ),
        ]

    def __str__(self):
        return self.name

    @property
    def is_low_stock(self):
        return self.stock < LOW_STOCK_THRESHOLD
