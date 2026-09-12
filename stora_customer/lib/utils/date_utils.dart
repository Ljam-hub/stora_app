final _tzSuffix = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

/// Parse an API timestamp and convert to Philippine Standard Time (PHT / UTC+8).
DateTime parseApiDateTimeToPht(String raw) {
  final trimmed = raw.trim();
  final parsed = DateTime.parse(trimmed);
  final utc = _tzSuffix.hasMatch(trimmed)
      ? parsed.toUtc()
      : DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
          parsed.microsecond,
        );
  return utc.add(const Duration(hours: 8));
}

/// Returns current DateTime in Philippine Standard Time (PHT / UTC+8).
DateTime nowInPht() {
  return DateTime.now().toUtc().add(const Duration(hours: 8));
}

/// Convert any DateTime to Philippine Standard Time (PHT / UTC+8).
DateTime toPht(DateTime dt) {
  final utc = dt.isUtc ? dt : dt.toUtc();
  return utc.add(const Duration(hours: 8));
}

/// Safely parse an API timestamp to Philippine Standard Time without throwing.
DateTime? tryParseApiDateTimeToPht(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    return parseApiDateTimeToPht(raw);
  } catch (_) {
    return null;
  }
}
