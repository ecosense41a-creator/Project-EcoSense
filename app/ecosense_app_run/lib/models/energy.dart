enum EnergyRange { day, week, month }

/// One bucket of /energy/<roomId>/hourly|daily/<key>.
class EnergyPoint {
  const EnergyPoint({required this.time, required this.wh, required this.savedWh});

  /// Bucket start. Fields are already in the app's fixed energy time zone
  /// (kEnergyUtcOffsetHours): read hour/day directly, do NOT call toLocal().
  final DateTime time;
  final double wh;
  final double savedWh;
}

class EnergySeries {
  const EnergySeries({required this.range, required this.points});

  final EnergyRange range;
  final List<EnergyPoint> points;

  double get totalKwh => points.fold<double>(0, (a, p) => a + p.wh) / 1000;
  double get savedKwh => points.fold<double>(0, (a, p) => a + p.savedWh) / 1000;
  bool get hasData => points.any((p) => p.wh > 0 || p.savedWh > 0);

  static EnergySeries empty(EnergyRange r) => EnergySeries(range: r, points: const []);
}
