from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import User
from .store_permissions import grant_customer_permissions, grant_store_permissions


@receiver(post_save, sender=User)
def assign_role_permissions(sender, instance, created, **kwargs):
    if not created or instance.is_superuser:
        return

    role = getattr(instance, "role", User.ROLE_OWNER)
    if role == User.ROLE_OWNER:
        grant_store_permissions(instance)
    elif role == User.ROLE_CUSTOMER:
        grant_customer_permissions(instance)
    elif role == User.ROLE_ADMIN:
        if not instance.is_staff:
            instance.is_staff = True
            instance.save(update_fields=["is_staff"])

