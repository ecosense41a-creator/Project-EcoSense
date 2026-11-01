import '../models/appliance_reading.dart';
import '../models/log_entry.dart';
import '../models/presence_status.dart';
import '../models/sensor_readings.dart';

/// Everything the screens read. Each method matches one database path from the
/// Data Dictionary. All are LIVE streams: the screen updates by itself
/// whenever the hub writes new data.
abstract class DataRepository {
  /// /status  (fused result)
  Stream<PresenceStatus?> presenceStatus();

  /// /sensors/mmwave
  Stream<MmwaveReading?> mmwaveReading();

  /// /sensors/door
  Stream<DoorReading?> doorReading();

  /// /logs  (newest first, at most kLogLimit entries)
  Stream<List<LogEntry>> recentLogs();

  /// /appliances/plug1
  Stream<ApplianceReading?> appliancePlug1();

  /// Write requested state and timestamp to /appliances/plug1
  Future<void> setAppliancePlug1Request(String requestedState, int requestedAt);

  /// /config/sustained_threshold_seconds
  Stream<int?> sustainedThresholdSeconds();

  /// Write sustained threshold seconds to /config
  Future<void> setSustainedThresholdSeconds(int seconds);

  /// Difference between Firebase's clock and this phone's clock, in ms.
  /// Needed to judge "is the hub online" correctly if the phone clock is off.
  Future<int> serverTimeOffsetMs();
}
