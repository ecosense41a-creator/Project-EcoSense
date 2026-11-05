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

/// "3:42 PM"
String formatClock(DateTime dt) => DateFormat('h:mm a').format(dt);

/// Seconds -> "4m 5s" / "42s" (same short format as formatHms)
String formatCountdown(int seconds) => formatHms(seconds);

/// 12 -> "₱12.00"
String peso(num n) => '₱${n.toStringAsFixed(2)}';

/// Event time: "3:42 AM" today, otherwise "Oct 8, 3:42 AM".
String formatEventTime(int unixSeconds) {
  if (unixSeconds <= 0) return '—';
  final dt = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
  final now = DateTime.now();
  final today = dt.year == now.year && dt.month == now.month && dt.day == now.day;
  return today ? DateFormat('h:mm a').format(dt) : DateFormat('MMM d, h:mm a').format(dt);
}

/// "Wh" -> "1.25 kWh" style, e.g. 21.7 -> "21.70".
String formatKwh(double kwh) => kwh.toStringAsFixed(2);

/// Converts a stored trigger type into a readable label.
String humanTrigger(String t) => switch (t) {
      'auto' => 'Automatic (vacancy)',
      'manual_override' => 'Manual (app)',
      'manual_plug' => 'Manual (plug button)',
      '' => '—',
      _ => t,
    };

/// Short duration: 0 -> "0s", 45 -> "45s", 3585 -> "59m 45s", 3600 -> "1h",
/// 3605 -> "1h 5s". Zero parts are hidden.
String formatHms(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  final parts = <String>[
    if (h > 0) '${h}h',
    if (m > 0) '${m}m',
    if (sec > 0 || (h == 0 && m == 0)) '${sec}s',
  ];
  return parts.join(' ');
}
