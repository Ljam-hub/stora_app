from rest_framework import permissions
from rest_framework.permissions import DjangoModelPermissions, SAFE_METHODS


class IsNotBlocked(permissions.BasePermission):
    """Denies access if user is blocked or inactive."""
    message = "Your account has been suspended or blocked. Please contact support."

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return True
        if getattr(request.user, "is_blocked", False) or not request.user.is_active:
            if getattr(request.user, "block_reason", None):
                self.message = f"Your account has been suspended or blocked. Reason: {request.user.block_reason}. Please contact support."
            return False
        return True


class IsAdminRole(permissions.BasePermission):
    """Allows access only to users with an administrator role."""
    message = "Administrator access required."

    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and not getattr(request.user, "is_blocked", False)
            and request.user.is_active
            and (getattr(request.user, "role", None) == "admin" or request.user.is_superuser or request.user.is_staff)
        )


class IsOwnerRole(permissions.BasePermission):
    """Allows access only to store owners."""
    message = "Store owner access required."

    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and not getattr(request.user, "is_blocked", False)
            and request.user.is_active
            and getattr(request.user, "role", None) == "owner"
        )


class IsCustomerRole(permissions.BasePermission):
    """Allows access only to customers."""
    message = "Customer account access required."

    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and not getattr(request.user, "is_blocked", False)
            and request.user.is_active
            and getattr(request.user, "role", None) == "customer"
        )


class HasAssignedModelPermission(DjangoModelPermissions):
    """Require the matching Django model permission for each HTTP method.

    Admin users have full access across all methods.
    Customers are restricted to safe read-only methods (GET, HEAD, OPTIONS)
    on catalog viewsets and are denied on destructive/management actions.
    """

    message = "You do not have permission to perform this action."

    perms_map = {
        "GET": ["%(app_label)s.view_%(model_name)s"],
        "OPTIONS": ["%(app_label)s.view_%(model_name)s"],
        "HEAD": ["%(app_label)s.view_%(model_name)s"],
        "POST": ["%(app_label)s.add_%(model_name)s"],
        "PUT": ["%(app_label)s.change_%(model_name)s"],
        "PATCH": ["%(app_label)s.change_%(model_name)s"],
        "DELETE": ["%(app_label)s.delete_%(model_name)s"],
    }

    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False

        # Admins and superusers bypass granular model permission checks
        if getattr(user, "role", None) == "admin" or user.is_superuser:
            return True

        # Customers can view catalog if safe read method, but are strictly blocked from writing
        if getattr(user, "role", None) == "customer":
            if request.method in SAFE_METHODS:
                if getattr(user, "_perm_cache", None) is not None:
                    delattr(user, "_perm_cache")
                if getattr(user, "_user_perm_cache", None) is not None:
                    delattr(user, "_user_perm_cache")
                return super().has_permission(request, view)
            return False

        if getattr(user, "_perm_cache", None) is not None:
            delattr(user, "_perm_cache")
        if getattr(user, "_user_perm_cache", None) is not None:
            delattr(user, "_user_perm_cache")
        return super().has_permission(request, view)

