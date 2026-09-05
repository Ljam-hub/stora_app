from decimal import Decimal
import base64
import uuid

from django.contrib.auth import authenticate, get_user_model
from django.core.files.base import ContentFile
from django.db import transaction
from rest_framework import serializers

from accounts.models import PaymentProof, SubscriptionConfig
from inventory.models import DEFAULT_CATEGORIES, MAX_STOCK, Category, Product
from orders.models import Order, OrderItem
from sales.models import Sale, SaleItem
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from .fields import UTCDateTimeField

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    premium_until = UTCDateTimeField(read_only=True, allow_null=True)
    date_joined = UTCDateTimeField(read_only=True)

    class Meta:
        model = User
        fields = ("id", "email", "business_name", "role", "fcm_token", "is_premium", "premium_until", "date_joined")
        read_only_fields = ("id", "is_premium", "premium_until", "date_joined")


class UserUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ("business_name", "email")

    def validate_email(self, value):
        email = value.strip().lower()
        owner = self.instance
        if User.objects.filter(email__iexact=email).exclude(pk=owner.pk).exists():
            raise serializers.ValidationError("An account with this email already exists.")
        return email

    def validate_business_name(self, value):
        val = value.strip()
        if not val:
            raise serializers.ValidationError("Business name cannot be blank.")
        return val


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(required=True, write_only=True)
    new_password = serializers.CharField(required=True, min_length=6, write_only=True)


class RegisterSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=6)
    business_name = serializers.CharField(max_length=150, required=False, allow_blank=True, default="")
    role = serializers.ChoiceField(choices=(("owner", "Store Owner"), ("customer", "Customer")), default="owner")

    def validate_email(self, value):
        email = value.strip().lower()
        if User.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError("An account with this email already exists.")
        return email

    def create(self, validated_data):
        email = validated_data["email"]
        role = validated_data.get("role", "owner")
        business_name = validated_data.get("business_name", "").strip()
        user = User.objects.create_user(
            username=email,
            email=email,
            password=validated_data["password"],
            business_name=business_name,
            role=role,
        )
        if role == "owner":
            Category.objects.bulk_create(
                [Category(owner=user, name=name) for name in DEFAULT_CATEGORIES]
            )
        return user


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        email = attrs["email"].strip().lower()
        password = attrs["password"]
        try:
            user = User.objects.get(email__iexact=email)
        except User.DoesNotExist:
            raise serializers.ValidationError("Invalid email or password.")

        authed = authenticate(username=user.username, password=password)
        if authed is None or not authed.is_active:
            raise serializers.ValidationError("Invalid email or password.")
        attrs["user"] = authed
        return attrs


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ("id", "name", "is_hidden")

    def validate_name(self, value):
        name = value.strip()
        if not name:
            raise serializers.ValidationError("Category name is required.")
        owner = self.context["request"].user
        qs = Category.objects.filter(owner=owner, name__iexact=name, is_archived=False)
        if self.instance:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            raise serializers.ValidationError("You already have this category.")
        return name


class ProductSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(required=False, allow_blank=False)
    image = serializers.CharField(required=False, allow_null=True, allow_blank=True, write_only=True)
    store_name = serializers.CharField(source="owner.business_name", read_only=True)

    class Meta:
        model = Product
        fields = (
            "id",
            "name",
            "category",
            "category_name",
            "price",
            "stock",
            "barcode",
            "image",
            "owner",
            "store_name",
        )
        read_only_fields = ("id", "owner", "store_name")
        extra_kwargs = {
            "category": {"required": False},
            "barcode": {"required": False, "allow_null": True, "allow_blank": True},
        }

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data["category_name"] = instance.category.name if instance.category else ""
        data["store_name"] = (instance.owner.business_name if instance.owner and instance.owner.business_name else (instance.owner.username if instance.owner else ""))
        data["owner"] = instance.owner_id
        data["price"] = f"{instance.price:.2f}"
        data["image"] = self._encode_image(instance)
        return data

    def validate_stock(self, value):
        if value < 0:
            raise serializers.ValidationError("Stock can't be negative.")
        if value > MAX_STOCK:
            raise serializers.ValidationError(f"Stock can't exceed {MAX_STOCK}.")
        return value

    def validate_barcode(self, value):
        if value is None:
            return None
        value = value.strip()
        return value or None

    def create(self, validated_data):
        owner = validated_data.pop("owner", None) or self.context["request"].user
        category = self._resolve_category(validated_data, owner)
        image_payload = validated_data.pop("image", None)
        product = Product.objects.create(owner=owner, category=category, **validated_data)
        self._apply_image(product, image_payload)
        return product

    def update(self, instance, validated_data):
        owner = validated_data.pop("owner", None) or self.context["request"].user
        if "category_name" in validated_data or "category" in validated_data:
            instance.category = self._resolve_category(validated_data, owner)
        image_payload = validated_data.pop("image", serializers.empty)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        if image_payload is not serializers.empty:
            self._apply_image(instance, image_payload)
        return instance

    def _resolve_category(self, validated_data, owner):
        category = validated_data.pop("category", None)
        category_name = (validated_data.pop("category_name", None) or "").strip()
        if category is not None:
            if category.owner_id != owner.id:
                raise serializers.ValidationError({"category": "Invalid category."})
            return category
        if not category_name:
            raise serializers.ValidationError({"category_name": "Please select or add a category."})
        category, _ = Category.objects.get_or_create(
            owner=owner,
            name=category_name,
            defaults={"is_archived": False, "is_hidden": False},
        )
        if category.is_archived:
            category.is_archived = False
            category.save(update_fields=["is_archived"])
        return category

    @staticmethod
    def _encode_image(instance):
        if not instance.image:
            return None
        try:
            instance.image.open("rb")
            encoded = base64.b64encode(instance.image.read()).decode("ascii")
            instance.image.close()
            return encoded
        except Exception:
            return None

    @staticmethod
    def _apply_image(product, payload):
        if not payload:
            if product.image:
                product.image.delete(save=True)
            return
        raw = payload
        if isinstance(raw, str) and "base64," in raw:
            raw = raw.split("base64,", 1)[1]
        try:
            content = base64.b64decode(raw)
        except Exception as exc:
            raise serializers.ValidationError({"image": "Invalid image data."}) from exc
        product.image.save(f"{uuid.uuid4().hex}.jpg", ContentFile(content), save=True)


class SaleItemWriteSerializer(serializers.Serializer):
    product = serializers.IntegerField()
    quantity = serializers.IntegerField(min_value=1)


class SaleItemReadSerializer(serializers.ModelSerializer):
    product_price = serializers.DecimalField(
        source="unit_price", max_digits=10, decimal_places=2
    )

    class Meta:
        model = SaleItem
        fields = ("product", "product_name", "product_price", "quantity")


class SaleSerializer(serializers.ModelSerializer):
    date = UTCDateTimeField(source="created_at", read_only=True)
    items = SaleItemWriteSerializer(many=True, write_only=True)
    line_items = SaleItemReadSerializer(source="items", many=True, read_only=True)

    class Meta:
        model = Sale
        fields = ("id", "date", "total", "items", "line_items")
        read_only_fields = ("total",)

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data["items"] = data.pop("line_items")
        data["total"] = f"{instance.total:.2f}"
        return data

    def create(self, validated_data):
        owner = self.context["request"].user
        raw_items = validated_data.pop("items")
        with transaction.atomic():
            sale = Sale.objects.create(owner=owner, total=0)
            total = 0
            for raw in raw_items:
                try:
                    product = (
                        Product.objects.select_for_update()
                        .select_related("category")
                        .get(pk=raw["product"], owner=owner)
                    )
                except Product.DoesNotExist as exc:
                    raise serializers.ValidationError(
                        {"items": f"Product {raw['product']} was not found."}
                    ) from exc
                qty = raw["quantity"]
                if product.stock < qty:
                    raise serializers.ValidationError(
                        {"items": f"Not enough stock for {product.name}."}
                    )
                product.stock -= qty
                product.save(update_fields=["stock", "updated_at"])
                SaleItem.objects.create(
                    sale=sale,
                    product=product,
                    product_name=product.name,
                    quantity=qty,
                    unit_price=product.price,
                )
                total += qty * product.price
            sale.total = total
            sale.save(update_fields=["total"])
        return sale

class PaymentProofSerializer(serializers.ModelSerializer):
    submitted_at = UTCDateTimeField(read_only=True)
    reviewed_at = UTCDateTimeField(read_only=True, allow_null=True)

    class Meta:
        model = PaymentProof
        fields = (
            "id",
            "reference_number",
            "amount",
            "status",
            "submitted_at",
            "reviewed_at",
        )
        read_only_fields = ("id", "status", "submitted_at", "reviewed_at")

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data["amount"] = f"{instance.amount:.2f}"
        return data


