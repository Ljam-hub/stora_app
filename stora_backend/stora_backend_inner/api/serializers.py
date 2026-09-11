from decimal import Decimal
import base64
import uuid

from django.contrib.auth import authenticate, get_user_model
from django.core.files.base import ContentFile
from django.db import transaction
from rest_framework import serializers

from accounts.models import PaymentProof, SubscriptionConfig, StoreLocation, AIInsight, PendingRegistration
from inventory.models import DEFAULT_CATEGORIES, MAX_STOCK, Category, Product
from orders.models import Order, OrderItem
from sales.models import Sale, SaleItem
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from .models import BlockedCustomer, ChatMessage, UserReport

from .fields import UTCDateTimeField

User = get_user_model()


def canonicalize_email(email: str) -> str:
    """Normalizes an email address so that Gmail aliases (dots, +tags, googlemail)
    collapse into a single unique canonical identity (1 Gmail per user).
    Non-Gmail domains are lowercased and trimmed without altering dots/pluses.
    """
    if not email or "@" not in email:
        return (email or "").strip().lower()

    local_part, domain = email.rsplit("@", 1)
    local_part = local_part.strip().lower()
    domain = domain.strip().lower()

    if domain in ("gmail.com", "googlemail.com"):
        domain = "gmail.com"
        # Strip all dots from local part
        local_part = local_part.replace(".", "")
        # Strip plus aliases (+anything)
        local_part = local_part.split("+", 1)[0]

    return f"{local_part}@{domain}"


class UserSerializer(serializers.ModelSerializer):
    premium_until = UTCDateTimeField(read_only=True, allow_null=True)
    date_joined = UTCDateTimeField(read_only=True)
    avatar_url = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ("id", "email", "business_name", "role", "is_email_verified", "fcm_token", "is_premium", "premium_until", "date_joined", "avatar", "avatar_url")
        read_only_fields = ("id", "is_email_verified", "is_premium", "premium_until", "date_joined", "avatar_url")

    def get_avatar_url(self, obj):
        if obj.avatar:
            request = self.context.get("request")
            if request:
                return request.build_absolute_uri(obj.avatar.url)
            return obj.avatar.url
        return None


class UserUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ("business_name", "email", "avatar")

    def validate_email(self, value):
        email = canonicalize_email(value)
        owner = self.instance
        if User.objects.filter(email__iexact=email).exclude(pk=owner.pk).exists():
            raise serializers.ValidationError("An account with this email already exists.")
        return email

    def validate_business_name(self, value):
        val = value.strip()
        if not val:
            raise serializers.ValidationError("Business name cannot be blank.")
        return val

    def update(self, instance, validated_data):
        new_email = validated_data.get("email")
        if new_email and new_email != instance.email:
            instance.email = new_email
            instance.username = new_email
            instance.is_email_verified = False
        if "business_name" in validated_data:
            instance.business_name = validated_data["business_name"]
        if "avatar" in validated_data:
            instance.avatar = validated_data["avatar"]
        instance.save()
        return instance


class VerifyEmailSerializer(serializers.Serializer):
    email = serializers.EmailField()
    code = serializers.CharField(max_length=6, min_length=6)

    def validate_email(self, value):
        return canonicalize_email(value)

    def validate_code(self, value):
        val = value.strip()
        if not val.isdigit() or len(val) != 6:
            raise serializers.ValidationError("Verification code must be 6 digits.")
        return val


class ResendVerificationSerializer(serializers.Serializer):
    email = serializers.EmailField()

    def validate_email(self, value):
        return canonicalize_email(value)


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(required=True, write_only=True)
    new_password = serializers.CharField(required=True, min_length=6, write_only=True)


class RegisterSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=6)
    business_name = serializers.CharField(max_length=150, required=False, allow_blank=True, default="")
    first_name = serializers.CharField(max_length=150, required=False, allow_blank=True, default="")
    last_name = serializers.CharField(max_length=150, required=False, allow_blank=True, default="")
    role = serializers.ChoiceField(choices=(("owner", "Store Owner"), ("customer", "Customer")), default="owner")

    def validate(self, attrs):
        email = canonicalize_email(attrs["email"])
        attrs["email"] = email
        role = attrs.get("role", "owner")

        # Check existing user accounts
        existing_user = User.objects.filter(email__iexact=email).first()
        if existing_user:
            if existing_user.role == "customer" and role == "owner":
                raise serializers.ValidationError({"email": "This email is registered as a Customer account and cannot be used in the Store Owner app."})
            elif existing_user.role in ("owner", "admin") and role == "customer":
                raise serializers.ValidationError({"email": "This email is registered as a Store Owner account and cannot be used in the Customer app."})
            else:
                raise serializers.ValidationError({"email": "An account with this email already exists."})

        # Check pending unverified registrations
        pending = PendingRegistration.objects.filter(email__iexact=email).first()
        if pending and pending.is_valid():
            if pending.role != role:
                other_role = "Customer" if pending.role == "customer" else "Store Owner"
                app_target = "Store Owner" if role == "owner" else "Customer"
                raise serializers.ValidationError({"email": f"This email has a pending {other_role} registration and cannot be used in the {app_target} app."})
            else:
                raise serializers.ValidationError({"email": "An account with this email already exists."})

        return attrs


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)
    app_role = serializers.CharField(required=False, allow_blank=True, default="")

    def validate(self, attrs):
        email = canonicalize_email(attrs["email"])
        password = attrs["password"]
        app_role = (attrs.get("app_role") or "").strip().lower()

        try:
            user = User.objects.get(email__iexact=email)
        except User.DoesNotExist:
            raise serializers.ValidationError("Invalid email or password.")

        authed = authenticate(username=user.username, password=password)
        if authed is None or not authed.is_active:
            raise serializers.ValidationError("Invalid email or password.")

        # Enforce role exclusivity for apps
        if app_role == "owner":
            if authed.role == "customer":
                raise serializers.ValidationError("This email is registered as a Customer. Please log in using the Stora Customer app.")
        elif app_role == "customer":
            if authed.role in ("owner", "admin"):
                raise serializers.ValidationError("This email is registered as a Store Owner. Please log in using the Stora Owner app.")

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
    store_avatar_url = serializers.SerializerMethodField()

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
            "bio",
            "owner",
            "store_name",
            "store_avatar_url",
        )
        read_only_fields = ("id", "owner", "store_name", "store_avatar_url")
        extra_kwargs = {
            "category": {"required": False},
            "barcode": {"required": False, "allow_null": True, "allow_blank": True},
            "bio": {"required": False, "allow_blank": True},
        }

    def get_store_avatar_url(self, obj):
        if obj.owner and obj.owner.avatar:
            request = self.context.get("request")
            if request:
                return request.build_absolute_uri(obj.owner.avatar.url)
            return obj.owner.avatar.url
        return None

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data["category_name"] = instance.category.name if instance.category else ""
        data["store_name"] = (instance.owner.business_name if instance.owner and instance.owner.business_name else (instance.owner.username if instance.owner else ""))
        data["bio"] = instance.bio or ""
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
    qr_code = serializers.SerializerMethodField()

    class Meta:
        model = SubscriptionConfig
        fields = ("monthly_price", "gcash_number", "gcash_name", "qr_code", "updated_at")

    def get_qr_code(self, instance):
        if instance.qr_code:
            request = self.context.get("request")
            if request:
                return request.build_absolute_uri(instance.qr_code.url)
            return instance.qr_code.url
        return None

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
    product_limit = serializers.IntegerField(allow_null=True)
    days_left = serializers.IntegerField()
    can_add_product = serializers.BooleanField()
    monthly_price = serializers.DecimalField(max_digits=8, decimal_places=2)
    gcash_number = serializers.CharField()
    gcash_name = serializers.CharField()
    qr_code = serializers.CharField(allow_null=True, required=False)
    latest_payment_proof = PaymentProofSerializer(allow_null=True, required=False)


