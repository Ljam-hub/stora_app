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
        qs = ChatMessage.objects.filter(
            Q(recipient__role=User.ROLE_ADMIN) | Q(recipient__is_superuser=True) | Q(recipient__is_staff=True),
            is_read=False,
            is_unsent=False,
        ).exclude(
            Q(sender__role=User.ROLE_ADMIN) | Q(sender__is_superuser=True)
        )
        if request and getattr(request, "user", None) and request.user.is_authenticated:
            qs = qs.exclude(deleted_by_users=request.user)
        return qs.count()

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
            path("support/api/messages/<int:message_id>/unsend/", self.admin_view(self.support_unsend_message_api), name="support_unsend_message_api"),
            path("support/api/messages/<int:message_id>/delete/", self.admin_view(self.support_delete_message_api), name="support_delete_message_api"),
            path("support/api/conversations/<int:partner_id>/delete/", self.admin_view(self.support_delete_conversation_api), name="support_delete_conversation_api"),
            path("support/api/avatar/", self.admin_view(self.support_avatar_api), name="support_avatar_api"),
            path("support/api/send/", self.admin_view(self.support_send_api), name="support_send_api"),
            path("support/api/unread-count/", self.admin_view(self.support_unread_count_api), name="support_unread_count_api"),
        ]
        return custom_urls + urls

    def support_chat_view(self, request):
        from api.views import get_support_user
        sup = get_support_user()
        support_avatar = None
        if request.user.avatar:
            support_avatar = request.build_absolute_uri(request.user.avatar.url)
        elif sup and sup.avatar:
            support_avatar = request.build_absolute_uri(sup.avatar.url)

        context = {
            **self.each_context(request),
            "title": "Support Chat Center",
            "site_header": self.site_header,
            "stora_support_avatar": support_avatar,
            "stora_support_email": request.user.email,
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
        sent_to_admin = ChatMessage.objects.filter(recipient_id__in=admin_ids).exclude(deleted_by_users=request.user).values_list("sender_id", flat=True)
        received_from_admin = ChatMessage.objects.filter(sender_id__in=admin_ids).exclude(deleted_by_users=request.user).values_list("recipient_id", flat=True)
        partner_ids = (set(sent_to_admin) | set(received_from_admin)) - set(admin_ids)

        all_users = User.objects.exclude(id__in=admin_ids).filter(is_active=True)

        conversations = []
        for partner in all_users:
            has_chatted = partner.id in partner_ids

            last_msg = ChatMessage.objects.filter(
                (Q(sender=partner) & Q(recipient_id__in=admin_ids)) |
                (Q(sender_id__in=admin_ids) & Q(recipient=partner))
            ).exclude(deleted_by_users=request.user).order_by("-created_at").first()

            unread_count = ChatMessage.objects.filter(
                sender=partner,
                recipient_id__in=admin_ids,
                is_read=False,
                is_unsent=False,
            ).exclude(deleted_by_users=request.user).count()

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

            last_msg_time = ""
            last_msg_at_iso = ""
            if last_msg and last_msg.created_at:
                local_dt = timezone.localtime(last_msg.created_at)
                last_msg_at_iso = local_dt.isoformat()
                now_dt = timezone.localtime(timezone.now())
                if local_dt.date() == now_dt.date():
                    last_msg_time = local_dt.strftime("%I:%M %p").lstrip("0")
                elif local_dt.year == now_dt.year:
                    last_msg_time = local_dt.strftime("%b %d")
                else:
                    last_msg_time = local_dt.strftime("%b %d, %Y")

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
                "last_message_at": last_msg_at_iso,
                "last_message_time": last_msg_time,
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

        support_avatar = request.build_absolute_uri(request.user.avatar.url) if request.user.avatar else None
        if not support_avatar:
            from api.views import get_support_user
            sup = get_support_user()
            if sup and sup.avatar:
                support_avatar = request.build_absolute_uri(sup.avatar.url)

        partner_avatar = request.build_absolute_uri(partner.avatar.url) if partner.avatar else None
        partner_name = partner.get_display_name() if hasattr(partner, "get_display_name") else ""
        if not partner_name:
            partner_name = partner.business_name if partner.role == "owner" and partner.business_name else f"{partner.first_name} {partner.last_name}".strip() or partner.username

        messages_qs = ChatMessage.objects.filter(
            (Q(sender=partner) & Q(recipient_id__in=admin_ids)) |
            (Q(sender_id__in=admin_ids) & Q(recipient=partner))
        ).exclude(deleted_by_users=request.user).order_by("created_at")

        msg_list = []
        for m in messages_qs:
            is_support_reply = m.sender_id in admin_ids
            image_url = request.build_absolute_uri(m.image.url) if m.image else None
            local_dt = timezone.localtime(m.created_at) if m.created_at else None
            time_display = local_dt.strftime("%I:%M %p").lstrip("0") if local_dt else ""
            full_display = (local_dt.strftime("%b %d, %Y ") + time_display) if local_dt else ""
            msg_list.append({
                "id": m.id,
                "sender_id": m.sender_id,
                "sender_name": "STORA Support" if is_support_reply else (partner.get_display_name() if hasattr(partner, "get_display_name") else partner.username),
                "sender_avatar_url": support_avatar if is_support_reply else partner_avatar,
                "is_support": is_support_reply,
                "message": m.message,
                "image_url": image_url,
                "is_read": m.is_read,
                "is_unsent": getattr(m, "is_unsent", False),
                "created_at": time_display,
                "full_date": full_display,
                "iso_time": local_dt.isoformat() if local_dt else "",
            })

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
            "support": {
                "name": "STORA Support",
                "email": request.user.email,
                "avatar_url": support_avatar,
            },
            "messages": msg_list,
        })

    def support_unsend_message_api(self, request, message_id):
        if request.method != "POST":
            return HttpResponseBadRequest("POST required")
        from api.models import ChatMessage
        from accounts.models import User
        msg = get_object_or_404(ChatMessage, pk=message_id)

        admin_users = User.objects.filter(Q(role=User.ROLE_ADMIN) | Q(is_superuser=True) | Q(is_staff=True))
        admin_ids = list(admin_users.values_list("id", flat=True))

        # Admin can unsend messages sent by admin
        if msg.sender_id not in admin_ids and msg.sender != request.user:
            return JsonResponse({"error": "Can only unsend STORA Support messages."}, status=403)

        if msg.image:
            try:
                msg.image.delete(save=False)
            except Exception:
                pass
            msg.image = None
        msg.is_unsent = True
        msg.message = "This message was unsent"
        msg.save(update_fields=["is_unsent", "message", "image"])
        return JsonResponse({"status": "success", "message_id": message_id, "is_unsent": True})

    def support_delete_message_api(self, request, message_id):
        if request.method not in ("POST", "DELETE"):
            return HttpResponseBadRequest("POST or DELETE required")
        from api.models import ChatMessage
        msg = get_object_or_404(ChatMessage, pk=message_id)
        action = request.POST.get("action") or request.GET.get("action") or "remove_for_me"

        if action == "unsend":
            from accounts.models import User
            admin_users = User.objects.filter(Q(role=User.ROLE_ADMIN) | Q(is_superuser=True) | Q(is_staff=True))
            admin_ids = list(admin_users.values_list("id", flat=True))
            if msg.sender_id not in admin_ids and msg.sender != request.user:
                return JsonResponse({"error": "Can only unsend STORA Support messages."}, status=403)

            if msg.image:
                try:
                    msg.image.delete(save=False)
                except Exception:
                    pass
                msg.image = None
            msg.is_unsent = True
            msg.message = "This message was unsent"
            msg.save(update_fields=["is_unsent", "message", "image"])
            return JsonResponse({"status": "success", "message_id": message_id, "is_unsent": True})

        # Remove for me only (partner can still see it)
        msg.deleted_by_users.add(request.user)
        return JsonResponse({"status": "success", "message_id": message_id, "action": "remove_for_me"})

    def support_delete_conversation_api(self, request, partner_id):
        if request.method not in ("POST", "DELETE"):
            return HttpResponseBadRequest("POST or DELETE required")
        from api.models import ChatMessage
        from accounts.models import User
        partner = get_object_or_404(User, pk=partner_id)
        admin_users = User.objects.filter(Q(role=User.ROLE_ADMIN) | Q(is_superuser=True) | Q(is_staff=True))
        admin_ids = list(admin_users.values_list("id", flat=True))

        msgs = ChatMessage.objects.filter(
            (Q(sender=partner) & Q(recipient_id__in=admin_ids)) |
            (Q(sender_id__in=admin_ids) & Q(recipient=partner))
        ).exclude(deleted_by_users=request.user)

        msg_ids = list(msgs.values_list("id", flat=True))
        if msg_ids:
            through = ChatMessage.deleted_by_users.through
            existing = set(
                through.objects.filter(user=request.user, chatmessage_id__in=msg_ids).values_list("chatmessage_id", flat=True)
            )
            new_records = [through(user=request.user, chatmessage_id=mid) for mid in msg_ids if mid not in existing]
            if new_records:
                through.objects.bulk_create(new_records)

        return JsonResponse({"status": "success", "partner_id": partner_id, "deleted_count": len(msg_ids)})

    def support_avatar_api(self, request):
        user = request.user
        if request.method == "GET":
            avatar_url = request.build_absolute_uri(user.avatar.url) if user.avatar else None
            return JsonResponse({"avatar_url": avatar_url, "email": user.email, "name": user.get_display_name()})

        if request.method == "POST":
            remove_avatar = request.POST.get("remove") in ("true", "1", True)
            if remove_avatar:
                if user.avatar:
                    try:
                        user.avatar.delete(save=False)
                    except Exception:
                        pass
                    user.avatar = None
                    user.save(update_fields=["avatar"])
                return JsonResponse({"status": "success", "avatar_url": None})

            new_avatar = request.FILES.get("avatar")
            if not new_avatar:
                return HttpResponseBadRequest("No image file provided")

            user.avatar = new_avatar
            user.save(update_fields=["avatar"])

            # Also ensure designated support account has this avatar if different
            from api.views import get_support_user
            support = get_support_user()
            if support and support.id != user.id and not support.avatar:
                support.avatar = new_avatar
                support.save(update_fields=["avatar"])

            avatar_url = request.build_absolute_uri(user.avatar.url) if user.avatar else None
            return JsonResponse({"status": "success", "avatar_url": avatar_url})

        return HttpResponseBadRequest("GET or POST required")

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
        support_avatar = request.build_absolute_uri(request.user.avatar.url) if request.user.avatar else None
        local_dt = timezone.localtime(chat_msg.created_at) if chat_msg.created_at else None
        time_display = local_dt.strftime("%I:%M %p").lstrip("0") if local_dt else ""
        full_display = (local_dt.strftime("%b %d, %Y ") + time_display) if local_dt else ""
        return JsonResponse({
            "status": "success",
            "message": {
                "id": chat_msg.id,
                "sender_id": chat_msg.sender_id,
                "sender_name": "STORA Support",
                "sender_avatar_url": support_avatar,
                "is_support": True,
                "message": chat_msg.message,
                "image_url": image_url,
                "created_at": time_display,
                "full_date": full_display,
                "iso_time": local_dt.isoformat() if local_dt else "",
            }
        })


stora_admin_site = StoraAdminSite(name="stora_admin")
