import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';
import 'glass_card.dart';

enum Tone { good, warn, bad, neutral }

/// Rounded status badge with a leading dot ("Occupied", "Hub online" ...).
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.tone});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    final (Color bg, Color fg) = switch (tone) {
      Tone.good => (e.accentSoft, e.greenInk),
      Tone.warn => (e.amberSoft, e.warnInk),
      Tone.bad => (e.redSoft, e.red),
      Tone.neutral => (e.chip, e.ink2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: EcoText.button(fg).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// "Your appliances ......... View all 4 ->"
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    return Padding(
      padding: const EdgeInsets.fromLTRB(1, 20, 1, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(title, style: EcoText.section(e))),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: e.accentDeep,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(action!, style: EcoText.button(e.accentDeep).copyWith(fontSize: 13)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: e.accentDeep),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Coloured info strip inside the presence card.
class StateBanner extends StatelessWidget {
  const StateBanner({
    super.key,
    required this.tone,
    required this.icon,
    required this.child,
    this.actions = const [],
  });

  final Tone tone;
  final IconData icon;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    final (Color bg, Color fg) = switch (tone) {
      Tone.good => (e.accentSoft, e.greenInk),
      Tone.warn => (e.amberSoft, e.ink),
      Tone.bad => (e.redSoft, e.ink),
      Tone.neutral => (e.chip, e.ink),
    };
    return Container(
      margin: const EdgeInsets.only(top: 13),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(17)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 16, color: fg),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DefaultTextStyle(
                  style: EcoText.small(e).copyWith(color: fg, fontSize: 14, height: 1.5),
                  child: child,
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

/// Small button used inside banners.
class SmallButton extends StatelessWidget {
  const SmallButton({super.key, required this.label, required this.onPressed, this.dark = false});

  final String label;
  final VoidCallback? onPressed;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    return SizedBox(
      height: 44,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: dark ? e.button : e.surface,
          foregroundColor: dark ? e.buttonFg : e.ink,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
            side: BorderSide(color: dark ? Colors.transparent : e.line),
          ),
        ),
        child: Text(
          label,
          style: EcoText.button(dark ? e.buttonFg : e.ink).copyWith(fontSize: 13),
        ),
      ),
    );
  }
}

/// Full-width outlined / filled buttons from the prototype.
class EcoButton extends StatelessWidget {
  const EcoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.icon,
    this.loading = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final IconData? icon;
  final bool loading;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    final fg = filled ? e.buttonFg : (danger ? e.red : e.ink);
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: TextButton(
        onPressed: loading ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: filled ? e.button : e.surface,
          foregroundColor: fg,
          disabledBackgroundColor: filled ? e.button.withValues(alpha: 0.5) : e.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: filled ? Colors.transparent : e.line),
          ),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 17, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Text(label, style: EcoText.button(fg).copyWith(fontSize: 14)),
                ],
              ),
      ),
    );
  }
}

/// Grey note with an info icon.
class HelpNote extends StatelessWidget {
  const HelpNote(this.text, {super.key, this.icon = Icons.info_outline_rounded, this.tone});

  final String text;
  final IconData icon;
  final Tone? tone;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    final bg = tone == Tone.warn ? e.amberSoft : e.chip;
    final fg = tone == Tone.warn ? e.warnInk : e.ink2;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: tone == Tone.warn ? e.warnInk : e.accentDeep),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: EcoText.small(e).copyWith(color: fg, height: 1.5))),
        ],
      ),
    );
  }
}

/// "No appliances added yet" style card.
class EmptyCard extends StatelessWidget {
  const EmptyCard(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: SizedBox(
        width: double.infinity,
        child: Text(text, textAlign: TextAlign.center, style: EcoText.small(e)),
      ),
    );
  }
}

/// Today / 7 days / 30 days style segmented control.
class EcoSegmented<T> extends StatelessWidget {
  const EcoSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final (v, label) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == value,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: v == value ? e.solid : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: v == value
                          ? const [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1))]
                          : null,
                    ),
                    child: Text(
                      label,
                      style: EcoText.button(v == value ? e.ink : e.ink2).copyWith(fontSize: 12.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Row of equal "choice" tiles (Auto/Manual, Light/Dark/System).
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          Expanded(
            child: Semantics(
              button: true,
              selected: options[i].$1 == value,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(options[i].$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 53,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: options[i].$1 == value ? e.accentSoft : e.chip,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: options[i].$1 == value ? e.accent : e.line,
                    ),
                  ),
                  child: Text(
                    options[i].$2,
                    style: EcoText.button(options[i].$1 == value ? e.greenInk : e.ink2)
                        .copyWith(fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Horizontal filter chips (All / Presence / Appliances / Alerts).
class FilterChips<T> extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final on = options[i].$1 == value;
          return Semantics(
            button: true,
            selected: on,
            child: GestureDetector(
              onTap: () => onChanged(options[i].$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? e.button : e.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: on ? Colors.transparent : e.border),
                ),
                child: Text(
                  options[i].$2,
                  style: EcoText.button(on ? e.buttonFg : e.ink2).copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Translucent square icon button (bell, close ...).
class EcoIconButton extends StatelessWidget {
  const EcoIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.dot = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: e.surface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: e.border),
                boxShadow: [BoxShadow(color: e.shadow, blurRadius: 20, offset: const Offset(0, 6))],
              ),
              child: Icon(icon, size: 20, color: e.ink),
            ),
            if (dot)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: e.amber,
                    shape: BoxShape.circle,
                    border: Border.all(color: e.solid, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Text field with the prototype's rounded, light-filled look.
InputDecoration ecoFieldDecoration(
  BuildContext context, {
  String? label,
  String? hint,
  IconData? prefixIcon,
  Widget? suffix,
  String? errorText,
}) {
  final e = context.eco;
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: errorText,
    prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20, color: e.ink2),
    suffixIcon: suffix,
    filled: true,
    fillColor: e.surface,
    labelStyle: EcoText.small(e),
    hintStyle: EcoText.small(e).copyWith(color: e.ink3),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    enabledBorder: b(e.line),
    focusedBorder: b(e.accent, 1.5),
    errorBorder: b(e.red),
    focusedErrorBorder: b(e.red, 1.5),
    disabledBorder: b(e.line),
  );
}
