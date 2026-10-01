"""
Universal Email Backend for Stora.
Delivers transactional emails over HTTPS (Port 443) via Brevo or Resend REST APIs.
Completely bypasses cloud firewalls (like Render Free Tier blocking outbound SMTP ports 25, 465, 587).
Falls back to standard SMTP in local development environments.
"""
import json
import logging
import os
import sys
import urllib.error
import urllib.request
from django.core.mail.backends.base import BaseEmailBackend
from django.core.mail.backends.smtp import EmailBackend as SmtpEmailBackend

logger = logging.getLogger(__name__)


class UniversalEmailBackend(BaseEmailBackend):
    _cached_brevo_sender = None
    _cached_senders_list = []
    last_error = None
    last_status = None

    def __init__(self, fail_silently=False, **kwargs):
        super().__init__(fail_silently=fail_silently, **kwargs)
        self.brevo_api_key = os.getenv("BREVO_API_KEY", "").strip()
        self.resend_api_key = os.getenv("RESEND_API_KEY", "").strip()

    def send_messages(self, email_messages):
        if not email_messages:
            return 0

        if "test" in sys.argv:
            from django.core import mail
            if not hasattr(mail, "outbox"):
                mail.outbox = []
            mail.outbox.extend(email_messages)
            return len(email_messages)

        sent_count = 0
        for message in email_messages:
            try:
                success = self._send_single_message(message)
                if success:
                    sent_count += 1
            except Exception as e:
                UniversalEmailBackend.last_error = f"{type(e).__name__}: {e}"
                logger.error("Email send failed: %s", e)
                if not self.fail_silently:
                    raise

        return sent_count

    def _send_single_message(self, message):
        html_content = ""
        for content, mimetype in getattr(message, "alternatives", []):
            if mimetype == "text/html":
                html_content = content
                break
        if not html_content and getattr(message, "content_subtype", "") == "html":
            html_content = message.body

        # 1. Try Brevo REST API over HTTPS (Port 443)
        if self.brevo_api_key:
            try:
                if self._send_via_brevo(message, html_content):
                    UniversalEmailBackend.last_status = "Sent via Brevo HTTPS"
                    return True
            except Exception as e:
                UniversalEmailBackend.last_error = f"Brevo dispatch error: {e}"
                logger.error("Brevo dispatch error: %s", e)

        # 2. Try Resend REST API over HTTPS (Port 443)
        if self.resend_api_key:
            try:
                if self._send_via_resend(message, html_content):
                    UniversalEmailBackend.last_status = "Sent via Resend HTTPS"
                    return True
            except Exception as e:
                UniversalEmailBackend.last_error = f"Resend dispatch error: {e}"
                logger.error("Resend dispatch error: %s", e)

        # 3. Fallback to standard SMTP (works locally where port 587 is unblocked)
        try:
            smtp_backend = SmtpEmailBackend(fail_silently=self.fail_silently)
            success = smtp_backend.send_messages([message]) > 0
            if success:
                UniversalEmailBackend.last_status = "Sent via SMTP"
            return success
        except Exception as e:
            UniversalEmailBackend.last_error = f"SMTP fallback error: {e}"
            logger.error(
                "SMTP fallback failed (expected on Render Free Tier due to blocked ports 25/465/587): %s",
                e,
            )
            if not self.fail_silently and not self.brevo_api_key and not self.resend_api_key:
                raise
            return False

    def _get_brevo_verified_sender(self, force_refresh=False):
        if not force_refresh and UniversalEmailBackend._cached_brevo_sender:
            return UniversalEmailBackend._cached_brevo_sender

        configured = os.getenv("BREVO_SENDER_EMAIL", "").strip()
        if configured:
            UniversalEmailBackend._cached_brevo_sender = configured
            return UniversalEmailBackend._cached_brevo_sender

        if not self.brevo_api_key:
            fallback = os.getenv("EMAIL_HOST_USER", "osiallj@gmail.com").strip()
            UniversalEmailBackend._cached_brevo_sender = fallback
            return fallback

        try:
            req = urllib.request.Request(
                "https://api.brevo.com/v3/senders",
                headers={
                    "api-key": self.brevo_api_key,
                    "Accept": "application/json",
                    "User-Agent": "StoraBackend/1.0",
                },
            )
            with urllib.request.urlopen(req, timeout=5) as r:
                data = json.loads(r.read().decode("utf-8"))
                senders = data.get("senders", [])
                UniversalEmailBackend._cached_senders_list = senders

                preferred_user = os.getenv("EMAIL_HOST_USER", "").strip().lower()

                # 1. Look for active sender matching EMAIL_HOST_USER
                if preferred_user:
                    for s in senders:
                        if s.get("active") and s.get("email", "").strip().lower() == preferred_user:
                            UniversalEmailBackend._cached_brevo_sender = s["email"].strip()
                            logger.info("Selected preferred active Brevo sender: %s", UniversalEmailBackend._cached_brevo_sender)
                            return UniversalEmailBackend._cached_brevo_sender

                # 2. Look for ANY active verified sender
                for s in senders:
                    if s.get("active") and s.get("email"):
                        UniversalEmailBackend._cached_brevo_sender = s["email"].strip()
                        logger.info("Auto-selected active Brevo verified sender: %s", UniversalEmailBackend._cached_brevo_sender)
                        return UniversalEmailBackend._cached_brevo_sender

                # 3. Look for any listed sender
                for s in senders:
                    if s.get("email"):
                        UniversalEmailBackend._cached_brevo_sender = s["email"].strip()
                        logger.info("Selected first available Brevo sender: %s", UniversalEmailBackend._cached_brevo_sender)
                        return UniversalEmailBackend._cached_brevo_sender
        except Exception as e:
            logger.warning("Could not auto-fetch Brevo verified sender: %s", e)

        fallback = os.getenv("EMAIL_HOST_USER", "osiallj@gmail.com").strip()
        UniversalEmailBackend._cached_brevo_sender = fallback
        return fallback

    def _send_via_brevo(self, message, html_content, retry=True):
        url = "https://api.brevo.com/v3/smtp/email"
        verified_sender = self._get_brevo_verified_sender()
        sender_email = verified_sender or "osiallj@gmail.com"
        sender_name = "STORA"

        from_email = message.from_email or ""
        if "<" in from_email and ">" in from_email:
            name_part = from_email.split("<")[0].strip().strip('"').strip("'")
            if name_part:
                sender_name = name_part

        # Deduplicate and validate recipient emails
        to_list = []
        seen = set()
        for to in message.to:
            cleaned = to.strip()
            if cleaned and cleaned.lower() not in seen:
                seen.add(cleaned.lower())
                to_list.append({"email": cleaned})
        if not to_list:
            logger.warning("No valid recipients for email: %s", message.subject)
            return False

        payload = {
            "sender": {"name": sender_name, "email": sender_email},
            "to": to_list,
            "subject": message.subject,
            "textContent": message.body,
        }
        if html_content:
            payload["htmlContent"] = html_content

        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "api-key": self.brevo_api_key,
                "Content-Type": "application/json",
                "Accept": "application/json",
                "User-Agent": "StoraBackend/1.0",
            },
            method="POST",
        )

        try:
            with urllib.request.urlopen(req, timeout=10) as response:
                if response.status in (200, 201, 202):
                    logger.info("Email successfully sent via Brevo to %s (sender: %s)", message.to, sender_email)
                    return True
        except urllib.error.HTTPError as err:
            err_body = err.read().decode("utf-8", errors="replace")
            logger.error("Brevo API error (HTTP %s): %s", err.code, err_body)
            UniversalEmailBackend.last_error = f"Brevo HTTP {err.code}: {err_body}"

            # Auto-recovery if sender email was not authorized/verified
            if retry and err.code in (400, 401, 403) and any(w in err_body.lower() for w in ["sender", "unauthorized", "verify", "verified"]):
                logger.warning("Brevo rejected sender '%s'. Refreshing verified senders from API...", sender_email)
                fresh_sender = self._get_brevo_verified_sender(force_refresh=True)
                if fresh_sender and fresh_sender != sender_email:
                    logger.info("Retrying Brevo dispatch with refreshed sender: %s", fresh_sender)
                    return self._send_via_brevo(message, html_content, retry=False)

            if not self.fail_silently:
                raise RuntimeError(f"Brevo API error {err.code}: {err_body}") from err
            return False
        except Exception as err:
            logger.error("Brevo connection failed: %s", err)
            UniversalEmailBackend.last_error = f"Brevo connection: {err}"
            if not self.fail_silently:
                raise
            return False
        return False

    def _send_via_resend(self, message, html_content):
        url = "https://api.resend.com/emails"
        from_email = message.from_email or "STORA <onboarding@resend.dev>"
        if "@" in from_email and not os.getenv("RESEND_CUSTOM_DOMAIN"):
            from_email = "STORA <onboarding@resend.dev>"

        payload = {
            "from": from_email,
            "to": [to.strip() for to in message.to],
            "subject": message.subject,
            "text": message.body,
        }
        if html_content:
            payload["html"] = html_content

        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {self.resend_api_key}",
                "Content-Type": "application/json",
                "Accept": "application/json",
                "User-Agent": "StoraBackend/1.0",
            },
            method="POST",
        )

        try:
            with urllib.request.urlopen(req, timeout=10) as response:
                if response.status in (200, 201, 202):
                    logger.info("Email successfully sent via Resend to %s", message.to)
                    return True
        except urllib.error.HTTPError as err:
            err_body = err.read().decode("utf-8", errors="replace")
            logger.error("Resend API error (HTTP %s): %s", err.code, err_body)
            UniversalEmailBackend.last_error = f"Resend HTTP {err.code}: {err_body}"
            if not self.fail_silently:
                raise RuntimeError(f"Resend API error {err.code}: {err_body}") from err
            return False
        except Exception as err:
            logger.error("Resend connection failed: %s", err)
            UniversalEmailBackend.last_error = f"Resend connection: {err}"
            if not self.fail_silently:
                raise
            return False
        return False
