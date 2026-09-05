from django.db import migrations


def grant_existing_store_permissions(apps, schema_editor):
    User = apps.get_model("accounts", "User")
    Permission = apps.get_model("auth", "Permission")
    codenames = (
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
    perms = list(
        Permission.objects.filter(
            codename__in=codenames,
            content_type__app_label__in=("inventory", "sales"),
        )
    )
    if not perms:
        return
    through = User.user_permissions.through
    for user in User.objects.filter(is_superuser=False):
        through.objects.bulk_create(
            [
                through(user_id=user.pk, permission_id=perm.pk)
                for perm in perms
            ],
            ignore_conflicts=True,
        )


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0003_user_is_premium_user_premium_until_and_more"),
        ("inventory", "0002_per_owner"),
        ("sales", "0003_saleitem_product_nullable"),
        ("contenttypes", "0002_remove_content_type_name"),
    ]

    operations = [
        migrations.RunPython(grant_existing_store_permissions, noop),
    ]
