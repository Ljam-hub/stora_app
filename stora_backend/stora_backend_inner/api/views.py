from django.db import transaction
from rest_framework import status, viewsets
from rest_framework.decorators import action, api_view, parser_classes, permission_classes
from rest_framework.exceptions import PermissionDenied
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken

from .permissions import HasAssignedModelPermission

from django.conf import settings as django_settings
from django.contrib.auth.models import update_last_login
from django.core.mail import send_mail
from django.utils import timezone
from accounts.models import PasswordResetToken, PaymentProof, SubscriptionConfig, User
from inventory.models import MAX_STOCK, Category, Product
from orders.models import Order, OrderItem
from sales.models import Sale

from .fcm import notify_order_status_change
from .serializers import (
    AccountStatusSerializer,
    CategorySerializer,
    ChangePasswordSerializer,
    FCMTokenSerializer,
    ForgotPasswordSerializer,
    LoginSerializer,
    OrderCounterSerializer,
    OrderDeclineSerializer,
    OrderItemSerializer,
    OrderSerializer,
    PaymentProofSerializer,
    PaymentProofUploadSerializer,
    ProductSerializer,
    RegisterSerializer,
    ResetPasswordSerializer,
    SaleSerializer,
    SubscriptionConfigSerializer,
    UserSerializer,
    UserUpdateSerializer,
)


def _tokens_for(user):
    refresh = RefreshToken.for_user(user)
    refresh["role"] = getattr(user, "role", "owner")
    refresh["email"] = user.email
    refresh["business_name"] = getattr(user, "business_name", "")
    return {
        "access": str(refresh.access_token),
        "refresh": str(refresh),
        "user": UserSerializer(user).data,
    }


