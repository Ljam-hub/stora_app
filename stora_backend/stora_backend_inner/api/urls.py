from django.urls import include, path
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from . import views
from .serializers import CustomTokenObtainPairSerializer

router = DefaultRouter()
router.register("categories", views.CategoryViewSet, basename="category")
router.register("products", views.ProductViewSet, basename="product")
router.register("sales", views.SaleViewSet, basename="sale")
router.register("orders", views.OrderViewSet, basename="order")

urlpatterns = [
    # Health & System Status
    path("health/", views.health_check, name="health_check"),
    path("system/email-status/", views.system_email_status, name="system_email_status"),

    # Auth & Tokens
    path("auth/register/", views.register, name="register"),
    path("auth/verify-email/", views.verify_email, name="verify_email"),
    path("auth/resend-verification/", views.resend_verification_code, name="resend_verification_code"),
    path("auth/login/", views.login, name="login"),
    path("auth/token/", TokenObtainPairView.as_view(serializer_class=CustomTokenObtainPairSerializer), name="token_obtain_pair"),
    path("auth/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("auth/me/", views.me, name="me"),
    path("auth/change-password/", views.change_password, name="change_password"),
    path("auth/forgot-password/", views.forgot_password_request, name="forgot_password_request"),
    path("auth/reset-password/", views.forgot_password_confirm, name="forgot_password_confirm"),
    path("auth/fcm-token/", views.update_fcm_token, name="update_fcm_token"),
    path("users/me/fcm/", views.update_fcm_token, name="user_fcm_token"),

    # Account & Subscription
    path("account/status/", views.account_status, name="account_status"),
    path("subscription/status/", views.account_status, name="subscription_status"),
    path("subscription/config/", views.subscription_config, name="subscription_config"),
    path("subscription/upload-proof/", views.upload_payment_proof, name="upload_payment_proof"),

    # Products & Inventory
    path("products/barcode/<str:code>/", views.barcode_lookup, name="barcode_lookup"),
    path("stores/", views.list_stores, name="list_stores"),
    path("stores/my-location/", views.store_location, name="store_location"),

    # AI Insights
    path("ai/insights/", views.ai_store_insights, name="ai_store_insights"),
    path("ai/insights/<int:pk>/dismiss/", views.dismiss_ai_insight, name="dismiss_ai_insight"),

    # ViewSets (Categories, Products, Sales, Orders)
    path("", include(router.urls)),

]
