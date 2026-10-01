"""
URL configuration for stora_backend project.
"""
from django.conf import settings
from django.conf.urls.static import static
from django.contrib.auth import views as auth_views
from django.http import JsonResponse
from django.shortcuts import redirect, render
from django.urls import include, path, re_path, reverse_lazy
from django.views.static import serve
from .admin_site import stora_admin_site

from pathlib import Path
import json
import logging
import urllib.request
from django.core.cache import cache

import os

logger = logging.getLogger(__name__)

GITHUB_REPO = "Ljam-hub/stora_app"
DEFAULT_RELEASE_TAG = "v1.2.0"
DEFAULT_CUSTOMER_SIZE = "56.1 MB"
DEFAULT_OWNER_SIZE = "80.9 MB"
DEFAULT_CUSTOMER_URL = f"https://github.com/{GITHUB_REPO}/releases/latest/download/Stora-Customer.apk"
DEFAULT_OWNER_URL = f"https://github.com/{GITHUB_REPO}/releases/latest/download/Stora.apk"
CACHE_KEY = "stora_github_release_info_v120_b"
LAST_KNOWN_KEY = "stora_github_release_last_known_v120_b"
CACHE_TIMEOUT = 300  # 5 minutes


def format_bytes_to_mb(size_in_bytes):
    if not size_in_bytes or not isinstance(size_in_bytes, (int, float)):
        return None
    mb = size_in_bytes / (1024 * 1024)
    if mb >= 10:
        return f"{mb:.1f} MB"
    return f"{mb:.2f} MB"


def get_github_release_info():
    cached = cache.get(CACHE_KEY)
    if cached and cached.get("tag_name") == DEFAULT_RELEASE_TAG:
        return cached

    # Always baseline on the current release defaults
    info = {
        "tag_name": DEFAULT_RELEASE_TAG,
        "customer_apk_size": DEFAULT_CUSTOMER_SIZE,
        "customer_download_url": DEFAULT_CUSTOMER_URL,
        "owner_apk_size": DEFAULT_OWNER_SIZE,
        "owner_download_url": DEFAULT_OWNER_URL,
    }
    last_known = cache.get(LAST_KNOWN_KEY)
    if last_known and isinstance(last_known, dict):
        if last_known.get("tag_name", "") >= DEFAULT_RELEASE_TAG:
            info.update(last_known)

    try:
        url = f"https://api.github.com/repos/{GITHUB_REPO}/releases/latest"
        headers = {
            "User-Agent": "Stora-Backend/1.1",
            "Accept": "application/vnd.github.v3+json",
        }
        github_token = os.environ.get("GITHUB_TOKEN") or getattr(settings, "GITHUB_TOKEN", None)
        if github_token:
            headers["Authorization"] = f"token {github_token}"

        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=5) as response:
            if response.status == 200:
                data = json.loads(response.read().decode("utf-8"))
                tag = data.get("tag_name") or info.get("tag_name", DEFAULT_RELEASE_TAG)
                info["tag_name"] = tag
                assets = data.get("assets", [])
                for asset in assets:
                    name = (asset.get("name") or "").lower()
                    size_bytes = asset.get("size")
                    formatted_size = format_bytes_to_mb(size_bytes)
                    download_url = asset.get("browser_download_url")

                    if "customer" in name:
                        if formatted_size:
                            info["customer_apk_size"] = formatted_size
                        if download_url:
                            info["customer_download_url"] = download_url
                    elif "stora" in name or "owner" in name:
                        if formatted_size:
                            info["owner_apk_size"] = formatted_size
                        if download_url:
                            info["owner_download_url"] = download_url
    except Exception as exc:
        logger.warning("Could not fetch GitHub release info: %s", exc)

    # Check local repo-level apk/ files and give precedence to built binaries served locally
    try:
        repo_root = Path(settings.BASE_DIR).parent.parent
        for cust_candidate in [
            repo_root / "apk" / "Stora-Customer.apk",
            repo_root / "stora_customer" / "apk" / "Stora-Customer.apk",
            repo_root / "flutter-apk" / "Stora-Customer.apk",
        ]:
            if cust_candidate.exists():
                formatted = format_bytes_to_mb(cust_candidate.stat().st_size)
                if formatted:
                    info["customer_apk_size"] = formatted
                break

        for owner_candidate in [
            repo_root / "apk" / "Stora-Owner.apk",
            repo_root / "apk" / "Stora.apk",
            repo_root / "stora_owner" / "apk" / "Stora-Owner.apk",
            repo_root / "stora_owner" / "apk" / "Stora.apk",
            repo_root / "flutter-apk" / "Stora.apk",
        ]:
            if owner_candidate.exists():
                formatted = format_bytes_to_mb(owner_candidate.stat().st_size)
                if formatted:
                    info["owner_apk_size"] = formatted
                break
    except Exception:
        pass

    cache.set(CACHE_KEY, info, CACHE_TIMEOUT)
    cache.set(LAST_KNOWN_KEY, info, None)  # Persist last known good

    return info


