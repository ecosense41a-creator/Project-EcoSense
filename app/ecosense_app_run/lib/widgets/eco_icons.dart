import 'package:flutter/material.dart';

IconData deviceIconFor(String name) {
  final n = name.toLowerCase();
  if (RegExp(r'conditioner|aircon|\bac\b').hasMatch(n)) return Icons.ac_unit_rounded;
  if (RegExp(r'fan').hasMatch(n)) return Icons.air_rounded;
  if (RegExp(r'lamp|light|bulb').hasMatch(n)) return Icons.lightbulb_outline_rounded;
  if (RegExp(r'rice|kettle|cooker|oven|toaster|fridge|refrigerator|kitchen').hasMatch(n)) {
    return Icons.kitchen_outlined;
  }
  if (RegExp(r'monitor|pc\b|desktop|computer|laptop|tv|television').hasMatch(n)) {
    return Icons.desktop_windows_outlined;
  }
  return Icons.power_outlined;
}

IconData roomIconFor(String name) {
  final n = name.toLowerCase();
  if (RegExp(r'bed').hasMatch(n)) return Icons.bed_outlined;
  if (RegExp(r'kitchen').hasMatch(n)) return Icons.kitchen_outlined;
  if (RegExp(r'office|study').hasMatch(n)) return Icons.desktop_windows_outlined;
  return Icons.home_outlined;
}
