import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../config.dart';
import '../models/automation_mode.dart';
import '../models/device.dart';
import '../models/energy.dart';
import '../models/log_entry.dart';
import '../models/presence_status.dart';
import '../models/room.dart';
import '../models/sensor_readings.dart';
import '../utils/parse.dart';
import 'data_repository.dart';

int _nowSec() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

String _slug(String name) {
  final s = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final base = s.isEmpty ? 'item' : (s.length > 24 ? s.substring(0, 24) : s);
  return '$base-${DateTime.now().millisecondsSinceEpoch % 100000}';
}

/// Reads and writes the real Firebase Realtime Database.
class FirebaseDataRepository implements DataRepository {
  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://ecosense-capstone-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  /// The primary room uses the original flat paths; others live in /rooms/<id>/.
  String _base(String roomId) =>
      roomId == kPrimaryRoomId ? '' : 'rooms/$roomId/';

  DatabaseReference _ref(String roomId, String rel) => _db.ref('${_base(roomId)}$rel');

  // ---- rooms -------------------------------------------------------------

  @override
  Stream<List<RoomInfo>> rooms() => _db.ref('room_index').onValue.map((event) {
        final list = <RoomInfo>[];
        for (final child in event.snapshot.children) {
          final key = child.key;
          if (key == null) continue;
          list.add(RoomInfo.fromMap(key, asMap(child.value)));
        }
        final primary = list.where((r) => r.id == kPrimaryRoomId).toList();
        final others = list.where((r) => r.id != kPrimaryRoomId).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return <RoomInfo>[
          primary.isNotEmpty ? primary.first : RoomInfo.primaryDefault(),
          ...others,
        ];
      });

  @override
  Future<String> addRoom(String name) async {
    final id = _slug(name);
    await _db.ref('room_index/$id').set({
      'name': name.trim(),
      'created_at': _nowSec(),
      'user_added': true,
      'pause_until': 0,
    });
    return id;
  }

  @override
  Future<void> setRoomPause(String roomId, int untilUnixSeconds) =>
      _db.ref('room_index/$roomId').update({'pause_until': untilUnixSeconds});

  // ---- live data ---------------------------------------------------------

  @override
  Stream<PresenceStatus?> presenceStatus(String roomId) =>
      _ref(roomId, 'status').onValue.map((event) {
        final map = asMap(event.snapshot.value);
        return map == null ? null : PresenceStatus.fromMap(map);
      });

  @override
  Stream<MmwaveReading?> mmwaveReading(String roomId) =>
      _ref(roomId, 'sensors/mmwave').onValue.map((event) {
        final map = asMap(event.snapshot.value);
        return map == null ? null : MmwaveReading.fromMap(map);
      });

  @override
  Stream<DoorReading?> doorReading(String roomId) =>
      _ref(roomId, 'sensors/door').onValue.map((event) {
        final map = asMap(event.snapshot.value);
        return map == null ? null : DoorReading.fromMap(map);
      });

  @override
  Stream<List<LogEntry>> recentLogs(String roomId) => _ref(roomId, 'logs')
          .orderByKey() // auto-generated keys are in time order
          .limitToLast(kLogLimit) // only the newest N
          .onValue
          .map((event) {
        final entries = <LogEntry>[];
        for (final child in event.snapshot.children) {
          final map = asMap(child.value);
          if (map != null) {
            entries.add(LogEntry.fromMap(child.key ?? '', map, roomId: roomId));
          }
        }
        entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return entries;
      });

  @override
  Stream<List<Device>> devices(String roomId) =>
      _ref(roomId, 'appliances').onValue.map((event) {
        final list = <Device>[];
        for (final child in event.snapshot.children) {
          final map = asMap(child.value);
          if (map != null && child.key != null) {
            list.add(Device.fromMap(child.key!, map));
          }
        }
        list.sort((a, b) {
          final c = a.createdAt.compareTo(b.createdAt);
          return c != 0 ? c : a.name.compareTo(b.name);
        });
        return list;
      });

