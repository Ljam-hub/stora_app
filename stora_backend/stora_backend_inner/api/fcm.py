"""
Firebase Cloud Messaging (FCM) push notification utility for Stora.
Handles sending order status updates and notifications to mobile devices.
"""
import logging
from django.conf import settings

logger = logging.getLogger(__name__)


def send_push_notification(fcm_token: str, title: str, body: str, data: dict = None) -> bool:
    """
    Sends a push notification to a specific device FCM token.
    Falls back gracefully to logging if FCM is not configured or in development.
    """
    if not fcm_token:
        logger.debug("No FCM token provided for notification: %s - %s", title, body)
        return False

    server_key = getattr(settings, "FCM_SERVER_KEY", None)
    if not server_key or server_key == "YOUR_FCM_SERVER_KEY":
        logger.info(
            "[DEV FCM] Simulated Push to [%s...]: Title: '%s' | Body: '%s' | Data: %s",
            fcm_token[:10] if len(fcm_token) > 10 else fcm_token,
            title,
            body,
            data or {},
        )
        return True

    # Real FCM dispatch via HTTP request / Firebase
    try:
        import requests
        headers = {
            "Authorization": f"key={server_key}",
            "Content-Type": "application/json",
        }
        payload = {
            "to": fcm_token,
            "notification": {
                "title": title,
                "body": body,
                "sound": "default",
            },
            "data": data or {},
        }
        response = requests.post(
            "https://fcm.googleapis.com/fcm/send",
            json=payload,
            headers=headers,
            timeout=5,
        )
        logger.info("FCM response: %s %s", response.status_code, response.text)
        return response.status_code == 200
    except Exception as exc:
        logger.warning("Failed to send FCM notification: %s", exc)
        return False


def notify_order_status_change(order, action: str, extra_msg: str = ""):
    """
    Notifies customer or owner about an order event.
    """
    data_payload = {
        "order_id": str(order.id),
        "status": order.status,
        "action": action,
    }

    if action == "created":
        # Notify owner of new order
        if order.owner and getattr(order.owner, "fcm_token", None):
            title = f"New Order #{order.id}"
            body = f"Order #{order.id} received from {order.customer_name or 'a customer'} for ₱{order.total_amount():.2f}"
            send_push_notification(order.owner.fcm_token, title, body, data_payload)

    elif action == "accepted":
        # Notify customer
        if order.customer and getattr(order.customer, "fcm_token", None):
            title = f"Order #{order.id} Accepted! 🎉"
            body = f"Your order #{order.id} has been accepted by {order.owner.business_name or 'the store'}."
            send_push_notification(order.customer.fcm_token, title, body, data_payload)

    elif action == "declined":
        # Notify customer
        if order.customer and getattr(order.customer, "fcm_token", None):
            reason_text = f": {order.decline_reason}" if order.decline_reason else "."
            title = f"Order #{order.id} Declined"
            body = f"Your order #{order.id} was declined{reason_text}"
            send_push_notification(order.customer.fcm_token, title, body, data_payload)

    elif action == "counter":
        # Notify customer of counter-offer
        if order.customer and getattr(order.customer, "fcm_token", None):
            price_text = f" (New Price: ₱{order.counter_price:.2f})" if order.counter_price else ""
            title = f"Counter-Offer for Order #{order.id}"
            body = f"Store suggested changes for Order #{order.id}{price_text}: {order.counter_notes}"
            send_push_notification(order.customer.fcm_token, title, body, data_payload)