class PaymentProofUploadSerializer(serializers.Serializer):
    reference_number = serializers.CharField(max_length=100)
    amount = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=Decimal("0.01"))
    screenshot = serializers.ImageField()

    def validate_reference_number(self, value):
        val = value.strip()
        if not val:
            raise serializers.ValidationError("Reference number is required.")
        return val


class SubscriptionConfigSerializer(serializers.ModelSerializer):
    class Meta:
        model = SubscriptionConfig
        fields = ("monthly_price", "gcash_number", "gcash_name", "updated_at")

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data["monthly_price"] = f"{instance.monthly_price:.2f}"
        return data


class AccountStatusSerializer(serializers.Serializer):
    is_premium = serializers.BooleanField()
    premium_until = UTCDateTimeField(allow_null=True)
    trial_started_at = UTCDateTimeField()
    trial_ends_at = UTCDateTimeField()
    product_count = serializers.IntegerField()
    product_limit = serializers.IntegerField()
    days_left = serializers.IntegerField()
    can_add_product = serializers.BooleanField()
    monthly_price = serializers.DecimalField(max_digits=8, decimal_places=2)
    gcash_number = serializers.CharField()
    gcash_name = serializers.CharField()
    latest_payment_proof = PaymentProofSerializer(allow_null=True, required=False)


class ForgotPasswordSerializer(serializers.Serializer):
    email = serializers.EmailField()

    def validate_email(self, value):
        return value.strip().lower()


class ResetPasswordSerializer(serializers.Serializer):
    token = serializers.CharField()
    new_password = serializers.CharField(min_length=6, write_only=True)


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token["email"] = user.email
        token["role"] = getattr(user, "role", "owner")
        token["business_name"] = getattr(user, "business_name", "")
        return token

    def validate(self, attrs):
        data = super().validate(attrs)
        data["user"] = {
            "id": self.user.id,
            "email": self.user.email,
            "role": getattr(self.user, "role", "owner"),
            "business_name": getattr(self.user, "business_name", ""),
            "is_premium": getattr(self.user, "is_premium", False),
        }
        return data


class OrderItemSerializer(serializers.ModelSerializer):
    subtotal = serializers.DecimalField(max_digits=10, decimal_places=2, read_only=True)

    class Meta:
        model = OrderItem
        fields = ("id", "product", "product_name", "quantity", "unit_price", "subtotal")


class OrderItemCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrderItem
        fields = ("product", "product_name", "quantity", "unit_price")


class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)
    items_data = OrderItemCreateSerializer(many=True, write_only=True, required=False)
    created_at = UTCDateTimeField(read_only=True)
    expires_at = UTCDateTimeField(read_only=True)
    total_amount = serializers.SerializerMethodField()

    class Meta:
        model = Order
        fields = (
            "id",
            "owner",
            "customer",
            "customer_name",
            "customer_phone",
            "customer_address",
            "notes",
            "status",
            "decline_reason",
            "counter_notes",
            "counter_price",
            "created_at",
            "expires_at",
            "total_amount",
            "items",
            "items_data",
        )
        read_only_fields = (
            "id",
            "customer",
            "status",
            "decline_reason",
            "counter_notes",
            "counter_price",
            "created_at",
            "expires_at",
            "total_amount",
            "items",
        )

    def get_total_amount(self, obj):
        return f"{obj.total_amount():.2f}"

    def create(self, validated_data):
        items_data = validated_data.pop("items_data", [])
        request = self.context.get("request")
        customer = request.user if request and request.user.is_authenticated else None
        order = Order.objects.create(customer=customer, **validated_data)
        for item_data in items_data:
            OrderItem.objects.create(order=order, **item_data)
        return order


class OrderDeclineSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=255, required=False, allow_blank=True, default="")


class OrderCounterSerializer(serializers.Serializer):
    notes = serializers.CharField(required=True)
    counter_price = serializers.DecimalField(max_digits=10, decimal_places=2, required=False, allow_null=True)


class FCMTokenSerializer(serializers.Serializer):
    fcm_token = serializers.CharField(max_length=255, required=True)

