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
            return self._send_via_brevo(message, html_content)

        # 2. Try Resend REST API over HTTPS (Port 443)
        if self.resend_api_key:
            return self._send_via_resend(message, html_content)

        # 3. Fallback to standard SMTP (works locally where port 587 is unblocked)
        try:
            smtp_backend = SmtpEmailBackend(fail_silently=self.fail_silently)
            return smtp_backend.send_messages([message]) > 0
        except Exception as e:
            logger.error(
                "SMTP fallback failed (expected on Render Free Tier due to blocked ports 25/465/587): %s",
                e,
            )
            if not self.fail_silently:
                raise
            return False

    def _send_via_brevo(self, message, html_content):
        url = "https://api.brevo.com/v3/smtp/email"
        from_email = os.getenv("BREVO_SENDER_EMAIL") or message.from_email or "STORA <laisojl014@gmail.com>"
        sender_name = "STORA"
        sender_email = "laisojl014@gmail.com"
        if "<" in from_email and ">" in from_email:
            sender_name = from_email.split("<")[0].strip().strip('"').strip("'")
            sender_email = from_email.split("<")[1].split(">")[0].strip()
        elif "@" in from_email:
            sender_email = from_email.strip()

        payload = {
            "sender": {"name": sender_name, "email": sender_email},
            "to": [{"email": to.strip()} for to in message.to],
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
                    logger.info("Email successfully sent via Brevo to %s", message.to)
                    return True
        except urllib.error.HTTPError as err:
            err_body = err.read().decode("utf-8", errors="replace")
            logger.error("Brevo API error (HTTP %s): %s", err.code, err_body)
            if not self.fail_silently:
                raise RuntimeError(f"Brevo API error {err.code}: {err_body}") from err
            return False
        except Exception as err:
            logger.error("Brevo connection failed: %s", err)
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
            if not self.fail_silently:
                raise RuntimeError(f"Resend API error {err.code}: {err_body}") from err
            return False
        except Exception as err:
            logger.error("Resend connection failed: %s", err)
            if not self.fail_silently:
                raise
            return False
        return False
