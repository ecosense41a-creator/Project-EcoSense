import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';

/// Rebuilds its child every [interval] so "5s ago" labels and countdowns keep
/// moving without touching the data streams.
class TickBuilder extends StatefulWidget {
  const TickBuilder({
    super.key,
    required this.builder,
    this.interval = const Duration(seconds: 1),
  });

  final WidgetBuilder builder;
  final Duration interval;

  @override
  State<TickBuilder> createState() => _TickBuilderState();
}

class _TickBuilderState extends State<TickBuilder> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// Centered icon + message, for empty and error states.
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    final color = isError ? e.red : e.ink2;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: color),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: EcoText.body(e).copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// One "label ........ value" line inside a card.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: EcoText.small(e))),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: EcoText.strong(e, size: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
