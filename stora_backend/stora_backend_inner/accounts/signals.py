from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import User
from .store_permissions import grant_store_permissions


@receiver(post_save, sender=User)
def assign_store_permissions(sender, instance, created, **kwargs):
    if created and not instance.is_superuser and getattr(instance, "role", "owner") == "owner":
        grant_store_permissions(instance)
