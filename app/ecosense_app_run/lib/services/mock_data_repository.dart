import 'dart:async';

import '../config.dart';
import '../models/appliance_reading.dart';
import '../models/log_entry.dart';
import '../models/presence_status.dart';
import '../models/sensor_readings.dart';
import 'data_repository.dart';

/// Fake hub for development. Every 2 seconds it publishes a new reading and
/// replays a repeating 80-second scenario, so every screen state can be seen.
class MockDataRepository implements DataRepository {
  MockDataRepository() {
    _seedLogs();
    _tick();
    Timer.periodic(const Duration(seconds: 2), (_) => _tick());
  }

  static const int _cycleLength = 40;

  final int _startMs = DateTime.now().millisecondsSinceEpoch;

  final StreamController<PresenceStatus?> _statusCtrl =
      StreamController<PresenceStatus?>.broadcast();
  final StreamController<MmwaveReading?> _mmwaveCtrl =
      StreamController<MmwaveReading?>.broadcast();
  final StreamController<DoorReading?> _doorCtrl =
      StreamController<DoorReading?>.broadcast();
  final StreamController<List<LogEntry>> _logsCtrl =
      StreamController<List<LogEntry>>.broadcast();
  final StreamController<ApplianceReading?> _applianceCtrl =
      StreamController<ApplianceReading?>.broadcast();
  final StreamController<int?> _configCtrl =
      StreamController<int?>.broadcast();

  PresenceStatus? _status;
  MmwaveReading? _mmwave;
  DoorReading? _door;
  ApplianceReading? _appliance;
  int _sustainedThreshold = 30;

  final List<LogEntry> _logs = []; // newest first
  int _step = 0;
  bool _wasVacant = false;
  int _logCounter = 0;

  void _seedLogs() {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (var i = 0; i < 8; i++) {
      final vacant = i.isEven;
      _logs.insert(
        0,
        LogEntry(
          id: 'seed$i',
          type: 'occupancy',
          message: vacant ? 'Room became vacant' : 'Room became occupied',
          confidence: vacant ? 0 : 100,
          timestamp: nowSec - (8 - i) * 1500,
        ),
      );
    }
  }

  void _tick() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final nowSec = nowMs ~/ 1000;
    final s = _step % _cycleLength;
    _step++;

    var presence = true;
    var distance = 0;
    var doorOpen = false;
    var confidence = 100.0;
    var vacant = false;
    var suspect = false;
    var doorGateHold = false;

    if (s < 15) {
      distance = 140 + (s % 4) * 6;
    } else if (s < 30) {
      presence = false;
      confidence = (29 - s) / 14 * 100;
      vacant = s == 29;
    } else if (s < 34) {
      presence = false;
      confidence = 0;
      vacant = true;
    } else if (s < 37) {
      distance = 90;
      doorOpen = s < 36;
      confidence = 0;
      vacant = true;
      suspect = true;
      doorGateHold = true;
    } else {
      distance = 120 + (s % 3) * 5;
    }

    if (vacant != _wasVacant) {
      _addLog(
        vacant ? 'Room became vacant' : 'Room became occupied',
        confidence,
        nowSec,
        'occupancy',
      );
      _wasVacant = vacant;
    }

    _status = PresenceStatus(
      isVacant: vacant,
      occupancyConfidence: confidence,
      suspect: suspect,
      doorGateHold: doorGateHold,
      timestamp: nowSec,
      hubLastSeenMs: kMockHubOffline ? _startMs : nowMs,
      wifiRssi: -55 - (s % 5),
      uptimeSeconds: 3600 + (nowMs - _startMs) ~/ 1000,
    );
    _mmwave = MmwaveReading(
      presence: presence,
      distanceCm: presence ? distance : 0,
      timestamp: nowSec,
    );
    _door = DoorReading(state: doorOpen ? 'open' : 'closed', timestamp: nowSec);

    _appliance ??= ApplianceReading(
      name: 'Desk Plug',
      plugIp: '192.168.1.50',
      state: 'on',
      triggerType: 'auto',
      lastChanged: nowSec,
      powerW: 45.5,
      energyWh: 1250.0,
      savedWhEstimate: 340.0,
      meterUpdated: nowSec,
      requestedState: 'on',
      requestedAt: nowSec,
    );

    _statusCtrl.add(_status);
    _mmwaveCtrl.add(_mmwave);
    _doorCtrl.add(_door);
    _applianceCtrl.add(_appliance);
    _configCtrl.add(_sustainedThreshold);
  }

  void _addLog(String message, double? confidence, int timestamp, String type) {
    _logCounter++;
    _logs.insert(
      0,
      LogEntry(
        id: 'live$_logCounter',
        type: type,
        message: message,
        confidence: confidence,
        timestamp: timestamp,
      ),
    );
    if (_logs.length > kLogLimit) {
      _logs.removeRange(kLogLimit, _logs.length);
    }
    _logsCtrl.add(List<LogEntry>.of(_logs));
  }

  @override
  Stream<PresenceStatus?> presenceStatus() async* {
    yield _status;
    yield* _statusCtrl.stream;
  }

  @override
  Stream<MmwaveReading?> mmwaveReading() async* {
    yield _mmwave;
    yield* _mmwaveCtrl.stream;
  }

  @override
  Stream<DoorReading?> doorReading() async* {
    yield _door;
    yield* _doorCtrl.stream;
  }

  @override
  Stream<List<LogEntry>> recentLogs() async* {
    yield List<LogEntry>.of(_logs);
    yield* _logsCtrl.stream;
  }

  @override
  Stream<ApplianceReading?> appliancePlug1() async* {
    yield _appliance;
    yield* _applianceCtrl.stream;
  }

  @override
  Future<void> setAppliancePlug1Request(String requestedState, int requestedAt) async {
    if (_appliance != null) {
      _appliance = ApplianceReading(
        name: _appliance!.name,
        plugIp: _appliance!.plugIp,
        state: requestedState,
        triggerType: 'manual_override',
        lastChanged: requestedAt,
        powerW: requestedState == 'on' ? 45.0 : 0.0,
        energyWh: _appliance!.energyWh,
        savedWhEstimate: _appliance!.savedWhEstimate,
        meterUpdated: requestedAt,
        requestedState: requestedState,
        requestedAt: requestedAt,
      );
      _applianceCtrl.add(_appliance);
      _addLog('Appliance turned $requestedState', null, requestedAt, 'appliance');
    }
  }

  @override
  Stream<int?> sustainedThresholdSeconds() async* {
    yield _sustainedThreshold;
    yield* _configCtrl.stream;
  }

  @override
  Future<void> setSustainedThresholdSeconds(int seconds) async {
    _sustainedThreshold = seconds;
    _configCtrl.add(_sustainedThreshold);
  }

  @override
  Future<int> serverTimeOffsetMs() async => 0;
}
