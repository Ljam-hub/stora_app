import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("inventory", "0002_per_owner"),
        ("sales", "0002_per_owner"),
    ]

    operations = [
        migrations.AlterField(
            model_name="saleitem",
            name="product",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="sale_items",
                to="inventory.product",
            ),
        ),
    ]
