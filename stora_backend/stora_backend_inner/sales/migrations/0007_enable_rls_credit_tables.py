"""
Enable Row Level Security on the Utang / Credit Ledger tables in the ``public`` schema:
- sales_customercredit
- sales_creditpayment
- sales_credititem

Context
-------
Supabase's PostgREST gateway exposes all tables in the ``public`` schema.
Without RLS, every newly added table is queryable via the public anon key.
Enabling RLS with default-deny prevents unauthorized PostgREST access while
allowing Django's connection (superuser/owner role) to continue operating seamlessly.
"""

from django.db import migrations

TABLES = [
    "sales_customercredit",
    "sales_creditpayment",
    "sales_credititem",
]


def enable_rls(apps, schema_editor):
    """Enable RLS on sales credit tables (forward migration)."""
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
        ("sales", "0006_customercredit_creditpayment_credititem"),
    ]

    operations = [
        migrations.RunPython(enable_rls, disable_rls),
    ]