@api_view(["POST"])
@permission_classes([AllowAny])
def register(request):
    serializer = RegisterSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    user = serializer.save()
    update_last_login(None, user)
    return Response(_tokens_for(user), status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([AllowAny])
def login(request):
    serializer = LoginSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    user = serializer.validated_data["user"]
    update_last_login(None, user)
    return Response(_tokens_for(user))


@api_view(["GET", "PATCH", "PUT"])
@permission_classes([IsAuthenticated])
def me(request):
    if request.method in ["PATCH", "PUT"]:
        serializer = UserUpdateSerializer(request.user, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
    return Response(UserSerializer(request.user).data)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def change_password(request):
    serializer = ChangePasswordSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    user = request.user
    if not user.check_password(serializer.validated_data["old_password"]):
        return Response({"old_password": ["Current password is incorrect."]}, status=status.HTTP_400_BAD_REQUEST)
    user.set_password(serializer.validated_data["new_password"])
    user.save(update_fields=["password"])
    return Response({"detail": "Password has been changed successfully."})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def barcode_lookup(request, code):
    if not request.user.has_perm("inventory.view_product"):
        raise PermissionDenied("You do not have permission to perform this action.")
    try:
        product = Product.objects.get(owner=request.user, barcode=code)
    except Product.DoesNotExist:
        return Response({"detail": "No product found with that barcode."}, status=status.HTTP_404_NOT_FOUND)
    return Response(ProductSerializer(product, context={"request": request}).data)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def account_status(request):
    user = request.user
    product_count = Product.objects.filter(owner=user).count()
    free_limit = django_settings.FREE_PLAN_PRODUCT_LIMIT
    limit = 0 if user.is_premium_active else free_limit
    trial_ends = user.trial_ends_at
    if user.is_premium_active:
        days_left = (user.premium_until - timezone.now()).days if user.premium_until else 0
        can_add = True
    elif user.is_trial_active:
        days_left = (trial_ends - timezone.now()).days
        can_add = product_count < free_limit
    else:
        days_left = 0
        can_add = False

    config = SubscriptionConfig.get_config()
    latest_proof = user.payment_proofs.first()
    data = {
        "is_premium": user.is_premium_active,
        "premium_until": user.premium_until,
        "trial_started_at": user.date_joined,
        "trial_ends_at": trial_ends,
        "product_count": product_count,
        "product_limit": limit,
        "days_left": max(days_left, 0),
        "can_add_product": can_add,
        "monthly_price": config.monthly_price,
        "gcash_number": config.gcash_number,
        "gcash_name": config.gcash_name,
        "latest_payment_proof": latest_proof,
    }
    return Response(AccountStatusSerializer(data).data)


@api_view(["GET"])
@permission_classes([AllowAny])
def subscription_config(request):
    config = SubscriptionConfig.get_config()
    return Response(SubscriptionConfigSerializer(config).data)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
def upload_payment_proof(request):
    serializer = PaymentProofUploadSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    proof = PaymentProof.objects.create(
        user=request.user,
        reference_number=serializer.validated_data["reference_number"],
        amount=serializer.validated_data["amount"],
        screenshot=serializer.validated_data["screenshot"],
        status=PaymentProof.STATUS_PENDING,
    )

    # Trigger backend notification to admin
    admin_recipient = django_settings.DEFAULT_FROM_EMAIL or django_settings.EMAIL_HOST_USER
    if admin_recipient:
        send_mail(
            subject=f"[STORA ADMIN] New Account Request: Payment Proof from {request.user.email}",
            message=(
                f"Hello Admin,\n\n"
                f"A user has submitted a GCash subscription payment proof for account verification.\n\n"
                f"User: {request.user.email} ({request.user.business_name})\n"
                f"Reference Number: {proof.reference_number}\n"
                f"Amount: ₱{proof.amount:.2f}\n"
                f"Submitted At: {proof.submitted_at.strftime('%Y-%m-%d %H:%M:%S')}\n\n"
                f"Please review and approve this request in the Stora Admin dashboard:\n"
                f"/admin/accounts/paymentproof/\n\n"
                f"— STORA Automated Notification"
            ),
            from_email=django_settings.DEFAULT_FROM_EMAIL,
            recipient_list=[admin_recipient],
            fail_silently=True,
        )

    return Response(PaymentProofSerializer(proof).data, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([AllowAny])
def forgot_password_request(request):
    serializer = ForgotPasswordSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    email = serializer.validated_data["email"]
    # Always return 200 to prevent email enumeration
    try:
        user = User.objects.get(email__iexact=email)
        # Invalidate old tokens
        PasswordResetToken.objects.filter(user=user, used=False).update(used=True)
        token_obj = PasswordResetToken.objects.create(user=user)

        html_content = f"""
        <!DOCTYPE html>
        <html>
        <body style="font-family: Arial, sans-serif; background-color: #141018; color: #FFFFFF; padding: 24px;">
          <div style="max-width: 480px; margin: 0 auto; background-color: #1F1A28; border-radius: 16px; padding: 28px; border: 1px solid #332A40;">
            <div style="text-align: center; margin-bottom: 20px;">
              <h1 style="color: #FFFFFF; font-size: 24px; font-weight: 800; margin: 0;">STORA.</h1>
              <p style="color: #9B87F5; font-size: 13px; margin: 4px 0 0 0;">Inventory made simple</p>
            </div>
            <h2 style="color: #FFFFFF; font-size: 18px;">Password Reset Code</h2>
            <p style="color: #8E8798; font-size: 14px; line-height: 1.5;">
              We received a request to reset your password for your STORA account (<strong>{user.email}</strong>).
            </p>
            <div style="text-align: center; margin: 24px 0;">
              <div style="display: inline-block; background-color: #141018; border: 2px solid #9B87F5; border-radius: 12px; padding: 14px 28px;">
                <span style="font-size: 26px; font-weight: 800; letter-spacing: 4px; color: #B9A9FF;">{token_obj.token}</span>
              </div>
            </div>
            <p style="color: #8E8798; font-size: 13px;">
              This code will expire in <strong>1 hour</strong>. If you didn't request a password reset, you can safely ignore this email.
            </p>
            <hr style="border: 0; border-top: 1px solid #332A40; margin: 20px 0;" />
            <p style="color: #6E6678; font-size: 12px; text-align: center; margin: 0;">
              &copy; STORA. All rights reserved.
            </p>
          </div>
        </body>
        </html>
        """

        send_mail(
            subject="STORA — Password Reset Code",
            message=(
                f"Hello,\n\n"
                f"We received a request to reset your password for your STORA account ({user.email}).\n\n"
                f"Your reset code is: {token_obj.token}\n\n"
                f"This code will expire in 1 hour.\n\n"
                f"If you didn't request this, you can safely ignore this email.\n\n"
                f"— The STORA Team"
            ),
            from_email=django_settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            html_message=html_content,
            fail_silently=True,
        )
    except User.DoesNotExist:
        pass
    return Response({"detail": "If that email is registered, a reset code has been sent."})


@api_view(["POST"])
@permission_classes([AllowAny])
def forgot_password_confirm(request):
    serializer = ResetPasswordSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    token_str = serializer.validated_data["token"].strip()
    try:
        token_obj = PasswordResetToken.objects.select_related("user").get(
            token=token_str
        )
    except (PasswordResetToken.DoesNotExist, ValueError):
        return Response({"detail": "Invalid or expired reset code."}, status=status.HTTP_400_BAD_REQUEST)
    if not token_obj.is_valid():
        return Response({"detail": "This reset code has expired or was already used."}, status=status.HTTP_400_BAD_REQUEST)
    user = token_obj.user
    user.set_password(serializer.validated_data["new_password"])
    user.save(update_fields=["password"])
    token_obj.used = True
    token_obj.save(update_fields=["used"])
    return Response({"detail": "Password has been reset successfully. You can now log in."})


class OwnerQuerysetMixin:
    def get_queryset(self):
        user = self.request.user
        if getattr(user, "role", "owner") == "customer":
            owner_id = self.request.query_params.get("owner") or self.request.query_params.get("store")
            if owner_id:
                return super().get_queryset().filter(owner_id=owner_id)
            return super().get_queryset().all()
        return super().get_queryset().filter(owner=user)


class CategoryViewSet(OwnerQuerysetMixin, viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated, HasAssignedModelPermission]
    serializer_class = CategorySerializer
    queryset = Category.objects.all()

    def get_queryset(self):
        user = self.request.user
        if getattr(user, "role", "owner") == "customer":
            owner_id = self.request.query_params.get("owner") or self.request.query_params.get("store")
            qs = Category.objects.filter(is_archived=False, is_hidden=False)
            if owner_id:
                qs = qs.filter(owner_id=owner_id)
            return qs
        return super().get_queryset().filter(is_archived=False)

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

    def perform_destroy(self, instance):
        if instance.products.exists():
            instance.is_archived = True
            instance.is_hidden = True
            instance.save(update_fields=["is_archived", "is_hidden"])
            return
        instance.delete()


class ProductViewSet(OwnerQuerysetMixin, viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated, HasAssignedModelPermission]
    serializer_class = ProductSerializer
    queryset = Product.objects.select_related("category", "owner")

    def get_queryset(self):
        qs = super().get_queryset().select_related("category", "owner").order_by("created_at", "id")
        user = self.request.user
        if getattr(user, "role", "owner") != "customer":
            if not user.is_premium_active:
                free_limit = django_settings.FREE_PLAN_PRODUCT_LIMIT
                # If user is on the free plan, only the first 20 products are open
                return qs[:free_limit]
        return qs

    def perform_create(self, serializer):
        user = self.request.user
        free_limit = django_settings.FREE_PLAN_PRODUCT_LIMIT
        if not user.is_premium_active:
            if not user.is_trial_active:
                raise PermissionDenied(
                    "Your free trial has expired. Please upgrade to premium to add more products."
                )
            product_count = Product.objects.filter(owner=user).count()
            if product_count >= free_limit:
                raise PermissionDenied(
                    f"Free plan limit reached ({free_limit} products). Please upgrade to premium."
                )
        serializer.save(owner=user)

    @action(detail=True, methods=["patch"])
    def adjust_stock(self, request, pk=None):
        product = self.get_object()
        try:
            delta = int(request.data.get("delta", 0))
        except (TypeError, ValueError):
            return Response({"detail": "delta must be an integer."}, status=400)
        product.stock = max(0, min(MAX_STOCK, product.stock + delta))
        product.save(update_fields=["stock", "updated_at"])
        return Response(self.get_serializer(product).data)


class SaleViewSet(OwnerQuerysetMixin, viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated, HasAssignedModelPermission]
    serializer_class = SaleSerializer
    queryset = Sale.objects.prefetch_related("items")
    http_method_names = ["get", "post", "delete", "head", "options"]

    def get_queryset(self):
        user = self.request.user
        if getattr(user, "role", "owner") == "customer":
            raise PermissionDenied("Customers cannot access sales records.")
        return super().get_queryset()

    def perform_destroy(self, instance):
        with transaction.atomic():
            for item in instance.items.select_related("product"):
                product = item.product
                if product is None or product.owner_id != instance.owner_id:
                    continue
                product.stock = min(MAX_STOCK, product.stock + item.quantity)
                product.save(update_fields=["stock", "updated_at"])
            instance.delete()


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def update_fcm_token(request):
    serializer = FCMTokenSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    request.user.fcm_token = serializer.validated_data["fcm_token"]
    request.user.save(update_fields=["fcm_token"])
    return Response({"status": "success", "fcm_token": request.user.fcm_token})


class OrderViewSet(viewsets.ModelViewSet):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if getattr(user, "role", "owner") == "owner":
            return Order.objects.filter(owner=user).prefetch_related("items")
        else:
            return Order.objects.filter(customer=user).prefetch_related("items")

    def perform_create(self, serializer):
        order = serializer.save()
        notify_order_status_change(order, "created")

    @action(detail=True, methods=["post"])
    def accept(self, request, pk=None):
        order = self.get_object()
        if request.user != order.owner:
            raise PermissionDenied("Only the store owner can accept this order.")
        if order.status not in (Order.STATUS_PENDING, Order.STATUS_COUNTER_OFFER):
            return Response(
                {"error": f"Cannot accept order in '{order.status}' status."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            sale = order.accept()
        except ValueError as err:
            return Response(
                {"error": str(err)},
                status=status.HTTP_400_BAD_REQUEST,
            )
        notify_order_status_change(order, "accepted")
        return Response({
            "status": "accepted",
            "order": OrderSerializer(order).data,
            "sale_id": sale.id if sale else None,
        })

    @action(detail=True, methods=["post"])
    def decline(self, request, pk=None):
        order = self.get_object()
        if request.user != order.owner:
            raise PermissionDenied("Only the store owner can decline this order.")
        if order.status not in (Order.STATUS_PENDING, Order.STATUS_COUNTER_OFFER):
            return Response(
                {"error": f"Cannot decline order in '{order.status}' status."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        serializer = OrderDeclineSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        reason = serializer.validated_data.get("reason", "")
        order.decline(reason=reason, auto=False)
        notify_order_status_change(order, "declined")
        return Response({
            "status": "declined",
            "order": OrderSerializer(order).data,
        })

    @action(detail=True, methods=["post"])
    def counter(self, request, pk=None):
        order = self.get_object()
        if request.user != order.owner:
            raise PermissionDenied("Only the store owner can propose a counter-offer.")
        if order.status != Order.STATUS_PENDING:
            return Response(
                {"error": f"Cannot counter order in '{order.status}' status."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        serializer = OrderCounterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        notes = serializer.validated_data["notes"]
        counter_price = serializer.validated_data.get("counter_price")
        order.counter_offer(notes=notes, counter_price=counter_price)
        notify_order_status_change(order, "counter")
        return Response({
            "status": "counter_offer",
            "order": OrderSerializer(order).data,
        })


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def list_stores(request):
    owners = User.objects.filter(role="owner").values("id", "business_name", "email")
    return Response(list(owners))

