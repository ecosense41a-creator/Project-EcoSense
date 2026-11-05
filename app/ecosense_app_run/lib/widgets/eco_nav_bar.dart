import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';

class EcoNavItem {
  const EcoNavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Floating glass pill with 5 destinations (prototype bottom navigation).
class EcoNavBar extends StatelessWidget {
  const EcoNavBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<EcoNavItem> items;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    final r = BorderRadius.circular(28);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [BoxShadow(color: e.shadow, blurRadius: 28, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 68,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: e.surface,
              borderRadius: r,
              border: Border.all(color: e.border),
            ),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: items[i],
                      selected: i == selected,
                      onTap: () => onSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});

  final EcoNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: selected ? e.solid : Colors.transparent,
            borderRadius: BorderRadius.circular(21),
            boxShadow: selected
                ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2))]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 20, color: selected ? e.accentDeep : e.ink2),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: EcoText.button(selected ? e.ink : e.ink2).copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
