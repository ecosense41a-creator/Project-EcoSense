import '../config.dart';
import '../utils/parse.dart';

/// One entry of /room_index/<roomId>. The room's live data lives elsewhere:
///  - primary room  -> the original flat paths (/status, /sensors, ...)
///  - other rooms   -> /rooms/<roomId>/...
class RoomInfo {
  const RoomInfo({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.userAdded,
    required this.pauseUntil,
  });

  final String id;
  final String name;

  /// Unix seconds.
  final int createdAt;
  final bool userAdded;

  /// "Keep power on" override: automatic cut-off is skipped until this Unix
  /// time (seconds). 0 = no override.
  final int pauseUntil;

  bool isPausedAt(int nowSeconds) => pauseUntil > nowSeconds;

  factory RoomInfo.fromMap(String id, Map<Object?, Object?>? m) {
    final map = m ?? const <Object?, Object?>{};
    final name = asString(map['name']).trim();
    return RoomInfo(
      id: id,
      name: name.isNotEmpty
          ? name
          : (id == kPrimaryRoomId ? kPrimaryRoomName : id),
      createdAt: asInt(map['created_at']),
      userAdded: asBool(map['user_added']),
      pauseUntil: asInt(map['pause_until']),
    );
  }

  static RoomInfo primaryDefault() => const RoomInfo(
        id: kPrimaryRoomId,
        name: kPrimaryRoomName,
        createdAt: 0,
        userAdded: false,
        pauseUntil: 0,
      );
}
