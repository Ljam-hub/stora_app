"""
URL configuration for stora_backend project.
"""
from django.conf import settings
from django.conf.urls.static import static
from django.contrib.auth import views as auth_views
from django.http import JsonResponse
from django.shortcuts import redirect, render
from django.urls import include, path, reverse_lazy
from .admin_site import stora_admin_site

GITHUB_RELEASE_BASE = "https://github.com/Ljam-hub/stora_app/releases/download/v1.0.0"

def download_customer(request):
    return redirect(f"{GITHUB_RELEASE_BASE}/Stora-Customer.apk")

def download_owner(request):
    return redirect(f"{GITHUB_RELEASE_BASE}/Stora.apk")

def root_status(request):
    # If requested by a browser, render the modern Stora Backend Portal
    accept = request.headers.get("Accept", "")
    if "text/html" in accept and request.GET.get("format") != "json":
        return render(request, "portal.html")

    return JsonResponse({
        "status": "ok",
        "message": "Stora backend is online and running!",
        "api_url": "/api/",
        "health_check": "/api/health/",
        "admin_url": "/admin/",
    })

urlpatterns = [
    path("", root_status, name="root_status"),
    path("download/customer/", download_customer, name="download_customer"),
    path("download/owner/", download_owner, name="download_owner"),
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
