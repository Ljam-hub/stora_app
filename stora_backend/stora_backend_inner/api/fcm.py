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
        # Check explicit path
        if cred_path and os.path.isfile(cred_path):
            cred = credentials.Certificate(cred_path)
            logger.info("Loaded Firebase credentials from configured path: %s", cred_path)

        # Check candidate auto-discovery paths
        if not cred:
            from pathlib import Path
            candidate_dirs = [
                getattr(settings, "BASE_DIR", None),
                Path(__file__).resolve().parent.parent,
                Path(__file__).resolve().parent.parent.parent,
            ]
            for cdir in candidate_dirs:
                if cdir:
                    candidate = Path(cdir) / "firebase-service-account.json"
                    if candidate.is_file():
                        try:
                            cred = credentials.Certificate(str(candidate))
                            logger.info("Auto-discovered Firebase credentials at %s", candidate)
                            break
                        except Exception as ce:
                            logger.warning("Failed to load discovered certificate at %s: %s", candidate, ce)

        # Check JSON string in env
        if not cred and cred_json:
            try:
                cert_dict = json.loads(cred_json)
                cred = credentials.Certificate(cert_dict)
                logger.info("Loaded Firebase credentials from FIREBASE_CREDENTIALS_JSON.")
            except Exception as e:
                logger.error("Failed to parse FIREBASE_CREDENTIALS_JSON: %s", e)

        if cred:
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("Firebase Admin SDK successfully initialized.")
            return True
        else:
            logger.warning("No Firebase credentials found. Push notifications will be simulated.")
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

            channel_id = str_data.get("channel_id") or (
                "stora_owner_orders" if str_data.get("action") == "created" else "stora_customer_orders"
            )

            android_config = messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id=channel_id,
                    priority="high",
                    default_sound=True,
                    default_vibrate_timings=True,
                    icon="ic_launcher",
                ),
            )

            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=str_data,
                token=fcm_token,
                android=android_config,
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
            data_payload["title"] = title
            data_payload["body"] = body
            data_payload["channel_id"] = "stora_owner_orders"
            send_push_notification(order.owner.fcm_token, title, body, data_payload)
        else:
            logger.info("Owner for Order #%s has no registered FCM token.", order.id)

    elif action == "accepted":
        # Notify customer
        if order.customer and getattr(order.customer, "fcm_token", None):
            title = f"Order #{order.id} Accepted! 🎉"
            body = f"Your order #{order.id} has been accepted by {order.owner.business_name or 'the store'}."
            data_payload["title"] = title
            data_payload["body"] = body
            data_payload["channel_id"] = "stora_customer_orders"
            send_push_notification(order.customer.fcm_token, title, body, data_payload)
        else:
            logger.info("Customer for Order #%s has no registered FCM token.", order.id)

    elif action == "declined":
        # Notify customer
        if order.customer and getattr(order.customer, "fcm_token", None):
            reason_text = f": {order.decline_reason}" if order.decline_reason else "."
            title = f"Order #{order.id} Declined"
            body = f"Your order #{order.id} was declined{reason_text}"
            data_payload["title"] = title
            data_payload["body"] = body
            data_payload["channel_id"] = "stora_customer_orders"
            send_push_notification(order.customer.fcm_token, title, body, data_payload)
        else:
            logger.info("Customer for Order #%s has no registered FCM token.", order.id)

    elif action == "counter":
        # Notify customer of counter-offer
        if order.customer and getattr(order.customer, "fcm_token", None):
            price_text = f" (New Price: ₱{order.counter_price:.2f})" if order.counter_price else ""
            title = f"Counter-Offer for Order #{order.id}"
            body = f"Store suggested changes for Order #{order.id}{price_text}: {order.counter_notes}"
            data_payload["title"] = title
            data_payload["body"] = body
            data_payload["channel_id"] = "stora_customer_orders"
            send_push_notification(order.customer.fcm_token, title, body, data_payload)
        else:
            logger.info("Customer for Order #%s has no registered FCM token.", order.id)

    elif action == "ready":
        # Notify customer that order is ready for pickup
        if order.customer and getattr(order.customer, "fcm_token", None):
            store_name = (order.owner.business_name if hasattr(order.owner, 'business_name') and order.owner.business_name else None) or "the store"
            title = f"Order #{order.id} Ready for Pickup! 🛍️"
            body = f"Your order #{order.id} is prepared and ready for pickup at {store_name}."
            data_payload["title"] = title
            data_payload["body"] = body
            data_payload["channel_id"] = "stora_customer_orders"
            send_push_notification(order.customer.fcm_token, title, body, data_payload)
        else:
            logger.info("Customer for Order #%s has no registered FCM token.", order.id)
