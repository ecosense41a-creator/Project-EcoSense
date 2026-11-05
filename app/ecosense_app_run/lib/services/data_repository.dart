import '../models/automation_mode.dart';
import '../models/device.dart';
import '../models/energy.dart';
import '../models/log_entry.dart';
import '../models/presence_status.dart';
import '../models/room.dart';
import '../models/sensor_readings.dart';

/// Everything the screens read or write. All reads are LIVE streams: the
/// screen updates by itself whenever the hub (or another phone) writes.
///
/// Database layout (see backend/DATABASE_SCHEMA.md):
///  - primary room ("living") keeps the ORIGINAL flat paths, so the existing
///    hub keeps working: /status, /sensors/*, /logs, /appliances/*
///  - every other room mirrors that shape under /rooms/<roomId>/
abstract class DataRepository {
  // ---- rooms -------------------------------------------------------------

  /// /room_index. Always contains the primary room, first in the list.
  Stream<List<RoomInfo>> rooms();

  /// Creates /room_index/<id>. Returns the new room id.
  Future<String> addRoom(String name);

  /// Sets /room_index/<id>/pause_until (Unix seconds). 0 clears the override.
  Future<void> setRoomPause(String roomId, int untilUnixSeconds);

  // ---- live data of one room --------------------------------------------

  /// <room>/status  (fused result written by the hub)
  Stream<PresenceStatus?> presenceStatus(String roomId);

  /// <room>/sensors/mmwave
  Stream<MmwaveReading?> mmwaveReading(String roomId);

  /// <room>/sensors/door
  Stream<DoorReading?> doorReading(String roomId);

  /// <room>/logs (newest first, at most kLogLimit entries)
  Stream<List<LogEntry>> recentLogs(String roomId);

  /// <room>/appliances/*
  Stream<List<Device>> devices(String roomId);

  /// Writes requested_state + requested_at; the hub applies it to the plug.
  Future<void> requestDeviceState(String roomId, String deviceId, String state);

  /// Writes auto_cutoff_allowed.
  Future<void> setDeviceCutoffAllowed(String roomId, String deviceId, bool allowed);

  /// Creates <room>/appliances/<id> (state off, cut-off NOT allowed).
  Future<void> addDevice(String roomId, String name, double ratedWatts);

  /// Appends an entry to <room>/logs (used for actions taken in the app).
  Future<void> addLog(
    String roomId, {
    required String type,
    required String title,
    String detail = '',
    String severity = 'info',
  });

  // ---- energy ------------------------------------------------------------

  /// /energy/<roomId>/hourly (day) or /daily (week, month), gap-filled.
  Stream<EnergySeries> energySeries(String roomId, EnergyRange range);

  /// Adds new energy (since the last sync) from the appliances' counters
  /// (energy_wh, saved_wh_estimate) into /energy buckets. Safe to call from
  /// several phones: a transaction on /energy_cursor claims each change once.
  Future<void> syncEnergy(String roomId, List<Device> devices);

  // ---- global settings (/config) -----------------------------------------

  /// /config/sustained_threshold_seconds (vacancy grace period)
  Stream<int?> sustainedThresholdSeconds();
  Future<void> setSustainedThresholdSeconds(int seconds);

  /// /config/automation_mode
  Stream<AutomationMode> automationMode();
  Future<void> setAutomationMode(AutomationMode mode);

  /// /config/electricity_rate_php
  Stream<double> electricityRate();
  Future<void> setElectricityRate(double phpPerKwh);

  // ---- per-user (/users/<uid>) -------------------------------------------

  /// "light", "dark" or "system"
  Stream<String?> themePreference(String uid);
  Future<void> setThemePreference(String uid, String value);

  /// Unix seconds of the last time the user opened notifications (0 = never).
  Stream<int> notificationsLastRead(String uid);
  Future<void> markNotificationsRead(String uid);

  /// Difference between Firebase's clock and this phone's clock, in ms.
  /// Needed to judge "is the hub online" correctly if the phone clock is off.
  Future<int> serverTimeOffsetMs();
}
