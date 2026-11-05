import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_scope.dart';
import '../models/energy.dart';
import '../theme/eco_theme.dart';
import '../utils/format.dart';
import '../utils/stream_utils.dart';
import '../widgets/common.dart';
import '../widgets/eco_widgets.dart';
import '../widgets/energy_chart.dart';
import '../widgets/glass_card.dart';

/// Estimated energy use and savings for the selected room.
class InsightsPage extends StatefulWidget {
  const InsightsPage({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.range,
    required this.onRangeChanged,
    required this.onEditRate,
  });

  final String roomId;
  final String roomName;
  final EnergyRange range;
  final ValueChanged<EnergyRange> onRangeChanged;
  final VoidCallback onEditRate;

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  Stream<(EnergySeries, double)>? _stream;
  String _key = '';
  Object? _repo;
  int _selected = -1; // -1 = latest bucket

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind();
  }

  @override
  void didUpdateWidget(InsightsPage old) {
    super.didUpdateWidget(old);
    _bind();
  }

  void _bind() {
    final repo = AppScope.of(context).repo;
    final key = '${widget.roomId}|${widget.range.name}';
    if (_stream == null || key != _key || !identical(_repo, repo)) {
      _key = key;
      _repo = repo;
      _selected = -1;
      _stream = combine2<EnergySeries, double, (EnergySeries, double)>(
        repo.energySeries(widget.roomId, widget.range),
        repo.electricityRate(),
        (s, r) => (s, r),
      );
    }
  }

  String _label(EnergyRange r, DateTime t, {bool long = false, bool latest = false}) =>
      switch (r) {
        EnergyRange.day => latest ? 'Now' : DateFormat('h a').format(t),
        EnergyRange.week => DateFormat(long ? 'EEE, MMM d' : 'EEE').format(t),
        EnergyRange.month => DateFormat(long ? 'MMM d' : 'd').format(t),
      };

  List<int> _labelIndexes(int n) {
    final k = n <= 7 ? n : 7;
    if (k <= 1) return k == 1 ? [0] : [];
    return List<int>.generate(k, (i) => (i * (n - 1) / (k - 1)).round());
  }

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    return ListView(
      padding: const EdgeInsets.fromLTRB(19, 4, 19, 128),
      children: [
        const SizedBox(height: 10),
        Text('Energy insights', style: EcoText.pageTitle(e)),
        const SizedBox(height: 6),
        Text(
          'Energy and savings estimates for ${widget.roomName}.',
          style: EcoText.pageSub(e),
        ),
        const SizedBox(height: 19),
        EcoSegmented<EnergyRange>(
          options: const [
            (EnergyRange.day, 'Today'),
            (EnergyRange.week, '7 days'),
            (EnergyRange.month, '30 days'),
          ],
          value: widget.range,
          onChanged: widget.onRangeChanged,
        ),
        const SizedBox(height: 15),
        StreamBuilder<(EnergySeries, double)>(
          stream: _stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return MessageView(
                icon: Icons.cloud_off,
                isError: true,
                message: 'Could not load energy data.\n${snap.error}',
              );
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final (series, rate) = snap.data!;
            return _body(context, series, rate);
          },
        ),
      ],
    );
  }

  Widget _body(BuildContext context, EnergySeries series, double rate) {
    final e = context.eco;
    final pts = series.points;
    final sel = pts.isEmpty ? 0 : (_selected < 0 ? pts.length - 1 : _selected.clamp(0, pts.length - 1));
    final idx = _labelIndexes(pts.length);
    final rangeLabel = switch (widget.range) {
      EnergyRange.day => '24H',
      EnergyRange.week => '7D',
      EnergyRange.month => '30D',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          padding: const EdgeInsets.fromLTRB(17, 17, 17, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Estimated energy usage', style: EcoText.cardTitle(e)),
                  Text(rangeLabel, style: EcoText.tiny(e)),
                ],
              ),
              const SizedBox(height: 9),
              Text.rich(
                TextSpan(
                  text: formatKwh(series.totalKwh),
                  style: EcoText.bigNumber(e, size: 36),
                  children: [
                    TextSpan(text: ' kWh', style: EcoText.small(e).copyWith(fontSize: 15)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                pts.isEmpty
                    ? 'No data yet'
                    : 'Selected: ${_label(widget.range, pts[sel].time, long: true, latest: sel == pts.length - 1)} · '
                        '${formatKwh(pts[sel].wh / 1000)} kWh of estimated usage',
                style: EcoText.tiny(e).copyWith(fontSize: 12),
              ),
              const SizedBox(height: 14),
              EnergyChart(
                values: [for (final p in pts) p.wh],
                selected: sel,
                onSelect: (i) => setState(() => _selected = i),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final i in idx)
                    GestureDetector(
                      onTap: () => setState(() => _selected = i),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          _label(widget.range, pts[i].time, latest: i == pts.length - 1),
                          style: EcoText.small(e).copyWith(
                            fontSize: 12,
                            color: i == sel ? e.accentDeep : e.ink2,
                            fontWeight: i == sel ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                series.hasData
                    ? 'Based on your smart plugs’ energy meters. Savings are estimates.'
                    : 'No readings yet. The chart fills in as the smart plugs report their meters.',
                style: EcoText.tiny(e),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Estimated energy saved', style: EcoText.small(e)),
                    const SizedBox(height: 7),
                    Text.rich(
                      TextSpan(
                        text: formatKwh(series.savedKwh),
                        style: EcoText.bigNumber(e, size: 23),
                        children: [TextSpan(text: ' kWh', style: EcoText.tiny(e))],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Estimated cost saved', style: EcoText.small(e)),
                    const SizedBox(height: 7),
                    Text(peso(series.savedKwh * rate), style: EcoText.bigNumber(e, size: 23)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SectionHeader('How savings work'),
        GlassCard(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.eco_outlined, size: 18, color: e.accentDeep),
                  const SizedBox(width: 8),
                  Text('Transparent estimates', style: EcoText.strong(e, size: 15)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Estimated cost = estimated energy saved × your electricity rate. '
                'Example: a 40 W fan kept off for 3 hours saves 0.12 kWh, or '
                '${peso(0.12 * rate)} at your rate, if it would otherwise have stayed on.',
                style: EcoText.small(e).copyWith(height: 1.55),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Your current rate', style: EcoText.tiny(e)),
                  Text.rich(
                    TextSpan(
                      text: peso(rate),
                      style: EcoText.strong(e, size: 15),
                      children: [TextSpan(text: ' / kWh', style: EcoText.tiny(e))],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              EcoButton(
                label: 'Edit electricity rate',
                icon: Icons.arrow_forward_rounded,
                onPressed: widget.onEditRate,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
