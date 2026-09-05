from rest_framework.permissions import DjangoModelPermissions


class HasAssignedModelPermission(DjangoModelPermissions):
    """Require the matching Django model permission for each HTTP method.

    DjangoModelPermissions leaves GET/HEAD/OPTIONS with an empty perm list,
    so a user with every permission removed could still list and retrieve.
    Superusers continue to pass via User.has_perm.
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
        if getattr(user, "_perm_cache", None) is not None:
            delattr(user, "_perm_cache")
        if getattr(user, "_user_perm_cache", None) is not None:
            delattr(user, "_user_perm_cache")
        return super().has_permission(request, view)
