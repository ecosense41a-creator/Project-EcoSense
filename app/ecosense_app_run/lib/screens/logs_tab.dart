import 'package:flutter/material.dart';

import '../config.dart';
import '../models/log_entry.dart';
import '../services/data_repository.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// Feature 4: a list of past events, newest first.
/// Source: /logs (last kLogLimit entries).
class LogsTab extends StatefulWidget {
  const LogsTab({super.key, required this.repo});

  final DataRepository repo;

  @override
  State<LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<LogsTab> {
  late final Stream<List<LogEntry>> _stream = widget.repo.recentLogs();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LogEntry>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MessageView(
            icon: Icons.cloud_off,
            isError: true,
            message: 'Could not load the event history.\n${snapshot.error}',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snapshot.data ?? const <LogEntry>[];
        if (logs.isEmpty) {
          return const MessageView(
            icon: Icons.history,
            message: 'No events yet.\nChanges in room occupancy will appear here.',
          );
        }

        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Latest ${logs.length} of up to $kLogLimit events',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: logs.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final log = logs[i];
                  final vacant = log.isVacantEvent;
                  final color = vacant ? Colors.blueGrey : Colors.green.shade600;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(
                        vacant ? Icons.person_off_outlined : Icons.person,
                        color: color,
                      ),
                    ),
                    title: Text(log.message),
                    subtitle: Text(
                      '${formatUnixTime(log.timestamp)}'
                      '${log.confidence != null ? '\nConfidence ${log.confidence!.round()}%' : ''}',
                    ),
                    isThreeLine: true,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
