class TimezoneUtils {
  static const Duration _gmt8Offset = Duration(hours: 8);

  static DateTime toGmt8(DateTime value) => value.toUtc().add(_gmt8Offset);

  static String formatDate(DateTime value) {
    final gmt8 = toGmt8(value);
    return '${gmt8.year.toString().padLeft(4, '0')}-'
        '${gmt8.month.toString().padLeft(2, '0')}-'
        '${gmt8.day.toString().padLeft(2, '0')}';
  }

  static String formatTime(DateTime value, {bool includeSeconds = false}) {
    final gmt8 = toGmt8(value);
    final hour = gmt8.hour.toString().padLeft(2, '0');
    final minute = gmt8.minute.toString().padLeft(2, '0');
    if (!includeSeconds) return '$hour:$minute';
    final second = gmt8.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  static String formatDateTime(DateTime value, {bool includeSeconds = false}) {
    return '${formatDate(value)} ${formatTime(value, includeSeconds: includeSeconds)}';
  }

  static String toUtcIsoString(DateTime value) =>
      value.toUtc().toIso8601String();
}
