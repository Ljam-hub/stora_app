"""
Custom Django AdminSite for Stora.

Django's default admin index is just an alphabetical app/model list. This
subclass injects the same at-a-glance numbers the app's own Dashboard
screen shows (today's earnings, stock levels, low-stock count, pending orders)
above that list, via `stora_stats` in the template context — see
templates/admin/index.html.
"""
from datetime import timedelta
from django.contrib.admin import AdminSite
from django.db.models import Sum
from django.utils import timezone


class StoraAdminSite(AdminSite):
    site_header = "STORA Admin"
    site_title = "STORA Admin"
    index_title = "Dashboard"

    def index(self, request, extra_context=None):
        from accounts.models import PasswordResetToken, PaymentProof
        from inventory.models import Product
        from orders.models import Order
        from sales.models import Sale

        today = timezone.localdate()
        user = request.user

        if user.is_superuser:
            todays_sales = Sale.objects.filter(created_at__date=today)
            products = Product.objects.all()
            pending_orders = Order.objects.filter(status=Order.STATUS_PENDING)
            pending_requests = PaymentProof.objects.filter(status="pending").count()
            active_resets = PasswordResetToken.objects.filter(
                used=False,
                created_at__gte=timezone.now() - timedelta(hours=1),
            ).count()
        else:
            todays_sales = Sale.objects.filter(owner=user, created_at__date=today)
            products = Product.objects.filter(owner=user)
            pending_orders = Order.objects.filter(owner=user, status=Order.STATUS_PENDING)
            pending_requests = 0
            active_resets = 0

        extra_context = extra_context or {}
        extra_context["stora_stats"] = {
            "todays_total": todays_sales.aggregate(total=Sum("total"))["total"] or 0,
            "todays_count": todays_sales.count(),
            "total_stock": products.aggregate(total=Sum("stock"))["total"] or 0,
            "low_stock_count": products.filter(stock__lt=5).count(),
            "product_count": products.count(),
            "pending_orders_count": pending_orders.count(),
            "pending_requests": pending_requests,
            "active_reset_requests": active_resets,
        }
        return super().index(request, extra_context)


stora_admin_site = StoraAdminSite(name="stora_admin")
