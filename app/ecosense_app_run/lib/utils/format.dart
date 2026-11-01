import 'package:intl/intl.dart';

/// "just now", "42s ago", "5m ago", "2h 10m ago", "3d ago"
String formatAge(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  if (s < 5) return 'just now';
  if (s < 60) return '${s}s ago';
  if (s < 3600) return '${s ~/ 60}m ago';
  if (s < 86400) return '${s ~/ 3600}h ${(s % 3600) ~/ 60}m ago';
  return '${s ~/ 86400}d ago';
}

/// Age of a Unix timestamp (seconds), measured against this phone's clock.
String formatAgeOfUnix(int unixSeconds) {
  if (unixSeconds <= 0) return 'no data';
  final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return formatAge(nowSeconds - unixSeconds);
}

/// Unix seconds -> local date and time, e.g. "Oct 8, 2026 • 3:42:10 PM".
String formatUnixTime(int unixSeconds) {
  if (unixSeconds <= 0) return '—';
  final dt = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
  return DateFormat('MMM d, y • h:mm:ss a').format(dt);
}

/// Seconds -> "2d 3h", "4h 12m", "7m 5s"
String formatUptime(int seconds) {
  final d = seconds ~/ 86400;
  final h = (seconds % 86400) ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (d > 0) return '${d}d ${h}h';
  if (h > 0) return '${h}h ${m}m';
  return '${m}m ${s}s';
}
