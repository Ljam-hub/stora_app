from django.contrib.auth.models import Permission

STORE_PERMISSION_CODENAMES = (
    "add_category",
    "change_category",
    "delete_category",
    "view_category",
    "add_product",
    "change_product",
    "delete_product",
    "view_product",
    "add_sale",
    "change_sale",
    "delete_sale",
    "view_sale",
)


def store_permission_queryset():
    return Permission.objects.filter(
        codename__in=STORE_PERMISSION_CODENAMES,
        content_type__app_label__in=("inventory", "sales"),
    )


def grant_store_permissions(user):
    """Give a store owner the model perms the API ViewSets require."""
    perms = list(store_permission_queryset())
    if perms:
        user.user_permissions.add(*perms)
    if getattr(user, "_perm_cache", None) is not None:
        delattr(user, "_perm_cache")
    if getattr(user, "_user_perm_cache", None) is not None:
        delattr(user, "_user_perm_cache")
