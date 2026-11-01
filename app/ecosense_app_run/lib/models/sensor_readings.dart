import '../utils/parse.dart';

/// /sensors/mmwave
class MmwaveReading {
  const MmwaveReading({
    required this.presence,
    required this.distanceCm,
    required this.timestamp,
  });

  /// The radar currently detects someone.
  final bool presence;

  /// Distance to the target in cm. 0 when nothing is detected.
  final int distanceCm;

  /// Unix time in seconds when it was read.
  final int timestamp;

  factory MmwaveReading.fromMap(Map<Object?, Object?> m) => MmwaveReading(
        presence: asBool(m['presence']),
        distanceCm: asInt(m['distance_cm']),
        timestamp: asInt(m['timestamp']),
      );
}

/// /sensors/door
class DoorReading {
  const DoorReading({required this.state, required this.timestamp});

  /// "open" or "closed".
  final String state;

  /// Unix time in seconds.
  final int timestamp;

  bool get isOpen => state == 'open';

  factory DoorReading.fromMap(Map<Object?, Object?> m) => DoorReading(
        state: asString(m['state']),
        timestamp: asInt(m['timestamp']),
      );
}
