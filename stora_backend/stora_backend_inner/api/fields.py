from datetime import timezone as dt_timezone

from django.utils import timezone
from rest_framework import serializers


class UTCDateTimeField(serializers.DateTimeField):
    """Serialize aware datetimes in UTC as ISO 8601 with an offset (…Z)."""

    def __init__(self, *args, **kwargs):
        kwargs.setdefault("default_timezone", dt_timezone.utc)
        super().__init__(*args, **kwargs)

    def to_representation(self, value):
        if value is None:
            return None
        if timezone.is_naive(value):
            value = timezone.make_aware(value, dt_timezone.utc)
        value = value.astimezone(dt_timezone.utc)
        iso = value.isoformat(timespec="microseconds")
        return iso.replace("+00:00", "Z")
