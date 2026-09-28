"""
Enable Row Level Security on every table in the ``public`` schema and create
a default-deny policy for the Supabase ``anon`` and ``authenticated`` roles.

Context
-------
Supabase's PostgREST gateway exposes all tables in the ``public`` schema.
Without RLS every table is readable/writable by anyone with the anon or
service-role key.  Because this project uses Django REST Framework + JWT
for all API access, the PostgREST surface should be completely locked down.

How it works
------------
* ``ALTER TABLE … ENABLE ROW LEVEL SECURITY`` turns on RLS.
* Because **no** permissive policy is created, the default for ``anon`` and
  ``authenticated`` is *deny-all* (SELECT / INSERT / UPDATE / DELETE).
* Django's database connection uses the **owner** role, which is exempt from
  RLS, so all existing Django ORM queries keep working unchanged.
"""

from django.db import migrations

# Every table flagged by the Supabase linter, grouped by Django app.
TABLES = [
    # ── Django internals ──────────────────────────────────────────────
    "django_migrations",
    "django_content_type",
    "django_admin_log",
    "django_session",
    # ── django.contrib.auth ───────────────────────────────────────────
    "auth_permission",
    "auth_group",
    "auth_group_permissions",
    # ── accounts ──────────────────────────────────────────────────────
    "accounts_user",
    "accounts_user_groups",
    "accounts_user_user_permissions",
    "accounts_pendingregistration",
    "accounts_emailverificationcode",
    "accounts_passwordresettoken",
    "accounts_paymentproof",
    "accounts_subscriptionconfig",
    "accounts_storelocation",
    "accounts_aiinsight",
    # ── inventory ─────────────────────────────────────────────────────
    "inventory_category",
    "inventory_product",
    # ── sales ─────────────────────────────────────────────────────────
    "sales_sale",
    "sales_saleitem",
    # ── orders ────────────────────────────────────────────────────────
    "orders_order",
    "orders_orderitem",
    # ── api ────────────────────────────────────────────────────────────
    "api_userreport",
    "api_chatmessage",
    "api_chatmessage_deleted_by_users",
    "api_blockedcustomer",
]


def enable_rls(apps, schema_editor):
    """Enable RLS on every listed table (forward migration)."""
    if schema_editor.connection.vendor != "postgresql":
        return
    for table in TABLES:
        schema_editor.execute(
            f'ALTER TABLE IF EXISTS public."{table}" ENABLE ROW LEVEL SECURITY;'
        )


def disable_rls(apps, schema_editor):
    """Disable RLS so the migration can be safely reversed."""
    if schema_editor.connection.vendor != "postgresql":
        return
    for table in TABLES:
        schema_editor.execute(
            f'ALTER TABLE IF EXISTS public."{table}" DISABLE ROW LEVEL SECURITY;'
        )


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0016_storelocation_is_open"),
        # Ensure tables from other apps exist before we ALTER them.
        ("inventory", "0005_change_product_category_to_protect"),
        ("sales", "0005_backfill_online_order_channel"),
        ("orders", "0004_add_status_completed_to_order"),
        ("api", "0007_remove_blockedcustomer_reason"),
    ]

    operations = [
        migrations.RunPython(enable_rls, disable_rls),
    ]
