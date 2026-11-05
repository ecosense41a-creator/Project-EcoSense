import '../config.dart';
import 'device.dart';
import 'presence_status.dart';

enum RoomState { occupied, confirming, vacant, offline }

/// What the UI needs to know about a room, derived from /status.
class RoomView {
  const RoomView({required this.state, required this.status, required this.hubAgeSeconds});

  final RoomState state;
  final PresenceStatus? status;

  /// Seconds since the hub last reported (null = never).
  final int? hubAgeSeconds;

  bool get online => state != RoomState.offline;

  /// 0..100
  double get confidence =>
      (status?.occupancyConfidence ?? 0).clamp(0, 100).toDouble();

  /// Last known occupancy even when the hub is offline.
  bool get lastKnownVacant => status?.isVacant ?? false;
}

/// [serverOffsetMs] = Firebase clock minus phone clock (see serverTimeOffsetMs).
RoomView roomViewOf(PresenceStatus? s, int serverOffsetMs) {
  if (s == null) {
    return const RoomView(state: RoomState.offline, status: null, hubAgeSeconds: null);
  }
  final nowServerMs = DateTime.now().millisecondsSinceEpoch + serverOffsetMs;
  final int? age =
      s.hubLastSeenMs > 0 ? (nowServerMs - s.hubLastSeenMs) ~/ 1000 : null;
  final online = age != null && age <= kHubOfflineAfterSeconds;
  final RoomState state;
  if (!online) {
    state = RoomState.offline;
  } else if (s.isVacant) {
    state = RoomState.vacant;
  } else if (s.occupancyConfidence < 100) {
    state = RoomState.confirming;
  } else {
    state = RoomState.occupied;
  }
  return RoomView(state: state, status: s, hubAgeSeconds: age);
}

/// Status + appliances of one room, for lists and summaries.
class RoomLive {
  const RoomLive({required this.status, required this.devices});
  final PresenceStatus? status;
  final List<Device> devices;

  double totalWatts() => devices.fold<double>(0, (a, d) => a + d.watts);
}
