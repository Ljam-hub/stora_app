import base64
import hashlib
import json
import os
from cryptography.fernet import Fernet, InvalidToken
from django.conf import settings
from django.db import models

ENCRYPTION_PREFIX = "enc::"


def get_cipher() -> Fernet:
    """Derives a deterministic Fernet cipher from settings.SECRET_KEY or FIELD_ENCRYPTION_KEY."""
    raw_key = os.getenv("FIELD_ENCRYPTION_KEY")
    if not raw_key:
        if settings.configured:
            secret = getattr(settings, "SECRET_KEY", "stora-backend-secret-key-fallback")
        else:
            secret = os.getenv("SECRET_KEY", "stora-backend-secret-key-fallback")
        digest = hashlib.sha256(secret.encode("utf-8")).digest()
        raw_key = base64.urlsafe_b64encode(digest)
    elif isinstance(raw_key, str):
        if len(raw_key) != 44 or not raw_key.endswith("="):
            digest = hashlib.sha256(raw_key.encode("utf-8")).digest()
            raw_key = base64.urlsafe_b64encode(digest)
        else:
            raw_key = raw_key.encode("utf-8")
    return Fernet(raw_key)


def encrypt_value(value: str) -> str:
    """Encrypts plaintext string and prepends prefix so unencrypted legacy values can be distinguished."""
    if not value or not isinstance(value, str):
        return value
    if value.startswith(ENCRYPTION_PREFIX):
        return value  # Already encrypted
    cipher = get_cipher()
    encrypted_bytes = cipher.encrypt(value.encode("utf-8"))
    return f"{ENCRYPTION_PREFIX}{encrypted_bytes.decode('utf-8')}"


def decrypt_value(value: str) -> str:
    """Decrypts ciphertext string if prefixed with enc::. Gracefully returns value as-is otherwise."""
    if not value or not isinstance(value, str):
        return value
    if not value.startswith(ENCRYPTION_PREFIX):
        return value  # Legacy or unencrypted plaintext
    token = value[len(ENCRYPTION_PREFIX):]
    try:
        cipher = get_cipher()
        decrypted_bytes = cipher.decrypt(token.encode("utf-8"))
        return decrypted_bytes.decode("utf-8")
    except (InvalidToken, Exception):
        return value


class EncryptedCharField(models.CharField):
    """CharField that transparently encrypts data at rest in Supabase/PostgreSQL.
    
    When written to the database, values are encrypted and prefixed with 'enc::'.
    When read back from the database, values are transparently decrypted into plaintext.
    """

    def from_db_value(self, value, expression, connection):
        if value is None:
            return value
        return decrypt_value(value)

    def to_python(self, value):
        if value is None:
            return value
        return decrypt_value(value)

    def get_prep_value(self, value):
        value = super().get_prep_value(value)
        if value is None:
            return value
        return encrypt_value(str(value))


class EncryptedTextField(models.TextField):
    """TextField that transparently encrypts data at rest in Supabase/PostgreSQL."""

    def from_db_value(self, value, expression, connection):
        if value is None:
            return value
        return decrypt_value(value)

    def to_python(self, value):
        if value is None:
            return value
        return decrypt_value(value)

    def get_prep_value(self, value):
        value = super().get_prep_value(value)
        if value is None:
            return value
        return encrypt_value(str(value))
