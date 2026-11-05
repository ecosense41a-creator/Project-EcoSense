import '../utils/parse.dart';

enum LogCategory { presence, appliance, alert }

/// One entry under <room base>/logs (one per change, never overwritten).
class LogEntry {
  const LogEntry({
    required this.id,
    required this.roomId,
    required this.type,
    required this.message,
    required this.confidence,
    required this.timestamp,
    this.titleField = '',
    this.detailField = '',
    this.severity = '',
  });

  /// Auto-generated Firebase key.
  final String id;

  /// Which room this entry belongs to (filled in by the repository).
  final String roomId;

  /// "occupancy", "appliance", "manual", "alert" or "error".
  final String type;

  /// Description of the event (always present, written by the hub).
  final String message;

  /// Confidence score at the moment of the change (only on occupancy logs).
  final double? confidence;

  /// Unix time in seconds.
  final int timestamp;

  /// Optional richer fields (new, written by the app or an updated hub).
  final String titleField;
  final String detailField;

  /// "info", "warn" or "error" (optional).
  final String severity;

  bool get isVacantEvent => message.toLowerCase().contains('vacant');

  String get title => titleField.isNotEmpty ? titleField : message;

  String get detail {
    if (detailField.isNotEmpty) return detailField;
    if (confidence != null) return 'Confidence ${confidence!.round()}%';
    return '';
  }

  LogCategory get category {
    if (type == 'alert' || type == 'error' || severity == 'warn' || severity == 'error') {
      return LogCategory.alert;
    }
    if (type == 'occupancy' || type == 'presence') return LogCategory.presence;
    return LogCategory.appliance;
  }

  factory LogEntry.fromMap(String id, Map<Object?, Object?> m, {String roomId = ''}) =>
      LogEntry(
        id: id,
        roomId: roomId,
        type: asString(m['type']),
        message: asString(m['message']),
        confidence: m['confidence'] != null ? asDouble(m['confidence']) : null,
        timestamp: asInt(m['timestamp']),
        titleField: asString(m['title']),
        detailField: asString(m['detail']),
        severity: asString(m['severity']),
      );
}
