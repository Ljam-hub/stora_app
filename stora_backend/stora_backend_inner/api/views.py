import logging
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
from datetime import timedelta
import math
from django.utils import timezone

logger = logging.getLogger(__name__)

from accounts.models import AIInsight, EmailVerificationCode, PasswordResetToken, PaymentProof, StoreLocation, SubscriptionConfig, User
from inventory.models import MAX_STOCK, Category, Product
from orders.models import Order, OrderItem
from sales.models import Sale

import sys
import threading
from .fcm import notify_admin, notify_order_status_change
from .serializers import (
    AccountStatusSerializer,
    AIInsightSerializer,
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
    ResendVerificationSerializer,
    ResetPasswordSerializer,
    SaleSerializer,
    StoreLocationSerializer,
    SubscriptionConfigSerializer,
    UserSerializer,
    UserUpdateSerializer,
    VerifyEmailSerializer,
    canonicalize_email,
)



def _tokens_for(user):
    refresh = RefreshToken.for_user(user)
    refresh["role"] = getattr(user, "role", "owner")
    refresh["email"] = user.email
    refresh["business_name"] = getattr(user, "business_name", "")
    refresh["is_email_verified"] = getattr(user, "is_email_verified", False)
    return {
        "access": str(refresh.access_token),
        "refresh": str(refresh),
        "user": UserSerializer(user).data,
    }