  @override
  Future<void> requestDeviceState(String roomId, String deviceId, String state) =>
      _ref(roomId, 'appliances/$deviceId').update({
        'requested_state': state,
        'requested_at': _nowSec(),
      });

  @override
  Future<void> setDeviceCutoffAllowed(String roomId, String deviceId, bool allowed) =>
      _ref(roomId, 'appliances/$deviceId').update({'auto_cutoff_allowed': allowed});

  @override
  Future<void> addDevice(String roomId, String name, double ratedWatts) =>
      _ref(roomId, 'appliances/${_slug(name)}').set({
        'name': name.trim(),
        'rated_watts': ratedWatts,
        'plug_ip': '',
        'state': 'off',
        'requested_state': 'off',
        'requested_at': 0,
        'trigger_type': '',
        'last_changed': 0,
        'power_w': 0,
        'energy_wh': 0,
        'saved_wh_estimate': 0,
        'meter_updated': 0,
        'auto_cutoff_allowed': false,
        'created_at': _nowSec(),
      });

  @override
  Future<void> addLog(
    String roomId, {
    required String type,
    required String title,
    String detail = '',
    String severity = 'info',
  }) async {
    await _ref(roomId, 'logs').push().set({
      'type': type,
      'message': title, // older readers only know "message"
      'title': title,
      'detail': detail,
      'severity': severity,
      'source': 'app',
      'timestamp': _nowSec(),
    });
  }

  // ---- energy ------------------------------------------------------------

  /// "now" expressed in the fixed energy time zone, as a UTC-flagged DateTime
  /// (so .year/.month/.day/.hour are the energy-zone wall clock).
  DateTime _energyNow() =>
      DateTime.now().toUtc().add(const Duration(hours: kEnergyUtcOffsetHours));

  String _p(int n, [int w = 2]) => n.toString().padLeft(w, '0');

  @override
  Stream<EnergySeries> energySeries(String roomId, EnergyRange range) {
    final hourly = range == EnergyRange.day;
    final count = switch (range) {
      EnergyRange.day => 24,
      EnergyRange.week => 7,
      EnergyRange.month => 30,
    };
    final ref = _db.ref('energy/$roomId/${hourly ? 'hourly' : 'daily'}');
    return ref.orderByKey().limitToLast(count).onValue.map((event) {
      final byKey = <String, Map<Object?, Object?>>{};
      for (final child in event.snapshot.children) {
        final map = asMap(child.value);
        if (map != null && child.key != null) byKey[child.key!] = map;
      }
      final now = _energyNow();
      final points = <EnergyPoint>[];
      for (var i = count - 1; i >= 0; i--) {
        final DateTime t;
        final String key;
        if (hourly) {
          t = DateTime.utc(now.year, now.month, now.day, now.hour)
              .subtract(Duration(hours: i));
          key = '${_p(t.year, 4)}${_p(t.month)}${_p(t.day)}${_p(t.hour)}';
        } else {
          t = DateTime.utc(now.year, now.month, now.day).subtract(Duration(days: i));
          key = '${_p(t.year, 4)}${_p(t.month)}${_p(t.day)}';
        }
        final m = byKey[key];
        points.add(EnergyPoint(
          time: t,
          wh: m == null ? 0 : asDouble(m['wh']),
          savedWh: m == null ? 0 : asDouble(m['saved_wh']),
        ));
      }
      return EnergySeries(range: range, points: points);
    });
  }

  final Map<String, String> _lastSynced = {};

