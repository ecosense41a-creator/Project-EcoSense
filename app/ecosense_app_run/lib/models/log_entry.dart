import '../utils/parse.dart';

/// One entry under /logs (one per change, never overwritten).
class LogEntry {
  const LogEntry({
    required this.id,
    required this.type,
    required this.message,
    required this.confidence,
    required this.timestamp,
  });

  /// Auto-generated Firebase key.
  final String id;

  /// "occupancy" or "appliance".
  final String type;

  /// Description of the event.
  final String message;

  /// Confidence score at the moment of the change (only on occupancy logs).
  final double? confidence;

  /// Unix time in seconds.
  final int timestamp;

  bool get isVacantEvent => message.toLowerCase().contains('vacant');

  factory LogEntry.fromMap(String id, Map<Object?, Object?> m) => LogEntry(
        id: id,
        type: asString(m['type']),
        message: asString(m['message']),
        confidence: m['confidence'] != null ? asDouble(m['confidence']) : null,
        timestamp: asInt(m['timestamp']),
      );
}