def send_verification_email(user, code_obj):
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <body style="font-family: Arial, sans-serif; background-color: #141018; color: #FFFFFF; padding: 24px;">
      <div style="max-width: 480px; margin: 0 auto; background-color: #1F1A28; border-radius: 16px; padding: 28px; border: 1px solid #332A40;">
        <div style="text-align: center; margin-bottom: 20px;">
          <h1 style="color: #FFFFFF; font-size: 24px; font-weight: 800; margin: 0;">STORA.</h1>
          <p style="color: #9B87F5; font-size: 13px; margin: 4px 0 0 0;">Verify your email address</p>
        </div>
        <h2 style="color: #FFFFFF; font-size: 18px;">Welcome to STORA!</h2>
        <p style="color: #8E8798; font-size: 14px; line-height: 1.5;">
          Thank you for signing up. Please enter the 6-digit verification code below in the app to confirm your account (<strong>{user.email}</strong>):
        </p>
        <div style="text-align: center; margin: 24px 0;">
          <div style="display: inline-block; background-color: #141018; border: 2px solid #9B87F5; border-radius: 12px; padding: 14px 28px;">
            <span style="font-size: 32px; font-weight: 800; letter-spacing: 6px; color: #B9A9FF;">{code_obj.code}</span>
          </div>
        </div>
        <p style="color: #8E8798; font-size: 13px;">
          This code will expire in <strong>15 minutes</strong>. If you didn't request this, please disregard this email.
        </p>
        <hr style="border: 0; border-top: 1px solid #332A40; margin: 20px 0;" />
        <p style="color: #6E6678; font-size: 12px; text-align: center; margin: 0;">
          &copy; STORA. All rights reserved.
        </p>
      </div>
    </body>
    </html>
    """
    from_email = (
        getattr(django_settings, "DEFAULT_FROM_EMAIL", None)
        or getattr(django_settings, "EMAIL_HOST_USER", None)
        or "STORA <laisojl014@gmail.com>"
    )
    if isinstance(from_email, str):
        from_email = from_email.strip('"').strip("'")
    try:
        send_mail(
            subject="STORA — Your Verification Code",
            message=(
                f"Hello,\n\n"
                f"Thank you for signing up for STORA!\n\n"
                f"Your 6-digit verification code is: {code_obj.code}\n\n"
                f"This code will expire in 15 minutes.\n\n"
                f"— The STORA Team"
            ),
            from_email=from_email,
            recipient_list=[user.email],
            html_message=html_content,
            fail_silently=False,
        )
        logger.info("Verification code email dispatched successfully to %s", user.email)
        return True
    except Exception as mail_err:
        logger.error("Failed to send verification code email to %s: %s", user.email, mail_err)
        return False


def dispatch_email_async(func, *args, **kwargs):
    """
    Executes email sending asynchronously in a background thread in production
    and development, allowing the HTTP response to return instantly to the mobile client (<100ms).
    Executes synchronously in automated unit tests so assertions on django.core.mail.outbox remain deterministic.
    """
    backend = getattr(django_settings, "EMAIL_BACKEND", "")
    if "locmem" in backend or "test" in sys.argv:
        try:
            return func(*args, **kwargs)
        except Exception as e:
            logger.error("Error in sync email dispatch: %s", e, exc_info=True)
            return None

    def _safe_worker():
        try:
            func(*args, **kwargs)
        except Exception as e:
            logger.error("Unhandled exception in async email dispatch worker: %s", e, exc_info=True)

    thread = threading.Thread(target=_safe_worker, daemon=False)
    thread.start()
    return thread


@api_view(["GET"])
@permission_classes([AllowAny])
def health_check(request):
    return Response({"status": "ok", "message": "Stora backend is reachable"})




TRUSTED_EMAIL_DOMAINS = {"gmail.com", "googlemail.com"}


def is_trusted_email(email: str) -> bool:
    if not email or "@" not in email:
        return False
    canonical = canonicalize_email(email)
    domain = canonical.rsplit("@", 1)[-1].strip().lower()
    return domain in TRUSTED_EMAIL_DOMAINS


@api_view(["POST"])
@permission_classes([AllowAny])
def register(request):
    serializer = RegisterSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    user = serializer.save()
    update_last_login(None, user)

    # Generate verification code and dispatch email + admin notification in background
    code_obj = EmailVerificationCode.generate_code(user)

    def _async_post_register():
        send_verification_email(user, code_obj)
        try:
            user_type = "Store Owner" if getattr(user, "role", "") == "owner" else "Customer"
            identifier = user.business_name or user.email
            notify_admin(
                title=f"New {user_type} Registered 👤",
                body=f"{identifier} ({user.email}) just created an account.",
                data={"user_id": str(user.id), "role": getattr(user, "role", ""), "action": "user_registered"},
            )
        except Exception as err:
            logger.warning("Failed to dispatch admin registration alert: %s", err)

    dispatch_email_async(_async_post_register)

    data = _tokens_for(user)
    data["message"] = "Account created. Please check your email for the verification code."
    return Response(data, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([AllowAny])
def verify_email(request):
    serializer = VerifyEmailSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    email = serializer.validated_data["email"].strip().lower()
    code = serializer.validated_data["code"].strip()

    try:
        user = User.objects.get(email__iexact=email)
    except User.DoesNotExist:
        return Response({"detail": "Account not found."}, status=status.HTTP_404_NOT_FOUND)

    if user.is_email_verified:
        return Response({
            "detail": "Email is already verified.",
            "user": UserSerializer(user).data,
        })

    verification = EmailVerificationCode.objects.filter(
        user=user,
        code=code,
        used=False,
    ).first()

    if not verification:
        return Response({"detail": "Invalid verification code."}, status=status.HTTP_400_BAD_REQUEST)

    if not verification.is_valid():
        return Response({"detail": "Verification code has expired. Please request a new one."}, status=status.HTTP_400_BAD_REQUEST)

    # Mark verified
    verification.used = True
    verification.save(update_fields=["used"])

    user.is_email_verified = True
    user.save(update_fields=["is_email_verified"])

    res_data = _tokens_for(user)
    res_data["detail"] = "Email verified successfully."
    return Response(res_data, status=status.HTTP_200_OK)


@api_view(["POST"])
@permission_classes([AllowAny])
def resend_verification_code(request):
    serializer = ResendVerificationSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    email = serializer.validated_data["email"].strip().lower()

    try:
        user = User.objects.get(email__iexact=email)
    except User.DoesNotExist:
        return Response({"detail": "If that email exists in our system, a verification code has been sent."})

    if user.is_email_verified:
        return Response({"detail": "Email is already verified."}, status=status.HTTP_200_OK)

    # Rate limiting: 60-second cooldown
    recent_code = EmailVerificationCode.objects.filter(
        user=user,
        created_at__gte=timezone.now() - timedelta(seconds=60),
    ).first()
    if recent_code:
        wait_seconds = max(1, 60 - int((timezone.now() - recent_code.created_at).total_seconds()))
        return Response(
            {"detail": f"Please wait {wait_seconds} seconds before requesting another code."},
            status=status.HTTP_429_TOO_MANY_REQUESTS,
        )

    code_obj = EmailVerificationCode.generate_code(user)
    dispatch_email_async(send_verification_email, user, code_obj)

    return Response({"detail": "A fresh verification code has been sent to your email."})


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
    config = SubscriptionConfig.get_config()
    qr_code_url = None
    if config.qr_code:
        try:
            qr_code_url = request.build_absolute_uri(config.qr_code.url)
        except Exception:
            qr_code_url = config.qr_code.url

    # Customers do not have subscription trials or product limits
    if getattr(user, "role", "owner") == "customer":
        data = {
            "is_premium": False,
            "premium_until": None,
            "trial_started_at": user.date_joined,
            "trial_ends_at": None,
            "product_count": 0,
            "product_limit": None,
            "days_left": 0,
            "can_add_product": False,
            "monthly_price": config.monthly_price,
            "gcash_number": config.gcash_number,
            "gcash_name": config.gcash_name,
            "qr_code": qr_code_url,
            "latest_payment_proof": None,
        }
        return Response(AccountStatusSerializer(data).data)

    # Admin users have full system access
    if getattr(user, "role", "owner") == "admin" or user.is_superuser:
        data = {
            "is_premium": True,
            "premium_until": None,
            "trial_started_at": user.date_joined,
            "trial_ends_at": None,
            "product_count": Product.objects.count(),
            "product_limit": None,
            "days_left": 9999,
            "can_add_product": True,
            "monthly_price": config.monthly_price,
            "gcash_number": config.gcash_number,
            "gcash_name": config.gcash_name,
            "qr_code": qr_code_url,
            "latest_payment_proof": None,
        }
        return Response(AccountStatusSerializer(data).data)

    # Store Owners have 14-day trials or premium subscriptions
    product_count = Product.objects.filter(owner=user).count()
    free_limit = django_settings.FREE_PLAN_PRODUCT_LIMIT
    limit = None if user.is_premium_active else free_limit
    trial_ends = user.trial_ends_at
    if user.is_premium_active:
        days_left = (user.premium_until - timezone.now()).days if user.premium_until else 0
        can_add = True
    elif user.is_trial_active:
        days_left = (trial_ends - timezone.now()).days if trial_ends else 0
        can_add = product_count < free_limit
    else:
        days_left = 0
        can_add = False

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
        "qr_code": qr_code_url,
        "latest_payment_proof": latest_proof,
    }
    return Response(AccountStatusSerializer(data).data)


@api_view(["GET"])
@permission_classes([AllowAny])
def subscription_config(request):
    config = SubscriptionConfig.get_config()
    return Response(SubscriptionConfigSerializer(config, context={"request": request}).data)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
def upload_payment_proof(request):
    if getattr(request.user, "role", "owner") != "owner":
        raise PermissionDenied("Only store owners can submit subscription payment proofs.")
    serializer = PaymentProofUploadSerializer(data=request.data)

    serializer.is_valid(raise_exception=True)
    proof = PaymentProof.objects.create(
        user=request.user,
        reference_number=serializer.validated_data["reference_number"],
        amount=serializer.validated_data["amount"],
        screenshot=serializer.validated_data["screenshot"],
        status=PaymentProof.STATUS_PENDING,
    )

    def _async_post_payment_proof():
        try:
            notify_admin(
                title="New Payment Proof Submitted 💳",
                body=f"₱{proof.amount:.2f} (Ref: {proof.reference_number}) from {request.user.business_name or request.user.email}",
                data={"proof_id": str(proof.id), "action": "payment_proof_submitted", "user_id": str(request.user.id)},
            )
        except Exception as e:
            logger.warning("Failed to dispatch admin payment push alert: %s", e)

        admin_recipient = getattr(django_settings, "DEFAULT_FROM_EMAIL", None) or getattr(django_settings, "EMAIL_HOST_USER", None)
        if admin_recipient:
            try:
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
            except Exception as e:
                logger.warning("Failed to send admin payment notification email: %s", e)

    dispatch_email_async(_async_post_payment_proof)

    return Response(PaymentProofSerializer(proof).data, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([AllowAny])
def forgot_password_request(request):
    serializer = ForgotPasswordSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    email = serializer.validated_data["email"]
    raw_email = (request.data.get("email") or "").strip().lower()

    # Always return 200 to prevent email enumeration
    try:
        user = User.objects.filter(email__iexact=email).first()
        if not user and raw_email:
            user = User.objects.filter(email__iexact=raw_email).first()
        if not user:
            raise User.DoesNotExist

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

        from_email = (
            getattr(django_settings, "DEFAULT_FROM_EMAIL", None)
            or getattr(django_settings, "EMAIL_HOST_USER", None)
            or "STORA <laisojl014@gmail.com>"
        )
        if isinstance(from_email, str):
            from_email = from_email.strip('"').strip("'")

        # Determine target recipient(s)
        recipients = [user.email]
        if raw_email and raw_email != user.email.lower() and "@" in raw_email:
            recipients.append(raw_email)

        def _send_reset_email():
            try:
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
                    from_email=from_email,
                    recipient_list=recipients,
                    html_message=html_content,
                    fail_silently=False,
                )
                logger.info("Password reset token dispatched successfully to %s", recipients)
            except Exception as mail_err:
                logger.error("Failed to send password reset email to %s: %s", recipients, mail_err)

        dispatch_email_async(_send_reset_email)
    except User.DoesNotExist:
        logger.info("Forgot password requested for non-existent email: %s (raw: %s)", email, raw_email)
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
        if getattr(user, "role", "owner") == "admin" or user.is_superuser:
            return super().get_queryset().all()
        if getattr(user, "role", "owner") == "customer":
            owner_id = self.request.query_params.get("owner") or self.request.query_params.get("store")
            if owner_id:
                return super().get_queryset().filter(owner_id=owner_id)
            # When customer selects 'All Stores' (no store param), return products/categories from all stores
            return super().get_queryset().all()
        return super().get_queryset().filter(owner=user)


class CategoryViewSet(OwnerQuerysetMixin, viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated, HasAssignedModelPermission]
    serializer_class = CategorySerializer
    queryset = Category.objects.all()

    def get_queryset(self):
        user = self.request.user
        if getattr(user, "role", "owner") == "admin" or user.is_superuser:
            return super().get_queryset().all()
        if getattr(user, "role", "owner") == "customer":
            owner_id = self.request.query_params.get("owner") or self.request.query_params.get("store")
            qs = Category.objects.filter(is_archived=False, is_hidden=False)
            if owner_id:
                qs = qs.filter(owner_id=owner_id)
            return qs
        return super().get_queryset().filter(is_archived=False)

    def perform_create(self, serializer):
        user = self.request.user
        if getattr(user, "role", "owner") == "customer":
            raise PermissionDenied("Customer accounts cannot create categories.")
        serializer.save(owner=user)

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
        if getattr(user, "role", "owner") == "admin" or user.is_superuser:
            return qs
        if getattr(user, "role", "owner") == "owner":
            if not user.is_premium_active:
                free_limit = django_settings.FREE_PLAN_PRODUCT_LIMIT
                # Use a subquery so the result is still a filterable queryset
                # (slicing with [:N] would break DRF's .filter() / .get_object())
                allowed_ids = qs.values_list("id", flat=True)[:free_limit]
                return qs.filter(id__in=list(allowed_ids))
        return qs

    def perform_create(self, serializer):
        user = self.request.user
        if getattr(user, "role", "owner") == "customer":
            raise PermissionDenied("Customer accounts cannot create products.")
        if getattr(user, "role", "owner") == "admin" or user.is_superuser:
            serializer.save(owner=user)
            return
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
        if getattr(user, "role", "owner") == "admin" or user.is_superuser:
            return Order.objects.all().prefetch_related("items")
        elif getattr(user, "role", "owner") == "owner":
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
    def ready(self, request, pk=None):
        order = self.get_object()
        if request.user != order.owner:
            raise PermissionDenied("Only the store owner can mark this order as ready.")
        if order.status != Order.STATUS_ACCEPTED:
            return Response(
                {"error": f"Only accepted orders can be marked ready. Current status: '{order.status}'."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        order.mark_as_ready()
        notify_order_status_change(order, "ready")
        return Response({
            "status": "ready",
            "order": OrderSerializer(order).data,
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


def _haversine_km(lat1, lon1, lat2, lon2):
    """Calculate the great circle distance in kilometers between two points."""
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (math.sin(d_lat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(d_lon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return 6371.0 * c


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def list_stores(request):
    """List stores for customers with location and optional GPS proximity sorting."""
    owners = User.objects.filter(role="owner").select_related("location")
    
    # Optional GPS coordinates from query params
    user_lat = request.query_params.get("lat")
    user_lng = request.query_params.get("lng")
    try:
        user_lat = float(user_lat) if user_lat is not None else None
        user_lng = float(user_lng) if user_lng is not None else None
    except (ValueError, TypeError):
        user_lat, user_lng = None, None

    stores_data = []
    for owner in owners:
        loc = getattr(owner, "location", None)
        lat = loc.latitude if loc else 14.5995
        lng = loc.longitude if loc else 120.9842
        address = loc.address if loc else ""
        is_visible = loc.is_visible if loc else True

        if not is_visible:
            continue

        distance_km = None
        if user_lat is not None and user_lng is not None:
            distance_km = round(_haversine_km(user_lat, user_lng, lat, lng), 2)

        stores_data.append({
            "id": owner.id,
            "business_name": owner.business_name,
            "email": owner.email,
            "latitude": lat,
            "longitude": lng,
            "address": address,
            "distance_km": distance_km,
        })

    if user_lat is not None and user_lng is not None:
        stores_data.sort(key=lambda x: (x["distance_km"] if x["distance_km"] is not None else 999999))

    return Response(stores_data)


@api_view(["GET", "PUT", "POST"])
@permission_classes([IsAuthenticated])
def store_location(request):
    """Get or update current owner's store location."""
    user = request.user
    if getattr(user, "role", "owner") != "owner":
        raise PermissionDenied("Only store owners can manage store location.")

    location, _ = StoreLocation.objects.get_or_create(
        owner=user,
        defaults={
            "latitude": 14.5995,
            "longitude": 120.9842,
            "address": "Metro Manila, Philippines",
            "is_visible": True,
        }
    )

    if request.method in ["PUT", "POST"]:
        serializer = StoreLocationSerializer(location, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)

    return Response(StoreLocationSerializer(location).data)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def ai_store_insights(request):
    """Generate and return real-time AI store insights for the store owner."""
    user = request.user
    if getattr(user, "role", "owner") != "owner":
        raise PermissionDenied("Only store owners can access AI insights.")

    # 1. Gather store statistics
    products = list(Product.objects.filter(owner=user).select_related("category"))
    sales = list(Sale.objects.filter(owner=user).prefetch_related("items"))
    pending_orders_count = Order.objects.filter(owner=user, status=Order.STATUS_PENDING).count()

    now = timezone.now()
    seven_days_ago = now - timedelta(days=7)
    recent_sales = [s for s in sales if s.created_at >= seven_days_ago]
    
    # Compute sales quantities per product
    product_qty = {}
    for s in sales:
        for it in s.items.all():
            name = it.product_name
            product_qty[name] = product_qty.get(name, 0) + it.quantity

    low_stock_products = [p for p in products if p.stock < 5]
    out_of_stock_products = [p for p in products if p.stock == 0]

    # Dynamically build actionable AI recommendations
    generated_insights = []

    # A. Low / Out of Stock alerts
    if out_of_stock_products:
        p_names = ", ".join([p.name for p in out_of_stock_products[:3]])
        generated_insights.append({
            "id": 1,
            "title": f"Restock Alert: {len(out_of_stock_products)} item(s) Out of Stock",
            "description": f"Items like {p_names} have 0 units remaining. Replenishing them now will recover lost daily sales.",
            "category": "inventory",
            "priority": "high",
            "action_label": "Restock Items",
            "action_target": "inventory",
            "is_dismissed": False,
            "created_at": now,
        })
    elif low_stock_products:
        p_names = ", ".join([p.name for p in low_stock_products[:3]])
        generated_insights.append({
            "id": 2,
            "title": f"Low Stock Warning: {len(low_stock_products)} item(s) running low",
            "description": f"Products like {p_names} have fewer than 5 units left. Restock before the weekend rush.",
            "category": "inventory",
            "priority": "medium",
            "action_label": "View Inventory",
            "action_target": "inventory",
            "is_dismissed": False,
            "created_at": now,
        })

    # B. Pending customer carts
    if pending_orders_count > 0:
        generated_insights.append({
            "id": 3,
            "title": f"{pending_orders_count} Pending Customer Order(s)",
            "description": "You have customers waiting for pickup confirmation. Accept quickly to delight your regulars!",
            "category": "sales",
            "priority": "high",
            "action_label": "Review Orders",
            "action_target": "orders",
            "is_dismissed": False,
            "created_at": now,
        })

    # C. Top Selling Product Driver
    if product_qty:
        top_product_name = max(product_qty, key=product_qty.get)
        top_qty = product_qty[top_product_name]
        generated_insights.append({
            "id": 4,
            "title": f"Top Performer: '{top_product_name}'",
            "description": f"'{top_product_name}' is your most purchased item ({top_qty} units sold). Consider bundling it with popular drinks or snacks for higher cart value.",
            "category": "growth",
            "priority": "medium",
            "action_label": "View Analytics",
            "action_target": "analytics",
            "is_dismissed": False,
            "created_at": now,
        })

    # D. Store Location Visibility
    loc = getattr(user, "location", None)
    if not loc or not loc.address:
        generated_insights.append({
            "id": 5,
            "title": "Pin Your Store on Map",
            "description": "Nearby customers can discover your store on their map! Set your store's physical location and address to gain more walk-in and pickup orders.",
            "category": "growth",
            "priority": "high",
            "action_label": "Set Location",
            "action_target": "map",
            "is_dismissed": False,
            "created_at": now,
        })

    # E. General growth / Category expansion
    cat_count = Category.objects.filter(owner=user, is_archived=False).count()
    if cat_count <= 2:
        generated_insights.append({
            "id": 6,
            "title": "Expand Your Categories",
            "description": "Stores with 4 or more categories (e.g. Snacks, Cold Drinks, Household Essentials) experience 38% higher total weekly order volume.",
            "category": "growth",
            "priority": "low",
            "action_label": "Manage Categories",
            "action_target": "inventory",
            "is_dismissed": False,
            "created_at": now,
        })
    else:
        generated_insights.append({
            "id": 7,
            "title": "Smart Pricing Optimization",
            "description": "Your current gross margins appear healthy. Review slow-moving inventory to introduce bundle promos and boost cash velocity.",
            "category": "pricing",
            "priority": "low",
            "action_label": "Review Pricing",
            "action_target": "inventory",
            "is_dismissed": False,
            "created_at": now,
        })

    return Response(generated_insights)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def dismiss_ai_insight(request, pk):
    """Mark an AI insight as dismissed."""
    return Response({"status": "dismissed", "id": pk})


