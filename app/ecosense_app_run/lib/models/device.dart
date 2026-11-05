import '../config.dart';
import '../utils/parse.dart';

enum CommandPhase { idle, pending, unconfirmed }

/// One appliance under <room base>/appliances/<deviceId>.
/// The original /appliances/plug1 node already has most of these fields.
class Device {
  const Device({
    required this.id,
    required this.name,
    required this.plugIp,
    required this.state,
    required this.triggerType,
    required this.lastChanged,
    required this.powerW,
    required this.ratedWatts,
    required this.energyWh,
    required this.savedWhEstimate,
    required this.meterUpdated,
    required this.requestedState,
    required this.requestedAt,
    required this.eligible,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String plugIp;
  final String state; // "on" or "off"
  final String triggerType; // "auto", "manual_override", "manual_plug", ...
  final int lastChanged; // Unix seconds
  final double powerW; // measured, 0 if the plug has no meter
  final double ratedWatts; // user-entered nameplate watts
  final double energyWh;
  final double savedWhEstimate;
  final int meterUpdated; // Unix seconds
  final String requestedState; // "on" / "off" / ""
  final int requestedAt; // Unix seconds

  /// The admin allows EcoSense to switch this appliance off after a confirmed
  /// vacancy (field: auto_cutoff_allowed).
  final bool eligible;
  final int createdAt;

  bool get isOn => state == 'on';

  /// Watts to show/sum: measured when available, otherwise the rated value.
  double get watts => !isOn ? 0 : (powerW > 0 ? powerW : ratedWatts);

  /// Switched off by EcoSense (not by a person) and still off.
  bool get switchedOffByAutomation => !isOn && triggerType == 'auto';

  /// A request is "open" when it asks for a different state than the plug
  /// reports, and was written after the plug last changed.
  bool get hasOpenRequest =>
      requestedState.isNotEmpty &&
      requestedState != state &&
      requestedAt > lastChanged;

  CommandPhase phase(int nowSeconds) {
    if (!hasOpenRequest) return CommandPhase.idle;
    return (nowSeconds - requestedAt) < kCommandTimeoutSeconds
        ? CommandPhase.pending
        : CommandPhase.unconfirmed;
  }

  Device copyWith({
    String? name,
    String? state,
    String? triggerType,
    int? lastChanged,
    double? powerW,
    double? ratedWatts,
    double? energyWh,
    double? savedWhEstimate,
    int? meterUpdated,
    String? requestedState,
    int? requestedAt,
    bool? eligible,
  }) =>
      Device(
        id: id,
        name: name ?? this.name,
        plugIp: plugIp,
        state: state ?? this.state,
        triggerType: triggerType ?? this.triggerType,
        lastChanged: lastChanged ?? this.lastChanged,
        powerW: powerW ?? this.powerW,
        ratedWatts: ratedWatts ?? this.ratedWatts,
        energyWh: energyWh ?? this.energyWh,
        savedWhEstimate: savedWhEstimate ?? this.savedWhEstimate,
        meterUpdated: meterUpdated ?? this.meterUpdated,
        requestedState: requestedState ?? this.requestedState,
        requestedAt: requestedAt ?? this.requestedAt,
        eligible: eligible ?? this.eligible,
        createdAt: createdAt,
      );

  factory Device.fromMap(String id, Map<Object?, Object?> m) => Device(
        id: id,
        name: asString(m['name']).isEmpty ? id : asString(m['name']),
        plugIp: asString(m['plug_ip']),
        state: asString(m['state']),
        triggerType: asString(m['trigger_type']),
        lastChanged: asInt(m['last_changed']),
        powerW: asDouble(m['power_w']),
        ratedWatts: asDouble(m['rated_watts']),
        energyWh: asDouble(m['energy_wh']),
        savedWhEstimate: asDouble(m['saved_wh_estimate']),
        meterUpdated: asInt(m['meter_updated']),
        requestedState: asString(m['requested_state']),
        requestedAt: asInt(m['requested_at']),
        // The original plug1 node predates this flag and the hub already cuts
        // it automatically, so a missing flag means "allowed" for plug1 only.
        eligible: m['auto_cutoff_allowed'] is bool
            ? m['auto_cutoff_allowed'] as bool
            : id == 'plug1',
        createdAt: asInt(m['created_at']),
      );
}
