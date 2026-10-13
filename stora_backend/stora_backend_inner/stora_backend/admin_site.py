"""
Custom Django AdminSite for Stora.

Django's default admin index is just an alphabetical app/model list. This
subclass injects high-level platform administrative summaries (subscription revenue,
payment proofs awaiting review, user violation reports, pending orders, and platform GMV).

PRIVACY ARCHITECTURE NOTE (RA 10173 & Zero-Exploitation Policy):
- Store Owner Utang / Customer Credit ledgers are strictly private to merchants and are
  NOT aggregated or queryable in this Control Panel.
- End-to-end chat messages and support conversation centers are excluded from staff access.
- Temporary password reset credentials are excluded from staff access.
"""
from django.contrib.admin import AdminSite
from django.db.models import Sum
from django.http import JsonResponse
from django.urls import path
from django.utils import timezone


class StoraAdminSite(AdminSite):
    site_header = "STORA Admin"
    site_title = "STORA Admin"
    index_title = "Dashboard"

    def get_unread_support_count(self, request=None):
        return 0

    def get_admin_notifications_summary(self, request=None):
        from accounts.models import PaymentProof, User
        from api.models import UserReport
        from inventory.models import Product
        from orders.models import Order

        user = getattr(request, "user", None) if request else None
        is_admin = bool(
            user and user.is_authenticated and (user.is_superuser or user.is_staff or getattr(user, "role", None) == User.ROLE_ADMIN)
        )

        if is_admin:
            pending_reports = UserReport.objects.filter(status=UserReport.STATUS_PENDING).count()
            pending_payments = PaymentProof.objects.filter(status=PaymentProof.STATUS_PENDING).count()
            pending_orders = Order.objects.filter(status=Order.STATUS_PENDING).count()
            out_of_stock = Product.objects.filter(stock=0).count()
        elif user and user.is_authenticated:
            pending_reports = 0
            pending_payments = 0
            pending_orders = Order.objects.filter(owner=user, status=Order.STATUS_PENDING).count()
            out_of_stock = Product.objects.filter(owner=user, stock=0).count()
        else:
            pending_reports = 0
            pending_payments = 0
            pending_orders = 0
            out_of_stock = 0

        total_action = pending_reports + pending_payments + pending_orders

        return {
            "pending_reports_count": pending_reports,
            "pending_payments_count": pending_payments,
            "pending_orders_count": pending_orders,
            "unread_support_count": 0,
            "active_reset_requests": 0,
            "out_of_stock_count": out_of_stock,
            "overdue_credit_count": 0,
            "total_action_count": total_action,
        }

    def index(self, request, extra_context=None):
        from accounts.models import PaymentProof
        from inventory.models import Product
        from sales.models import Sale

        today = timezone.localdate()
        user = request.user
        notifs = self.get_admin_notifications_summary(request)
        is_admin_user = bool(user.is_superuser or getattr(user, "role", None) == "admin")

        if is_admin_user:
            todays_sales = Sale.objects.filter(created_at__date=today)
            products = Product.objects.all()
            total_sub_revenue = (
                PaymentProof.objects.filter(status=PaymentProof.STATUS_APPROVED).aggregate(total=Sum("amount"))["total"]
                or 0
            )
            month_sub_revenue = (
                PaymentProof.objects.filter(
                    status=PaymentProof.STATUS_APPROVED,
                    reviewed_at__year=today.year,
                    reviewed_at__month=today.month,
                ).aggregate(total=Sum("amount"))["total"]
                or 0
            )
            total_platform_gmv = Sale.objects.aggregate(total=Sum("total"))["total"] or 0
        else:
            todays_sales = Sale.objects.filter(owner=user, created_at__date=today)
            products = Product.objects.filter(owner=user)
            total_sub_revenue = (
                PaymentProof.objects.filter(user=user, status=PaymentProof.STATUS_APPROVED).aggregate(
                    total=Sum("amount")
                )["total"]
                or 0
            )
            month_sub_revenue = 0
            total_platform_gmv = Sale.objects.filter(owner=user).aggregate(total=Sum("total"))["total"] or 0

        extra_context = extra_context or {}
        extra_context["stora_notifications"] = notifs
        extra_context["stora_unread_support_count"] = 0
        extra_context["stora_stats"] = {
            "todays_total": todays_sales.aggregate(total=Sum("total"))["total"] or 0,
            "todays_count": todays_sales.count(),
            "total_stock": products.aggregate(total=Sum("stock"))["total"] or 0,
            "low_stock_count": products.filter(stock__lt=5).count(),
            "product_count": products.count(),
            "out_of_stock_count": notifs["out_of_stock_count"],
            "pending_reports_count": notifs["pending_reports_count"],
            "pending_requests": notifs["pending_payments_count"],
            "pending_orders_count": notifs["pending_orders_count"],
            "unread_support_count": 0,
            "active_reset_requests": 0,
            "overdue_credit_count": 0,
            "total_credit_receivables": 0,
            "active_credit_count": 0,
            "total_action_count": notifs["total_action_count"],
            "total_sub_revenue": total_sub_revenue,
            "month_sub_revenue": month_sub_revenue,
            "total_platform_gmv": total_platform_gmv,
            "is_platform_admin": is_admin_user,
        }
        return super().index(request, extra_context)

    def each_context(self, request):
        context = super().each_context(request)
        notifs = self.get_admin_notifications_summary(request)
        context["stora_notifications"] = notifs
        context["stora_unread_support_count"] = 0
        return context

    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path("api/notifications/summary/", self.admin_view(self.notifications_summary_api), name="notifications_summary_api"),
        ]
        return custom_urls + urls

    def notifications_summary_api(self, request):
        summary = self.get_admin_notifications_summary(request)
        return JsonResponse(summary)


stora_admin_site = StoraAdminSite(name="stora_admin")
