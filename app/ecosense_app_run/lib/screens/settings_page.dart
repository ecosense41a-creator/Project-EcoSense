import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../config.dart';
import '../models/automation_mode.dart';
import '../theme/eco_theme.dart';
import '../utils/format.dart';
import '../widgets/eco_sheet.dart';
import '../widgets/eco_widgets.dart';
import '../widgets/glass_card.dart';

/// Automation mode, vacancy grace period, appearance, electricity rate, account.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.rateSectionKey,
    required this.rateEmphasis,
  });

  /// Lets the Insights screen scroll straight to the rate card.
  final GlobalKey rateSectionKey;

  /// true briefly after "Edit electricity rate" to highlight the card.
  final ValueNotifier<bool> rateEmphasis;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AutomationMode _mode = AutomationMode.auto;
  int _grace = kGraceDefaultSeconds;
  bool _draggingGrace = false;
  final _hCtrl = TextEditingController();
  final _mCtrl = TextEditingController();
  final _sCtrl = TextEditingController();
  final _hFocus = FocusNode();
  final _mFocus = FocusNode();
  final _sFocus = FocusNode();
  String? _graceError;
  Timer? _graceDebounce;
  double _rate = kRateDefault;
  bool _draggingRate = false;
  final _rateCtrl = TextEditingController(text: kRateDefault.toStringAsFixed(2));
  final _rateFocus = FocusNode();
  String? _rateError;
  Timer? _rateDebounce;
  final List<StreamSubscription<Object?>> _subs = [];
  bool _subscribed = false;

  @override
  void initState() {
    super.initState();
    _syncGraceFields();
    for (final f in [_hFocus, _mFocus, _sFocus]) {
      f.addListener(_onGraceFocus);
    }
  }

  bool get _graceFocused => _hFocus.hasFocus || _mFocus.hasFocus || _sFocus.hasFocus;

  void _syncGraceFields() {
    _hCtrl.text = '${_grace ~/ 3600}';
    _mCtrl.text = '${(_grace % 3600) ~/ 60}';
    _sCtrl.text = '${_grace % 60}';
  }

  // When the user leaves the boxes, show the last valid value again.
  void _onGraceFocus() {
    if (_graceFocused || !mounted) return;
    setState(() {
      _graceError = null;
      _syncGraceFields();
    });
  }

  void _onGraceText(String _) {
    final total = (int.tryParse(_hCtrl.text) ?? 0) * 3600 +
        (int.tryParse(_mCtrl.text) ?? 0) * 60 +
        (int.tryParse(_sCtrl.text) ?? 0);
    if (total < kGraceMinSeconds || total > kGraceMaxSeconds) {
      setState(() => _graceError =
          'Enter a time from ${formatHms(kGraceMinSeconds)} to ${formatHms(kGraceMaxSeconds)}.');
      return;
    }
    setState(() {
      _graceError = null;
      _grace = total;
    });
    _graceDebounce?.cancel();
    final repo = AppScope.of(context).repo;
    _graceDebounce = Timer(const Duration(milliseconds: 700), () {
      _run(() => repo.setSustainedThresholdSeconds(total), 'Could not save the grace period');
    });
  }

  void _resetGraceToDefault() {
    _graceDebounce?.cancel();
    FocusScope.of(context).unfocus();
    setState(() {
      _grace = kGraceDefaultSeconds;
      _graceError = null;
      _syncGraceFields();
    });
    _run(
      () => AppScope.of(context).repo.setSustainedThresholdSeconds(kGraceDefaultSeconds),
      'Could not save the grace period',
    );
    showEcoToast(context, 'Grace period reset to ${formatHms(kGraceDefaultSeconds)}');
  }

  Widget _hmsField(TextEditingController c, FocusNode f, String suffix) {
    return Expanded(
      child: TextField(
        controller: c,
        focusNode: f,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
        onChanged: _onGraceText,
        decoration: ecoFieldDecoration(context, errorText: _graceError == null ? null : '').copyWith(
          isDense: true,
          suffixText: suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 15),
          errorStyle: const TextStyle(height: 0),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscribed) return;
    _subscribed = true;
    final repo = AppScope.of(context).repo;
    _subs.add(repo.automationMode().listen((m) {
      if (mounted) setState(() => _mode = m);
    }));
    _subs.add(repo.sustainedThresholdSeconds().listen((s) {
      if (mounted && !_draggingGrace && !_graceFocused) {
        setState(() {
          _grace = (s ?? kGraceDefaultSeconds).clamp(kGraceMinSeconds, kGraceMaxSeconds);
          _graceError = null;
          _syncGraceFields();
        });
      }
    }));
    _subs.add(repo.electricityRate().listen((r) {
      if (!mounted || _draggingRate || _rateFocus.hasFocus) return;
      setState(() {
        _rate = r.clamp(kRateMin, kRateMax);
        _rateCtrl.text = _rate.toStringAsFixed(2);
        _rateError = null;
      });
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _graceDebounce?.cancel();
    for (final f in [_hFocus, _mFocus, _sFocus]) {
      f.dispose();
    }
    _hCtrl.dispose();
    _mCtrl.dispose();
    _sCtrl.dispose();
    _rateDebounce?.cancel();
    _rateCtrl.dispose();
    _rateFocus.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() op, String failure) async {
    try {
      await op();
    } catch (err) {
      if (mounted) showEcoToast(context, '$failure: $err');
    }
  }

  void _onRateText(String text) {
    final v = double.tryParse(text.trim());
    if (v == null || v < kRateMin || v > kRateMax) {
      setState(() => _rateError = 'Enter a rate from ${peso(kRateMin)} to ${peso(kRateMax)}.');
      return;
    }
    setState(() {
      _rateError = null;
      _rate = v;
    });
    _rateDebounce?.cancel();
    _rateDebounce = Timer(const Duration(milliseconds: 700), () {
      final repo = AppScope.of(context).repo;
      _run(() => repo.setElectricityRate((v * 100).round() / 100), 'Could not save the rate');
    });
  }

  Future<void> _confirmLogout(AppScope scope) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
        ],
      ),
    );
    if (ok == true) await scope.auth.signOut();
  }

  Widget _title(BuildContext context, IconData icon, String text) {
    final e = context.eco;
    return Row(
      children: [
        Icon(icon, size: 18, color: e.ink),
        const SizedBox(width: 8),
        Text(text, style: EcoText.strong(e, size: 15.5)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    final scope = AppScope.of(context);
    final repo = scope.repo;
    return ListView(
      padding: const EdgeInsets.fromLTRB(19, 4, 19, 128),
      children: [
        const SizedBox(height: 10),
        Text('Settings', style: EcoText.pageTitle(e)),
        const SizedBox(height: 6),
        Text('Make EcoSense work safely for your routine.', style: EcoText.pageSub(e)),
        const SizedBox(height: 19),

        // Automation mode
        GlassCard(
          padding: const EdgeInsets.all(17),
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title(context, Icons.shield_outlined, 'Automation mode'),
              const SizedBox(height: 6),
              Text(
                'Controls whether allowed appliances may turn off after a confirmed vacancy.',
                style: EcoText.small(e).copyWith(height: 1.5),
              ),
              const SizedBox(height: 12),
              ChoiceRow<AutomationMode>(
                options: const [
                  (AutomationMode.auto, 'Auto'),
                  (AutomationMode.manual, 'Manual'),
                ],
                value: _mode,
                onChanged: (m) {
                  setState(() => _mode = m);
                  _run(() => repo.setAutomationMode(m), 'Could not save the mode');
                },
              ),
              const SizedBox(height: 12),
              HelpNote(
                _mode == AutomationMode.auto
                    ? 'After vacancy confirmation, only opted-in appliances are switched off.'
                    : 'No automatic switching occurs; you control appliances yourself.',
              ),
            ],
          ),
        ),

        // Grace period
        GlassCard(
          padding: const EdgeInsets.all(17),
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title(context, Icons.schedule_rounded, 'Vacancy grace period'),
              const SizedBox(height: 6),
              Text(
                'Time without detected movement before the room can be marked vacant. '
                'Changes apply to new checks.',
                style: EcoText.small(e).copyWith(height: 1.5),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Applied period', style: EcoText.tiny(e).copyWith(fontSize: 12)),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 50,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(formatHms(_grace), style: EcoText.bigNumber(e, size: 22)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 190,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Enter grace period', style: EcoText.tiny(e).copyWith(fontSize: 12)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _hmsField(_hCtrl, _hFocus, 'h'),
                            const SizedBox(width: 6),
                            _hmsField(_mCtrl, _mFocus, 'm'),
                            const SizedBox(width: 6),
                            _hmsField(_sCtrl, _sFocus, 's'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_graceError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_graceError!, style: EcoText.tiny(e).copyWith(color: e.red)),
                ),
              const SizedBox(height: 12),
              Text('Or adjust using the slider', style: EcoText.tiny(e).copyWith(fontSize: 12)),
              Slider(
                value: _grace.toDouble().clamp(kGraceMinSeconds.toDouble(), kGraceMaxSeconds.toDouble()),
                min: kGraceMinSeconds.toDouble(),
                max: kGraceMaxSeconds.toDouble(),
                divisions: kGraceMaxSeconds - kGraceMinSeconds,
                label: formatHms(_grace),
                onChangeStart: (_) {
                  _draggingGrace = true;
                  FocusScope.of(context).unfocus();
                },
                onChanged: (v) => setState(() {
                  _grace = v.round();
                  _graceError = null;
                  _syncGraceFields();
                }),
                onChangeEnd: (v) {
                  _draggingGrace = false;
                  _graceDebounce?.cancel();
                  _run(
                    () => repo.setSustainedThresholdSeconds(v.round()),
                    'Could not save the grace period',
                  );
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatHms(kGraceMinSeconds), style: EcoText.tiny(e)),
                  Text(formatHms(kGraceMaxSeconds), style: EcoText.tiny(e)),
                ],
              ),
              const SizedBox(height: 12),
              EcoButton(
                label: 'Default (${formatHms(kGraceDefaultSeconds)})',
                icon: Icons.restart_alt_rounded,
                onPressed: _grace == kGraceDefaultSeconds && _graceError == null
                    ? null
                    : _resetGraceToDefault,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter hours, minutes and seconds. Changes save automatically.',
                style: EcoText.tiny(e),
              ),
            ],
          ),
        ),

        // Appearance
        ListenableBuilder(
          listenable: scope.theme,
          builder: (context, _) => GlassCard(
            padding: const EdgeInsets.all(17),
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(context, Icons.wb_sunny_outlined, 'Appearance'),
                const SizedBox(height: 12),
                ChoiceRow<String>(
                  options: const [('light', 'Light'), ('dark', 'Dark'), ('system', 'System')],
                  value: scope.theme.value,
                  onChanged: (v) {
                    scope.theme.set(v);
                    _run(() => repo.setThemePreference(scope.uid, v), 'Could not sync the theme');
                  },
                ),
              ],
            ),
          ),
        ),

        // Electricity rate
        ValueListenableBuilder<bool>(
          valueListenable: widget.rateEmphasis,
          builder: (context, emphasis, _) => GlassCard(
            key: widget.rateSectionKey,
            padding: const EdgeInsets.all(17),
            margin: const EdgeInsets.only(bottom: 12),
            borderColor: emphasis ? e.accent : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(context, Icons.bolt_rounded, 'Electricity rate'),
                const SizedBox(height: 6),
                Text(
                  'Used only for estimated energy cost, in Philippine pesos per kilowatt-hour.',
                  style: EcoText.small(e).copyWith(height: 1.5),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Applied rate', style: EcoText.tiny(e)),
                          const SizedBox(height: 4),
                          Text(peso(_rate), style: EcoText.bigNumber(e, size: 24)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: TextField(
                        controller: _rateCtrl,
                        focusNode: _rateFocus,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}(\.\d{0,2})?$')),
                        ],
                        onChanged: _onRateText,
                        decoration: ecoFieldDecoration(
                          context,
                          label: 'Exact rate',
                          errorText: _rateError == null ? null : '',
                        ).copyWith(prefixText: '₱ ', suffixText: '/kWh', errorStyle: const TextStyle(height: 0)),
                      ),
                    ),
                  ],
                ),
                if (_rateError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_rateError!, style: EcoText.tiny(e).copyWith(color: e.red)),
                  ),
                const SizedBox(height: 6),
                Slider(
                  value: _rate.clamp(kRateMin, kRateMax),
                  min: kRateMin,
                  max: kRateMax,
                  divisions: ((kRateMax - kRateMin) * 100).round(),
                  onChangeStart: (_) => _draggingRate = true,
                  onChanged: (v) => setState(() {
                    _rate = (v * 100).round() / 100;
                    _rateError = null;
                    _rateCtrl.text = _rate.toStringAsFixed(2);
                  }),
                  onChangeEnd: (v) {
                    _draggingRate = false;
                    _run(
                      () => repo.setElectricityRate((v * 100).round() / 100),
                      'Could not save the rate',
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(peso(kRateMin), style: EcoText.tiny(e)),
                    Text('${peso(kRateMax)} / kWh', style: EcoText.tiny(e)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Changes save automatically.', style: EcoText.tiny(e)),
              ],
            ),
          ),
        ),

        // Account
        GlassCard(
          padding: const EdgeInsets.all(17),
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: e.accent, borderRadius: BorderRadius.circular(15)),
                child: Text(
                  initialsOf(scope.username),
                  style: EcoText.button(e.onAccent).copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Signed in as', style: EcoText.tiny(e)),
                    const SizedBox(height: 2),
                    Text(
                      scope.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EcoText.strong(e, size: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        EcoButton(label: 'Log out', danger: true, onPressed: () => _confirmLogout(scope)),
      ],
    );
  }
}

/// "jane.doe@x.com" -> "JD", "admin" -> "AD".
String initialsOf(String username) {
  final local = username.split('@').first.trim();
  if (local.isEmpty) return '?';
  final parts = local.split(RegExp(r'[._\- ]+')).where((p) => p.isNotEmpty).toList();
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return local.substring(0, local.length >= 2 ? 2 : 1).toUpperCase();
}
