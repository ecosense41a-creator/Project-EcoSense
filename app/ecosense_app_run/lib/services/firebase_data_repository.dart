import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../config.dart';
import '../models/appliance_reading.dart';
import '../models/log_entry.dart';
import '../models/presence_status.dart';
import '../models/sensor_readings.dart';
import '../utils/parse.dart';
import 'data_repository.dart';

/// Reads the real Firebase Realtime Database.
class FirebaseDataRepository implements DataRepository {
  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://ecosense-capstone-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  @override
  Stream<PresenceStatus?> presenceStatus() =>
      _db.ref('status').onValue.map((event) {
        final map = asMap(event.snapshot.value);
        return map == null ? null : PresenceStatus.fromMap(map);
      });

  @override
  Stream<MmwaveReading?> mmwaveReading() =>
      _db.ref('sensors/mmwave').onValue.map((event) {
        final map = asMap(event.snapshot.value);
        return map == null ? null : MmwaveReading.fromMap(map);
      });

  @override
  Stream<DoorReading?> doorReading() =>
      _db.ref('sensors/door').onValue.map((event) {
        final map = asMap(event.snapshot.value);
        return map == null ? null : DoorReading.fromMap(map);
      });

  @override
  Stream<List<LogEntry>> recentLogs() => _db
          .ref('logs')
          .orderByKey() // auto-generated keys are in time order
          .limitToLast(kLogLimit) // only the newest N
          .onValue
          .map((event) {
        final entries = <LogEntry>[];
        for (final child in event.snapshot.children) {
          final map = asMap(child.value);
          if (map != null) {
            entries.add(LogEntry.fromMap(child.key ?? '', map));
          }
        }
        // Newest first.
        entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return entries;
      });

  @override
  Stream<ApplianceReading?> appliancePlug1() =>
      _db.ref('appliances/plug1').onValue.map((event) {
        final map = asMap(event.snapshot.value);
        return map == null ? null : ApplianceReading.fromMap(map);
      });

  @override
  Future<void> setAppliancePlug1Request(String requestedState, int requestedAt) async {
    await _db.ref('appliances/plug1').update({
      'requested_state': requestedState,
      'requested_at': requestedAt,
    });
  }

  @override
  Stream<int?> sustainedThresholdSeconds() =>
      _db.ref('config/sustained_threshold_seconds').onValue.map((event) {
        final val = event.snapshot.value;
        return val is num ? val.toInt() : null;
      });

  @override
  Future<void> setSustainedThresholdSeconds(int seconds) async {
    await _db.ref('config').update({
      'sustained_threshold_seconds': seconds,
    });
  }

  @override
  Future<int> serverTimeOffsetMs() async {
    try {
      final event = await _db
          .ref('.info/serverTimeOffset')
          .onValue
          .first
          .timeout(const Duration(seconds: 5));
      final value = event.snapshot.value;
      return value is num ? value.toInt() : 0;
    } catch (_) {
      return 0; // could not measure; assume clocks match
    }
  }
}
