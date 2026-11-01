import 'package:flutter/material.dart';

import '../models/appliance_reading.dart';
import '../models/sensor_readings.dart';
import '../services/data_repository.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// Feature 3 & 9 & 10: raw readings from sensors and appliance control.
class SensorsTab extends StatefulWidget {
  const SensorsTab({super.key, required this.repo});

  final DataRepository repo;

  @override
  State<SensorsTab> createState() => _SensorsTabState();
}

class _SensorsTabState extends State<SensorsTab> {
  late final Stream<MmwaveReading?> _mmwave = widget.repo.mmwaveReading();
  late final Stream<DoorReading?> _door = widget.repo.doorReading();
  late final Stream<ApplianceReading?> _appliance = widget.repo.appliancePlug1();
  bool _requesting = false;

  Future<void> _toggleAppliance(ApplianceReading app) async {
    final newState = app.isOn ? 'off' : 'on';
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    setState(() => _requesting = true);
    try {
      await widget.repo.setAppliancePlug1Request(newState, nowSec);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update appliance: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SensorCard<MmwaveReading>(
          title: 'mmWave radar',
          icon: Icons.radar,
          stream: _mmwave,
          emptyText: 'No mmWave reading yet.',
          rowsBuilder: (r) => [
            InfoRow(label: 'Presence', value: r.presence ? 'Detected' : 'Not detected'),
            InfoRow(
              label: 'Distance',
              value: r.presence && r.distanceCm > 0 ? '${r.distanceCm} cm' : '—',
            ),
            InfoRow(label: 'Last read', value: formatAgeOfUnix(r.timestamp)),
            InfoRow(label: 'Time', value: formatUnixTime(r.timestamp)),
          ],
          pillBuilder: (r) => StatusPill(
            label: r.presence ? 'Detected' : 'Clear',
            color: r.presence ? Colors.green.shade600 : Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 8),
        _SensorCard<DoorReading>(
          title: 'Door sensor',
          icon: Icons.sensor_door_outlined,
          stream: _door,
          emptyText: 'No door reading yet.',
          rowsBuilder: (r) => [
            InfoRow(
              label: 'State',
              value: r.state.isEmpty ? 'unknown' : r.state,
            ),
            InfoRow(label: 'Last update', value: formatAgeOfUnix(r.timestamp)),
            InfoRow(label: 'Time', value: formatUnixTime(r.timestamp)),
          ],
          pillBuilder: (r) => StatusPill(
            label: r.isOpen ? 'Open' : 'Closed',
            color: r.isOpen ? Colors.orange.shade700 : Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 8),
        _SensorCard<ApplianceReading>(
          title: 'Appliance (Plug 1)',
          icon: Icons.power,
          stream: _appliance,
          emptyText: 'No appliance data yet.',
          rowsBuilder: (app) => [
            InfoRow(label: 'Name', value: app.name.isEmpty ? 'Plug 1' : app.name),
            InfoRow(label: 'State', value: app.state),
            InfoRow(label: 'Power', value: '${app.powerW.toStringAsFixed(1)} W'),
            InfoRow(label: 'Energy consumed', value: '${app.energyWh.toStringAsFixed(1)} Wh'),
            InfoRow(label: 'Estimated energy saved', value: '${app.savedWhEstimate.toStringAsFixed(1)} Wh'),
            InfoRow(label: 'Trigger type', value: app.triggerType),
            InfoRow(label: 'Last changed', value: formatAgeOfUnix(app.lastChanged)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _requesting ? null : () => _toggleAppliance(app),
                icon: Icon(app.isOn ? Icons.power_off : Icons.power),
                label: Text(app.isOn ? 'Turn Off' : 'Turn On'),
              ),
            ),
          ],
          pillBuilder: (app) => StatusPill(
            label: app.isOn ? 'On' : 'Off',
            color: app.isOn ? Colors.green.shade600 : Colors.grey,
          ),
        ),
      ],
    );
  }
}

/// One card that listens to one stream and shows its rows.
class _SensorCard<T> extends StatelessWidget {
  const _SensorCard({
    required this.title,
    required this.icon,
    required this.stream,
    required this.emptyText,
    required this.rowsBuilder,
    required this.pillBuilder,
  });

  final String title;
  final IconData icon;
  final Stream<T?> stream;
  final String emptyText;
  final List<Widget> Function(T reading) rowsBuilder;
  final Widget Function(T reading) pillBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<T?>(
          stream: stream,
          builder: (context, snapshot) {
            final reading = snapshot.data;

            Widget body;
            if (snapshot.hasError) {
              body = Text(
                'Could not load this sensor.\n${snapshot.error}',
                style: TextStyle(color: theme.colorScheme.error),
              );
            } else if (snapshot.connectionState == ConnectionState.waiting) {
              body = const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (reading == null) {
              body = Text(emptyText);
            } else {
              // TickBuilder keeps the "ago" values counting.
              body = TickBuilder(
                builder: (context) =>
                    Column(children: rowsBuilder(reading)),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleMedium),
                    ),
                    if (reading != null) pillBuilder(reading),
                  ],
                ),
                const SizedBox(height: 8),
                body,
              ],
            );
          },
        ),
      ),
    );
  }
}
