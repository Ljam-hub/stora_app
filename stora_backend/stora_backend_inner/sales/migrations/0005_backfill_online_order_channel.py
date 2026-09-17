from django.db import migrations


def backfill_online_orders(apps, schema_editor):
    Sale = apps.get_model("sales", "Sale")
    # Backfill channel for sales linked to orders or having an ORD- receipt number
    Sale.objects.filter(order__isnull=False).exclude(channel="online_order").update(channel="online_order")
    Sale.objects.filter(receipt_number__startswith="ORD-").exclude(channel="online_order").update(channel="online_order")


def reverse_backfill(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("sales", "0004_sale_channel_sale_customer_name_sale_order_and_more"),
    ]

    operations = [
        migrations.RunPython(backfill_online_orders, reverse_backfill),
    ]
