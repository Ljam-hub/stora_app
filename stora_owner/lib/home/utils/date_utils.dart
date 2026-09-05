import 'package:timezone/timezone.dart' as tz;

const kManilaTimezone = 'Asia/Manila';

final _tzSuffix = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// Parse an API timestamp. Naive values are treated as UTC (Django storage).
DateTime parseApiDateTime(String raw) {
  final parsed = DateTime.parse(raw);
  if (!_tzSuffix.hasMatch(raw.trim())) {
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }
  return parsed.toUtc();
}

/// Wall-clock time in Asia/Manila (UTC+8), independent of the device timezone.
DateTime toManila(DateTime d) {
  final utc = d.isUtc ? d : d.toUtc();
  return tz.TZDateTime.from(utc, tz.getLocation(kManilaTimezone));
}

String formatFriendlyDate(DateTime d) {
  final local = toManila(d);
  return '${_weekdayNames[local.weekday - 1]}, ${_monthNames[local.month - 1]} ${local.day}';
}

String formatDateTime(DateTime d) {
  final local = toManila(d);
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${formatFriendlyDate(d)} · $hour12:$minute $period';
}

String formatManilaShortDateTime(DateTime d) {
  final local = toManila(d);
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${_monthNames[local.month - 1]} ${local.day}, $hour12:$minute $period';
}

bool isSameDay(DateTime a, DateTime b) {
  final ma = toManila(a);
  final mb = toManila(b);
  return ma.year == mb.year && ma.month == mb.month && ma.day == mb.day;
}