  @override
  Future<void> syncEnergy(String roomId, List<Device> devices) async {
    for (final d in devices) {
      if (d.energyWh <= 0 && d.savedWhEstimate <= 0) continue;
      final sig = '${d.energyWh}|${d.savedWhEstimate}';
      final memo = '$roomId/${d.id}';
      if (_lastSynced[memo] == sig) continue; // nothing new since our last look
      _lastSynced[memo] = sig;
      try {
        var prevWh = 0.0;
        var prevSaved = 0.0;
        final result = await _db.ref('energy_cursor/$roomId/${d.id}').runTransaction((Object? cur) {
          final m = asMap(cur);
          prevWh = m == null ? 0 : asDouble(m['energy_wh']);
          prevSaved = m == null ? 0 : asDouble(m['saved_wh']);
          if (m != null && prevWh == d.energyWh && prevSaved == d.savedWhEstimate) {
            return Transaction.abort(); // another phone already counted this
          }
          return Transaction.success({'energy_wh': d.energyWh, 'saved_wh': d.savedWhEstimate});
        });
        if (!result.committed) continue;
        // A counter that went DOWN was reset by the hub: count from zero again.
        double delta(double now, double prev) {
          final v = now >= prev ? now - prev : now;
          return v > 0 && v < 100000 ? v : 0;
        }

        final wh = delta(d.energyWh, prevWh);
        final saved = delta(d.savedWhEstimate, prevSaved);
        if (wh == 0 && saved == 0) continue;
        final ts = d.meterUpdated > 0 ? d.meterUpdated : _nowSec();
        final t = DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true)
            .add(const Duration(hours: kEnergyUtcOffsetHours));
        final day = '${_p(t.year, 4)}${_p(t.month)}${_p(t.day)}';
        final hour = '$day${_p(t.hour)}';
        final updates = <String, Object?>{};
        void add(String bucket, String key, String field, double v) {
          if (v > 0) updates['energy/$roomId/$bucket/$key/$field'] = ServerValue.increment(v);
        }

        add('hourly', hour, 'wh', wh);
        add('daily', day, 'wh', wh);
        add('hourly', hour, 'saved_wh', saved);
        add('daily', day, 'saved_wh', saved);
        await _db.ref().update(updates);
      } catch (_) {
        _lastSynced.remove(memo); // try again on the next change
      }
    }
  }

  // ---- global settings ---------------------------------------------------

  @override
  Stream<int?> sustainedThresholdSeconds() =>
      _db.ref('config/sustained_threshold_seconds').onValue.map((event) {
        final val = event.snapshot.value;
        return val is num ? val.toInt() : null;
      });

  @override
  Future<void> setSustainedThresholdSeconds(int seconds) =>
      _db.ref('config').update({'sustained_threshold_seconds': seconds});

  @override
  Stream<AutomationMode> automationMode() => _db
      .ref('config/automation_mode')
      .onValue
      .map((e) => AutomationMode.parse(e.snapshot.value));

  @override
  Future<void> setAutomationMode(AutomationMode mode) =>
      _db.ref('config').update({'automation_mode': mode.name});

  @override
  Stream<double> electricityRate() => _db.ref('config/electricity_rate_php').onValue.map((e) {
        final v = e.snapshot.value;
        return v is num ? v.toDouble() : kRateDefault;
      });

  @override
  Future<void> setElectricityRate(double phpPerKwh) =>
      _db.ref('config').update({'electricity_rate_php': phpPerKwh});

  // ---- per-user ----------------------------------------------------------

  @override
  Stream<String?> themePreference(String uid) =>
      _db.ref('users/$uid/prefs/theme').onValue.map((e) {
        final v = e.snapshot.value;
        return v is String ? v : null;
      });

  @override
  Future<void> setThemePreference(String uid, String value) =>
      _db.ref('users/$uid/prefs').update({'theme': value});

  @override
  Stream<int> notificationsLastRead(String uid) =>
      _db.ref('users/$uid/notifications_last_read').onValue.map((e) => asInt(e.snapshot.value));

  @override
  Future<void> markNotificationsRead(String uid) =>
      _db.ref('users/$uid').update({'notifications_last_read': _nowSec()});

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
