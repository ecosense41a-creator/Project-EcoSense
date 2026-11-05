import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';

/// Rounded bottom sheet from the prototype (grab handle, title, subtitle, close).
Future<T?> showEcoSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) => _EcoSheet(title: title, subtitle: subtitle, builder: builder),
  );
}

class _EcoSheet extends StatelessWidget {
  const _EcoSheet({required this.title, required this.subtitle, required this.builder});

  final String title;
  final String? subtitle;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [e.bg1, e.bg2],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
            border: Border.all(color: e.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 39,
                height: 4,
                margin: const EdgeInsets.only(top: 11, bottom: 15),
                decoration: BoxDecoration(
                  color: e.line,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: EcoText.section(e).copyWith(fontSize: 22),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(subtitle!, style: EcoText.small(e)),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.close_rounded, color: e.ink),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    28 + media.padding.bottom,
                  ),
                  child: Builder(builder: builder),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dark rounded toast above the navigation bar.
void showEcoToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final bottom = MediaQuery.of(context).padding.bottom;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 2900),
        margin: EdgeInsets.fromLTRB(19, 0, 19, 99 + bottom),
      ),
    );
}