class ForgotPasswordSerializer(serializers.Serializer):
    email = serializers.EmailField()

    def validate_email(self, value):
        return canonicalize_email(value)


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
    customer_avatar_url = serializers.SerializerMethodField()
    store_avatar_url = serializers.SerializerMethodField()
    store_name = serializers.CharField(source="owner.business_name", read_only=True, default="")

    class Meta:
        model = Order
        fields = (
            "id",
            "owner",
            "store_name",
            "store_avatar_url",
            "customer",
            "customer_name",
            "customer_avatar_url",
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
            "store_name",
            "store_avatar_url",
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

    def get_customer_avatar_url(self, obj):
        if obj.customer and obj.customer.avatar:
            request = self.context.get("request")
            if request:
                return request.build_absolute_uri(obj.customer.avatar.url)
            return obj.customer.avatar.url
        return None

    def get_store_avatar_url(self, obj):
        if obj.owner and obj.owner.avatar:
            request = self.context.get("request")
            if request:
                return request.build_absolute_uri(obj.owner.avatar.url)
            return obj.owner.avatar.url
        return None

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


class StoreLocationSerializer(serializers.ModelSerializer):
    class Meta:
        model = StoreLocation
        fields = ("id", "latitude", "longitude", "address", "is_visible", "updated_at")
        read_only_fields = ("id", "updated_at")


class AIInsightSerializer(serializers.ModelSerializer):
    created_at = UTCDateTimeField(read_only=True)

    class Meta:
        model = AIInsight
        fields = (
            "id",
            "title",
            "description",
            "category",
            "priority",
            "action_label",
            "action_target",
            "is_dismissed",
            "created_at",
        )
        read_only_fields = ("id", "created_at")


class ChatMessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.SerializerMethodField()
    sender_role = serializers.CharField(source="sender.role", read_only=True)
    recipient_name = serializers.SerializerMethodField()
    order_title = serializers.SerializerMethodField()
    image_url = serializers.SerializerMethodField()
    created_at = UTCDateTimeField(read_only=True)

    class Meta:
        model = ChatMessage
        fields = (
            "id",
            "sender",
            "sender_name",
            "sender_role",
            "recipient",
            "recipient_name",
            "order",
            "order_title",
            "message",
            "image",
            "image_url",
            "is_read",
            "created_at",
        )
        read_only_fields = ("id", "sender", "is_read", "created_at", "image_url")
        extra_kwargs = {
            "image": {"required": False, "allow_null": True},
            "message": {"required": False, "allow_blank": True},
            "order": {"required": False, "allow_null": True},
        }

    def get_sender_name(self, obj):
        if obj.sender.role == "owner":
            return obj.sender.business_name or f"{obj.sender.first_name} {obj.sender.last_name}".strip() or obj.sender.username
        return f"{obj.sender.first_name} {obj.sender.last_name}".strip() or obj.sender.username

    def get_recipient_name(self, obj):
        if obj.recipient.role == "owner":
            return obj.recipient.business_name or f"{obj.recipient.first_name} {obj.recipient.last_name}".strip() or obj.recipient.username
        return f"{obj.recipient.first_name} {obj.recipient.last_name}".strip() or obj.recipient.username

    def get_order_title(self, obj):
        if obj.order_id:
            return f"Order #{obj.order_id}"
        return None

    def get_image_url(self, obj):
        if obj.image:
            request = self.context.get("request")
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None


class BlockedCustomerSerializer(serializers.ModelSerializer):
    customer_email = serializers.CharField(source="customer.email", read_only=True)
    customer_name = serializers.SerializerMethodField()
    created_at = UTCDateTimeField(read_only=True)

    class Meta:
        model = BlockedCustomer
        fields = ("id", "owner", "customer", "customer_email", "customer_name", "created_at")
        read_only_fields = ("id", "owner", "created_at")

    def get_customer_name(self, obj):
        return f"{obj.customer.first_name} {obj.customer.last_name}".strip() or obj.customer.username


class UserReportSerializer(serializers.ModelSerializer):
    reporter = serializers.PrimaryKeyRelatedField(read_only=True)
    reporter_email = serializers.CharField(source="reporter.email", read_only=True)
    reporter_name = serializers.SerializerMethodField()
    reporter_role = serializers.CharField(source="reporter.role", read_only=True)

    reported_user = serializers.PrimaryKeyRelatedField(queryset=User.objects.all())
    reported_user_email = serializers.CharField(source="reported_user.email", read_only=True)
    reported_user_name = serializers.SerializerMethodField()
    reported_user_role = serializers.CharField(source="reported_user.role", read_only=True)

    reason_display = serializers.CharField(source="get_reason_display", read_only=True)
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    attachment_url = serializers.SerializerMethodField()
    created_at = UTCDateTimeField(read_only=True)

    class Meta:
        model = UserReport
        fields = (
            "id",
            "reporter",
            "reporter_email",
            "reporter_name",
            "reporter_role",
            "reported_user",
            "reported_user_email",
            "reported_user_name",
            "reported_user_role",
            "reason",
            "reason_display",
            "description",
            "order",
            "attachment",
            "attachment_url",
            "status",
            "status_display",
            "created_at",
        )
        read_only_fields = (
            "id",
            "reporter",
            "status",
            "created_at",
        )

    def get_reporter_name(self, obj):
        if obj.reporter.role == "owner":
            return obj.reporter.business_name or f"{obj.reporter.first_name} {obj.reporter.last_name}".strip() or obj.reporter.username
        return f"{obj.reporter.first_name} {obj.reporter.last_name}".strip() or obj.reporter.username

    def get_reported_user_name(self, obj):
        if obj.reported_user.role == "owner":
            return obj.reported_user.business_name or f"{obj.reported_user.first_name} {obj.reported_user.last_name}".strip() or obj.reported_user.username
        return f"{obj.reported_user.first_name} {obj.reported_user.last_name}".strip() or obj.reported_user.username

    def get_attachment_url(self, obj):
        if obj.attachment:
            request = self.context.get("request")
            if request:
                return request.build_absolute_uri(obj.attachment.url)
            return obj.attachment.url
        return None

    def validate(self, attrs):
        request = self.context.get("request")
        reporter = getattr(request, "user", None)
        reported_user = attrs.get("reported_user")

        if reported_user and (reported_user.is_staff or reported_user.is_superuser or getattr(reported_user, "role", None) == "admin"):
            raise serializers.ValidationError({"reported_user": "Administrative accounts cannot be reported."})

        if reporter and reported_user and reporter == reported_user:
            raise serializers.ValidationError({"reported_user": "You cannot file a report against yourself."})

        if reporter and getattr(reporter, "is_authenticated", False) and reported_user:
            # Check for existing pending report against the same user
            existing = UserReport.objects.filter(
                reporter=reporter,
                reported_user=reported_user,
                status=UserReport.STATUS_PENDING,
            ).exists()
            if existing:
                raise serializers.ValidationError({
                    "detail": "You already have a pending report against this user under review by our admin team."
                })

        order = attrs.get("order")
        if order and reporter and getattr(reporter, "is_authenticated", False):
            if reporter.id not in (order.owner_id, order.customer_id) or (reported_user and reported_user.id not in (order.owner_id, order.customer_id)):
                raise serializers.ValidationError({"order": "The specified order is not associated with this report."})

        return attrs



