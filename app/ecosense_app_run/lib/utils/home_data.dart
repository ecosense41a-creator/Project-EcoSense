import '../config.dart';
import '../models/automation_mode.dart';
import '../models/device.dart';
import '../models/energy.dart';
import '../models/presence_status.dart';
import '../models/sensor_readings.dart';
import '../services/data_repository.dart';
import 'stream_utils.dart';

/// Everything the room screen needs, as one snapshot.
class HomeData {
  const HomeData({
    required this.status,
    required this.mmwave,
    required this.door,
    required this.devices,
    required this.mode,
    required this.graceSeconds,
    required this.rate,
    required this.today,
  });

  final PresenceStatus? status;
  final MmwaveReading? mmwave;
  final DoorReading? door;
  final List<Device> devices;
  final AutomationMode mode;
  final int graceSeconds;
  final double rate;
  final EnergySeries today;
}

/// Combines live room readings and settings for the home screen.
Stream<HomeData> homeDataStream(DataRepository repo, String roomId) {
  final streams = <Stream<Object?>>[
    repo.presenceStatus(roomId),
    repo.mmwaveReading(roomId),
    repo.doorReading(roomId),
    repo.devices(roomId),
    repo.automationMode(),
    repo.sustainedThresholdSeconds(),
    repo.electricityRate(),
    repo.energySeries(roomId, EnergyRange.day),
  ];
  return combineList<Object?>(streams).map(
    (v) => HomeData(
      status: v[0] as PresenceStatus?,
      mmwave: v[1] as MmwaveReading?,
      door: v[2] as DoorReading?,
      devices: v[3] as List<Device>,
      mode: v[4] as AutomationMode,
      graceSeconds: (v[5] as int?) ?? kGraceDefaultSeconds,
      rate: v[6] as double,
      today: v[7] as EnergySeries,
    ),
  );
}
