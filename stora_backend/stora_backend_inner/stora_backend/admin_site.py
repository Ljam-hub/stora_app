"""
Custom Django AdminSite for Stora.

Django's default admin index is just an alphabetical app/model list. This
subclass injects the same at-a-glance numbers the app's own Dashboard
screen shows (today's earnings, stock levels, low-stock count, pending orders,
and unread support messages) above that list, via `stora_stats` in the template
context — see templates/admin/index.html.
Also provides a full Live Support Chat Center (`/admin/support/`) and real-time
unread badge API (`/admin/support/api/unread-count/`).
"""
from datetime import timedelta
from django.contrib.admin import AdminSite
from django.db.models import Sum, Q
from django.http import JsonResponse, HttpResponseBadRequest
from django.shortcuts import render, get_object_or_404
from django.urls import path
from django.utils import timezone


class StoraAdminSite(AdminSite):
    site_header = "STORA Admin"
    site_title = "STORA Admin"
    index_title = "Dashboard"

    def get_unread_support_count(self, request=None):
        from api.models import ChatMessage
        from accounts.models import User
        # Count all unread messages sent to admin/staff users by non-admin users
        return ChatMessage.objects.filter(
            Q(recipient__role=User.ROLE_ADMIN) | Q(recipient__is_superuser=True) | Q(recipient__is_staff=True),
            is_read=False,
            is_unsent=False,
        ).exclude(
            Q(sender__role=User.ROLE_ADMIN) | Q(sender__is_superuser=True)
        ).count()

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
            unread_support = self.get_unread_support_count(request)
        else:
            todays_sales = Sale.objects.filter(owner=user, created_at__date=today)
            products = Product.objects.filter(owner=user)
            pending_orders = Order.objects.filter(owner=user, status=Order.STATUS_PENDING)
            pending_requests = 0
            active_resets = 0
            unread_support = self.get_unread_support_count(request)

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
            "unread_support_count": unread_support,
        }
        extra_context["stora_unread_support_count"] = unread_support
        return super().index(request, extra_context)

    def each_context(self, request):
        context = super().each_context(request)
        context["stora_unread_support_count"] = self.get_unread_support_count(request)
        return context

    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path("support/", self.admin_view(self.support_chat_view), name="support_chat"),
            path("support/api/conversations/", self.admin_view(self.support_conversations_api), name="support_conversations_api"),
            path("support/api/messages/", self.admin_view(self.support_messages_api), name="support_messages_api"),
            path("support/api/send/", self.admin_view(self.support_send_api), name="support_send_api"),
            path("support/api/unread-count/", self.admin_view(self.support_unread_count_api), name="support_unread_count_api"),
        ]
        return custom_urls + urls

    def support_chat_view(self, request):
        context = {
            **self.each_context(request),
            "title": "Support Chat Center",
            "site_header": self.site_header,
        }
        return render(request, "admin/support_chat.html", context)

    def support_unread_count_api(self, request):
        count = self.get_unread_support_count(request)
        return JsonResponse({"unread_count": count})

    def support_conversations_api(self, request):
        from api.models import ChatMessage
        from accounts.models import User

        admin_users = User.objects.filter(Q(role=User.ROLE_ADMIN) | Q(is_superuser=True) | Q(is_staff=True))
        admin_ids = list(admin_users.values_list("id", flat=True))

        # Distinct partner user IDs who ever messaged admin or whom admin messaged
        sent_to_admin = ChatMessage.objects.filter(recipient_id__in=admin_ids).values_list("sender_id", flat=True)
        received_from_admin = ChatMessage.objects.filter(sender_id__in=admin_ids).values_list("recipient_id", flat=True)
        partner_ids = (set(sent_to_admin) | set(received_from_admin)) - set(admin_ids)

        all_users = User.objects.exclude(id__in=admin_ids).filter(is_active=True)

        conversations = []
        for partner in all_users:
            has_chatted = partner.id in partner_ids

            last_msg = ChatMessage.objects.filter(
                (Q(sender=partner) & Q(recipient_id__in=admin_ids)) |
                (Q(sender_id__in=admin_ids) & Q(recipient=partner))
            ).order_by("-created_at").first()

            unread_count = ChatMessage.objects.filter(
                sender=partner,
                recipient_id__in=admin_ids,
                is_read=False,
                is_unsent=False,
            ).count()

            avatar_url = request.build_absolute_uri(partner.avatar.url) if partner.avatar else None

            name = partner.get_display_name() if hasattr(partner, "get_display_name") else ""
            if not name:
                if partner.role == "owner" and partner.business_name:
                    name = partner.business_name
                else:
                    name = f"{partner.first_name} {partner.last_name}".strip() or partner.business_name or partner.username

            last_msg_text = ""
            if last_msg:
                if getattr(last_msg, "is_unsent", False):
                    last_msg_text = "Message was unsent"
                elif last_msg.image and not last_msg.message:
                    last_msg_text = "📷 Photo sent"
                elif last_msg.image and last_msg.message:
                    last_msg_text = f"📷 {last_msg.message}"
                else:
                    last_msg_text = last_msg.message

            conversations.append({
                "id": partner.id,
                "user_id": partner.id,
                "name": name,
                "business_name": partner.business_name or "",
                "email": partner.email,
                "role": partner.role,
                "role_label": "Store Owner" if partner.role == "owner" else ("Customer" if partner.role == "customer" else "User"),
                "avatar_url": avatar_url,
                "last_message": last_msg_text,
                "last_message_at": last_msg.created_at.isoformat() if last_msg else "",
                "last_message_is_support": (last_msg.sender_id in admin_ids) if last_msg else False,
                "unread_count": unread_count,
                "has_chatted": has_chatted,
                "is_active": partner.is_active,
            })

        # Sort: unread first, then latest message time, then has_chatted, then alphabetically
        conversations.sort(
            key=lambda x: (
                x["unread_count"] > 0,
                x["last_message_at"] or "",
                x["has_chatted"],
                x["name"].lower()
            ),
            reverse=True,
        )

        return JsonResponse({"conversations": conversations})

    def support_messages_api(self, request):
        from api.models import ChatMessage
        from accounts.models import User

        user_id = request.GET.get("user_id")
        if not user_id:
            return HttpResponseBadRequest("Missing user_id parameter")

        partner = get_object_or_404(User, pk=user_id)
        admin_users = User.objects.filter(Q(role=User.ROLE_ADMIN) | Q(is_superuser=True) | Q(is_staff=True))
        admin_ids = list(admin_users.values_list("id", flat=True))

        # Mark all incoming messages from this user to admin as read
        ChatMessage.objects.filter(
            sender=partner,
            recipient_id__in=admin_ids,
            is_read=False,
        ).update(is_read=True)

        messages_qs = ChatMessage.objects.filter(
            (Q(sender=partner) & Q(recipient_id__in=admin_ids)) |
            (Q(sender_id__in=admin_ids) & Q(recipient=partner))
        ).order_by("created_at")

        msg_list = []
        for m in messages_qs:
            is_support_reply = m.sender_id in admin_ids
            image_url = request.build_absolute_uri(m.image.url) if m.image else None
            msg_list.append({
                "id": m.id,
                "sender_id": m.sender_id,
                "sender_name": "STORA Support" if is_support_reply else (partner.get_display_name() if hasattr(partner, "get_display_name") else partner.username),
                "is_support": is_support_reply,
                "message": m.message,
                "image_url": image_url,
                "is_read": m.is_read,
                "is_unsent": getattr(m, "is_unsent", False),
                "created_at": m.created_at.strftime("%b %d, %Y %I:%M %p"),
                "iso_time": m.created_at.isoformat(),
            })

        partner_avatar = request.build_absolute_uri(partner.avatar.url) if partner.avatar else None
        partner_name = partner.get_display_name() if hasattr(partner, "get_display_name") else ""
        if not partner_name:
            partner_name = partner.business_name if partner.role == "owner" and partner.business_name else f"{partner.first_name} {partner.last_name}".strip() or partner.username

        return JsonResponse({
            "partner": {
                "id": partner.id,
                "name": partner_name,
                "business_name": partner.business_name or "",
                "email": partner.email,
                "role": partner.role,
                "role_label": "Store Owner" if partner.role == "owner" else ("Customer" if partner.role == "customer" else "User"),
                "avatar_url": partner_avatar,
                "is_active": partner.is_active,
            },
            "messages": msg_list,
        })

    def support_send_api(self, request):
        if request.method != "POST":
            return HttpResponseBadRequest("POST required")

        from api.models import ChatMessage
        from accounts.models import User
        from api.fcm import notify_new_chat_message

        recipient_id = request.POST.get("recipient_id")
        if not recipient_id:
            return HttpResponseBadRequest("Missing recipient_id")

        recipient = get_object_or_404(User, pk=recipient_id)
        msg_text = (request.POST.get("message") or "").strip()
        image = request.FILES.get("image")

        if not msg_text and not image:
            return HttpResponseBadRequest("Message cannot be empty")

        chat_msg = ChatMessage.objects.create(
            sender=request.user,
            recipient=recipient,
            message=msg_text,
            image=image,
        )

        try:
            notify_new_chat_message(chat_msg)
        except Exception:
            pass

        image_url = request.build_absolute_uri(chat_msg.image.url) if chat_msg.image else None
        return JsonResponse({
            "status": "success",
            "message": {
                "id": chat_msg.id,
                "sender_id": chat_msg.sender_id,
                "sender_name": "STORA Support",
                "is_support": True,
                "message": chat_msg.message,
                "image_url": image_url,
                "created_at": chat_msg.created_at.strftime("%b %d, %Y %I:%M %p"),
                "iso_time": chat_msg.created_at.isoformat(),
            }
        })


stora_admin_site = StoraAdminSite(name="stora_admin")
