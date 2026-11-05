/// /config/automation_mode
enum AutomationMode {
  /// After a confirmed vacancy, appliances that the admin allowed are switched off.
  auto,

  /// EcoSense never switches anything by itself.
  manual;

  static AutomationMode parse(Object? v) =>
      v == 'manual' ? AutomationMode.manual : AutomationMode.auto;
}