def download_customer(request):
    source = request.GET.get("source", "").lower()
    if source != "github":
        try:
            repo_root = Path(settings.BASE_DIR).parent.parent
            for candidate in [
                repo_root / "apk" / "Stora-Customer.apk",
                repo_root / "flutter-apk" / "Stora-Customer.apk",
                repo_root / "stora_customer" / "apk" / "Stora-Customer.apk",
            ]:
                if candidate.exists():
                    from django.http import FileResponse
                    return FileResponse(
                        open(candidate, "rb"),
                        as_attachment=True,
                        filename="Stora-Customer.apk",
                        content_type="application/vnd.android.package-archive",
                    )
        except Exception as exc:
            logger.warning("Could not serve local customer APK: %s", exc)
    info = get_github_release_info()
    return redirect(info.get("customer_download_url") or DEFAULT_CUSTOMER_URL)


def download_owner(request):
    source = request.GET.get("source", "").lower()
    if source != "github":
        try:
            repo_root = Path(settings.BASE_DIR).parent.parent
            for candidate in [
                repo_root / "apk" / "Stora.apk",
                repo_root / "apk" / "Stora-Owner.apk",
                repo_root / "flutter-apk" / "Stora.apk",
                repo_root / "flutter-apk" / "Stora-Owner.apk",
                repo_root / "stora_owner" / "apk" / "Stora.apk",
            ]:
                if candidate.exists():
                    from django.http import FileResponse
                    return FileResponse(
                        open(candidate, "rb"),
                        as_attachment=True,
                        filename="Stora.apk",
                        content_type="application/vnd.android.package-archive",
                    )
        except Exception as exc:
            logger.warning("Could not serve local owner APK: %s", exc)
    info = get_github_release_info()
    return redirect(info.get("owner_download_url") or DEFAULT_OWNER_URL)


def release_info_api(request):
    info = get_github_release_info()
    return JsonResponse(info)


def root_status(request):
    try:
        info = get_github_release_info()
    except Exception as exc:
        logger.warning("Could not get release info: %s", exc)
        info = {
            "tag_name": DEFAULT_RELEASE_TAG,
            "customer_apk_size": DEFAULT_CUSTOMER_SIZE,
            "customer_download_url": DEFAULT_CUSTOMER_URL,
            "owner_apk_size": DEFAULT_OWNER_SIZE,
            "owner_download_url": DEFAULT_OWNER_URL,
        }

    # If requested by a browser, render the modern Stora Backend Portal
    accept = request.headers.get("Accept", "")
    if "text/html" in accept and request.GET.get("format") != "json":
        context = {
            "release_tag": info.get("tag_name", DEFAULT_RELEASE_TAG),
            "customer_apk_size": info.get("customer_apk_size", DEFAULT_CUSTOMER_SIZE),
            "customer_download_url": info.get("customer_download_url", DEFAULT_CUSTOMER_URL),
            "owner_apk_size": info.get("owner_apk_size", DEFAULT_OWNER_SIZE),
            "owner_download_url": info.get("owner_download_url", DEFAULT_OWNER_URL),
        }
        try:
            return render(request, "portal.html", context)
        except Exception as exc:
            logger.error("Failed to render portal.html: %s", exc)

    return JsonResponse({
        "status": "ok",
        "message": "Stora backend is online and running!",
        "api_url": "/api/",
        "health_check": "/api/health/",
        "admin_url": "/admin/",
        "release": info,
    })


def custom_500_handler(request):
    accept = request.headers.get("Accept", "")
    if "text/html" not in accept or request.path.startswith("/api/"):
        return JsonResponse(
            {"error": "Internal Server Error", "detail": "An unexpected server condition occurred. Please try again later."},
            status=500,
        )
    return render(request, "500.html", status=500)


def custom_404_handler(request, exception=None):
    accept = request.headers.get("Accept", "")
    if "text/html" not in accept or request.path.startswith("/api/"):
        return JsonResponse(
            {"error": "Not Found", "detail": "The requested resource was not found."},
            status=404,
        )
    return render(request, "404.html", status=404)


handler500 = custom_500_handler
handler404 = custom_404_handler


urlpatterns = [
    path("", root_status, name="root_status"),
    path("download/customer/", download_customer, name="download_customer"),
    path("download/owner/", download_owner, name="download_owner"),
    path("api/release-info/", release_info_api, name="release_info_api"),
    path(
        "admin/password_reset/",
        auth_views.PasswordResetView.as_view(
            template_name="registration/password_reset_form.html",
            email_template_name="registration/password_reset_email.html",
            subject_template_name="registration/password_reset_subject.txt",
            success_url=reverse_lazy("admin_password_reset_done"),
            extra_email_context={"site_name": "STORA Admin"},
        ),
        name="admin_password_reset",
    ),
    path(
        "admin/password_reset/done/",
        auth_views.PasswordResetDoneView.as_view(
            template_name="registration/password_reset_done.html",
        ),
        name="admin_password_reset_done",
    ),
    path(
        "reset/<uidb64>/<token>/",
        auth_views.PasswordResetConfirmView.as_view(
            template_name="registration/password_reset_confirm.html",
            success_url=reverse_lazy("admin_password_reset_complete"),
        ),
        name="admin_password_reset_confirm",
    ),
    path(
        "reset/done/",
        auth_views.PasswordResetCompleteView.as_view(
            template_name="registration/password_reset_complete.html",
        ),
        name="admin_password_reset_complete",
    ),
    path("admin/", stora_admin_site.urls),
    path("api/", include("api.urls")),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
else:
    urlpatterns += [
        re_path(r"^media/(?P<path>.*)$", serve, {"document_root": settings.MEDIA_ROOT}),
    ]
