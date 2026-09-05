"""
Firebase Cloud Messaging (FCM) push notification utility for Stora.
Handles sending order status updates and notifications to mobile devices using
the modern Firebase Admin SDK (FCM HTTP v1 API).
"""
import json
import logging
import os
from django.conf import settings

logger = logging.getLogger(__name__)

_firebase_initialized = False


def _get_firebase_app():
    """
    Initializes and returns the Firebase Admin default app.
    Supports credentials from file path or JSON string in environment variables.
    """
    global _firebase_initialized
    if _firebase_initialized:
        return True

    try:
        import firebase_admin
        from firebase_admin import credentials

        if firebase_admin._apps:
            _firebase_initialized = True
            return True

        cred_path = getattr(settings, "FIREBASE_CREDENTIALS_PATH", "") or os.getenv("FIREBASE_CREDENTIALS_PATH", "")
        cred_json = getattr(settings, "FIREBASE_CREDENTIALS_JSON", "") or os.getenv("FIREBASE_CREDENTIALS_JSON", "")

        cred = None
        if cred_path and os.path.isfile(cred_path):
            cred = credentials.Certificate(cred_path)
        elif cred_json:
            try:
                cert_dict = json.loads(cred_json)
                cred = credentials.Certificate(cert_dict)
            except Exception as e:
                logger.error("Failed to parse FIREBASE_CREDENTIALS_JSON: %s", e)

        if cred:
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("Firebase Admin SDK successfully initialized.")
            return True
        else:
            return False
    except ImportError:
        logger.debug("firebase_admin package is not installed.")
        return False
    except Exception as exc:
        logger.warning("Error initializing Firebase Admin SDK: %s", exc)
        return False


def send_push_notification(fcm_token: str, title: str, body: str, data: dict = None) -> bool:
    """
    Sends a push notification to a specific device FCM token using the HTTP v1 API.
    Falls back gracefully to logging if Firebase is not configured or in development.
    """
    if not fcm_token:
        logger.debug("No FCM token provided for notification: %s - %s", title, body)
        return False

    # Stringify all data payload values as required by FCM specification
    str_data = {str(k): str(v) for k, v in (data or {}).items()}

    # Check if Firebase Admin SDK can be initialized
    if _get_firebase_app():
        try:
            from firebase_admin import messaging

            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=str_data,
                token=fcm_token,
            )
            response = messaging.send(message)
            logger.info("Successfully sent FCM message: %s", response)
            return True
        except Exception as exc:
            logger.warning("Firebase Admin failed to send notification to token [%s...]: %s", fcm_token[:10], exc)
            return False

    # Graceful fallback: simulated push notification in development/testing
    logger.info(
        "[DEV FCM] Simulated Push to [%s...]: Title: '%s' | Body: '%s' | Data: %s",
        fcm_token[:10] if len(fcm_token) > 10 else fcm_token,
        title,
        body,
        str_data,
    )
    return True


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
