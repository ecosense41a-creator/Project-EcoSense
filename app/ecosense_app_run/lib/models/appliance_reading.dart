import '../utils/parse.dart';

/// /appliances/plug1
class ApplianceReading {
  const ApplianceReading({
    required this.name,
    required this.plugIp,
    required this.state,
    required this.triggerType,
    required this.lastChanged,
    required this.powerW,
    required this.energyWh,
    required this.savedWhEstimate,
    required this.meterUpdated,
    required this.requestedState,
    required this.requestedAt,
  });

  final String name;
  final String plugIp;
  final String state; // "on" or "off"
  final String triggerType; // "auto", "manual_override", "manual_plug"
  final int lastChanged; // Unix seconds
  final double powerW;
  final double energyWh;
  final double savedWhEstimate;
  final int meterUpdated; // Unix seconds
  final String requestedState; // "on" or "off"
  final int requestedAt; // Unix seconds

  bool get isOn => state == 'on';

  factory ApplianceReading.fromMap(Map<Object?, Object?> m) => ApplianceReading(
        name: asString(m['name']),
        plugIp: asString(m['plug_ip']),
        state: asString(m['state']),
        triggerType: asString(m['trigger_type']),
        lastChanged: asInt(m['last_changed']),
        powerW: asDouble(m['power_w']),
        energyWh: asDouble(m['energy_wh']),
        savedWhEstimate: asDouble(m['saved_wh_estimate']),
        meterUpdated: asInt(m['meter_updated']),
        requestedState: asString(m['requested_state']),
        requestedAt: asInt(m['requested_at']),
      );
}
