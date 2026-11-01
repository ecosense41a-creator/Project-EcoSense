import '../utils/parse.dart';

/// The fused result written by the hub at /status.
class PresenceStatus {
  const PresenceStatus({
    required this.isVacant,
    required this.occupancyConfidence,
    required this.suspect,
    required this.doorGateHold,
    required this.timestamp,
    required this.hubLastSeenMs,
    required this.wifiRssi,
    required this.uptimeSeconds,
  });

  /// true once confidence has fallen to 0.
  final bool isVacant;

  /// 0 to 100. 100 at the last confirmed presence, falling to 0 over the grace period.
  final double occupancyConfidence;

  /// Presence seen right after a door event and not trusted yet.
  final bool suspect;

  /// Door gate hold state.
  final bool doorGateHold;

  /// Unix time in SECONDS of this update.
  final int timestamp;

  /// Firebase server time in MILLISECONDS. Used to tell if the hub is online.
  final int hubLastSeenMs;

  /// Wi-Fi signal in dBm (closer to 0 is stronger).
  final int wifiRssi;

  final int uptimeSeconds;

  factory PresenceStatus.fromMap(Map<Object?, Object?> m) => PresenceStatus(
        isVacant: asBool(m['is_vacant']),
        occupancyConfidence: asDouble(m['occupancy_confidence']),
        suspect: asBool(m['suspect']),
        doorGateHold: asBool(m['door_gate_hold']),
        timestamp: asInt(m['timestamp']),
        hubLastSeenMs: asInt(m['hub_last_seen']),
        wifiRssi: asInt(m['wifi_rssi']),
        uptimeSeconds: asInt(m['uptime_seconds']),
      );
}
