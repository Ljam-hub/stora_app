"""
URL configuration for stora_backend project.
"""
from django.conf import settings
from django.conf.urls.static import static
from django.urls import include, path
from .admin_site import stora_admin_site

urlpatterns = [
    path("admin/", stora_admin_site.urls),
    path("api/", include("api.urls")),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
