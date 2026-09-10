"""
Django settings for the Stora backend.
Supports local SQLite / PostgreSQL via DATABASE_URL, SimpleJWT authentication,
Cloudinary image storage, CORS headers, and Stora business logic.
"""
import os
import sys
from datetime import timedelta
from pathlib import Path
try:
    import dj_database_url
except ImportError:
    dj_database_url = None
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent

# Load .env file
load_dotenv(BASE_DIR / ".env")

SECRET_KEY = os.getenv("SECRET_KEY", os.getenv("Secret_Key", "dev-insecure-secret-key-change-me"))

DEBUG = os.getenv("DEBUG", "True").lower() in ("true", "1", "t", "yes")

allowed_hosts_env = os.getenv("ALLOWED_HOSTS")
if allowed_hosts_env:
    ALLOWED_HOSTS = [h.strip() for h in allowed_hosts_env.split(",") if h.strip()]
elif DEBUG:
    ALLOWED_HOSTS = ["*"]
else:
    ALLOWED_HOSTS = [".onrender.com", "localhost", "127.0.0.1"]

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
]

# Cloudinary support if configured
if os.getenv("CLOUDINARY_URL"):
    INSTALLED_APPS += [
        "django.contrib.staticfiles",
        "cloudinary_storage",
        "cloudinary",
    ]
else:
    INSTALLED_APPS += [
        "django.contrib.staticfiles",
    ]

INSTALLED_APPS += [
    # 3rd party
    "corsheaders",
    "rest_framework",
    "rest_framework_simplejwt",
    # Stora apps
    "accounts",
    "inventory",
    "sales",
    "orders",
    "api",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

CORS_ALLOW_ALL_ORIGINS = True

ROOT_URLCONF = "stora_backend.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "stora_backend.wsgi.application"
ASGI_APPLICATION = "stora_backend.asgi.application"

# Database configuration: PostgreSQL if DATABASE_URL is set, otherwise SQLite.
# When running automated test suites, use isolated SQLite to avoid Supabase pooler permission issues.
DATABASE_URL = os.getenv("DATABASE_URL")
if "test" in sys.argv:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "test_db.sqlite3",
        }
    }
elif DATABASE_URL and dj_database_url:
    DATABASES = {
        "default": dj_database_url.config(
            default=DATABASE_URL,
            conn_max_age=600,
            conn_health_checks=True,
        )
    }
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",
        }
    }

AUTH_USER_MODEL = "accounts.User"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": (
        "rest_framework.permissions.IsAuthenticated",
    ),
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(days=7),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=30),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": False,
    "AUTH_HEADER_TYPES": ("Bearer",),
}

FREE_TRIAL_DAYS = 14
FREE_PLAN_PRODUCT_LIMIT = 20

LANGUAGE_CODE = "en-us"
TIME_ZONE = "Asia/Manila"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATICFILES_DIRS = [BASE_DIR / "static"] if (BASE_DIR / "static").exists() else []
STATIC_ROOT = BASE_DIR / "staticfiles"

# Whitenoise static storage with fallback
STATICFILES_STORAGE = "whitenoise.storage.CompressedStaticFilesStorage"
WHITENOISE_MANIFEST_STRICT = False

STORAGES = {
    "default": {
        "BACKEND": "cloudinary_storage.storage.MediaCloudinaryStorage" if os.getenv("CLOUDINARY_URL") else "django.core.files.storage.FileSystemStorage",
    },
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedStaticFilesStorage",
    },
}

MEDIA_URL = "media/"
MEDIA_ROOT = BASE_DIR / "media"

if os.getenv("CLOUDINARY_URL"):
    DEFAULT_FILE_STORAGE = "cloudinary_storage.storage.MediaCloudinaryStorage"

# Email configuration
EMAIL_HOST = os.getenv("EMAIL_HOST", "smtp.gmail.com")
EMAIL_PORT = int(os.getenv("EMAIL_PORT", "587"))
EMAIL_USE_TLS = os.getenv("EMAIL_USE_TLS", "True").lower() in ("true", "1", "yes")
EMAIL_USE_SSL = os.getenv("EMAIL_USE_SSL", "False").lower() in ("true", "1", "yes")
EMAIL_HOST_USER = os.getenv("EMAIL_HOST_USER", "laisojl014@gmail.com")
EMAIL_HOST_PASSWORD = os.getenv("EMAIL_HOST_PASSWORD", "kworofuerbnejybp")
EMAIL_TIMEOUT = int(os.getenv("EMAIL_TIMEOUT", "15"))

_env_email_backend = os.getenv("EMAIL_BACKEND")
if _env_email_backend:
    EMAIL_BACKEND = _env_email_backend
elif os.getenv("BREVO_API_KEY") or os.getenv("RESEND_API_KEY"):
    EMAIL_BACKEND = "api.email_backend.UniversalEmailBackend"
elif EMAIL_HOST_USER and EMAIL_HOST_PASSWORD:
    EMAIL_BACKEND = "api.email_backend.UniversalEmailBackend"
elif DEBUG:
    EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
else:
    EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

_default_from = os.getenv(
    "DEFAULT_FROM_EMAIL",
    f"STORA <{EMAIL_HOST_USER}>" if EMAIL_HOST_USER else "STORA <laisojl014@gmail.com>"
)
DEFAULT_FROM_EMAIL = _default_from.strip('"').strip("'")


DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# Firebase Cloud Messaging (Modern HTTP v1 via Firebase Admin SDK)
default_fcm_cred = BASE_DIR / "firebase-service-account.json"
FIREBASE_CREDENTIALS_PATH = os.getenv(
    "FIREBASE_CREDENTIALS_PATH",
    str(default_fcm_cred) if default_fcm_cred.exists() else ""
)
FIREBASE_CREDENTIALS_JSON = os.getenv("FIREBASE_CREDENTIALS_JSON", "")
FCM_SERVER_KEY = os.getenv("FCM_SERVER_KEY", "")
