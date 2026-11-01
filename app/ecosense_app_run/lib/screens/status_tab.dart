import 'package:flutter/material.dart';

import '../config.dart';
import '../models/presence_status.dart';
import '../services/data_repository.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// Feature 2: shows whether presence is detected (occupied or vacant).
/// Source: /status (the fused result written by the hub).
class StatusTab extends StatefulWidget {
  const StatusTab({super.key, required this.repo});

  final DataRepository repo;

  @override
  State<StatusTab> createState() => _StatusTabState();
}

enum _View { occupied, vacant, hubOffline }

class _StatusTabState extends State<StatusTab> {
  // Created ONCE. If we called repo.presenceStatus() inside build(), every
  // rebuild would open a new database listener.
  late final Stream<PresenceStatus?> _stream = widget.repo.presenceStatus();
  int _serverOffsetMs = 0;

  @override
  void initState() {
    super.initState();
    widget.repo.serverTimeOffsetMs().then((offset) {
      if (mounted) setState(() => _serverOffsetMs = offset);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PresenceStatus?>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MessageView(
            icon: Icons.cloud_off,
            isError: true,
            message: 'Could not load presence status.\n${snapshot.error}',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final status = snapshot.data;
        if (status == null) {
          return const MessageView(
            icon: Icons.sensors_off,
            message: 'No presence data yet.\nWaiting for the hub to publish /status.',
          );
        }
        // TickBuilder re-runs this every second so the "ago" texts keep counting.
        return TickBuilder(builder: (context) => _content(context, status));
      },
    );
  }

  Widget _content(BuildContext context, PresenceStatus status) {
    final nowServerMs = DateTime.now().millisecondsSinceEpoch + _serverOffsetMs;
    final int? hubAgeSeconds = status.hubLastSeenMs > 0
        ? (nowServerMs - status.hubLastSeenMs) ~/ 1000
        : null;
    final hubOnline =
        hubAgeSeconds != null && hubAgeSeconds <= kHubOfflineAfterSeconds;

    final view = !hubOnline
        ? _View.hubOffline
        : (status.isVacant ? _View.vacant : _View.occupied);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final confidence = status.occupancyConfidence.clamp(0, 100).toDouble();

    final (Color color, IconData icon, String title) = switch (view) {
      _View.occupied => (Colors.green.shade600, Icons.person, 'Occupied'),
      _View.vacant => (Colors.blueGrey, Icons.person_off_outlined, 'Vacant'),
      _View.hubOffline => (Colors.grey, Icons.cloud_off, 'Hub offline'),
    };

    final String detail = switch (view) {
      _View.occupied => confidence < 100
          ? 'No presence detected right now. Confirming before marking the room vacant.'
          : 'Presence confirmed.',
      _View.vacant => 'No presence confirmed in the room.',
      _View.hubOffline => hubAgeSeconds == null
          ? 'The hub has not reported in yet.'
          : 'Last heard from the hub ${formatAge(hubAgeSeconds)}. '
              'The reading below may be outdated '
              '(last known: ${status.isVacant ? 'vacant' : 'occupied'}).',
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // The one prominent element: the current state.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, size: 72, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (status.suspect) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Unconfirmed presence (suspect reading: seen right after a door event).',
                  ),
                ),
              ],
            ),
          ),
        ],
        if (status.doorGateHold) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Holding: door hasn\'t moved.',
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Occupancy confidence',
                          style: theme.textTheme.titleMedium),
                    ),
                    Text(
                      '${confidence.round()}%',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: confidence / 100,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 8),
                Text(
                  '100% at the last confirmed presence, falling to 0% over the grace period.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hub', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                InfoRow(
                  label: 'Last update',
                  value: formatAgeOfUnix(status.timestamp),
                ),
                InfoRow(
                  label: 'Heartbeat',
                  value:
                      hubAgeSeconds == null ? 'none' : formatAge(hubAgeSeconds),
                ),
                InfoRow(label: 'Wi-Fi signal', value: '${status.wifiRssi} dBm'),
                InfoRow(
                  label: 'Uptime',
                  value: formatUptime(status.uptimeSeconds),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
