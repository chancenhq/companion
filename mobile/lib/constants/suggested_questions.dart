import 'package:flutter/material.dart';

/// Suggested questions shown on the empty chat screen.
///
/// Keeps companion-new's `suggestedQuestions(BuildContext)` signature (the call
/// site in _EmptyState passes a context) but returns Chancen's ISA prompts.
/// TODO(i18n): localise these via AppLocalizations, as companion-new does for
/// its generic finance prompts (chatSuggestion* keys).
List<({IconData icon, String text})> suggestedQuestions(BuildContext context) {
  return const [
    (icon: Icons.help_outline,         text: 'What is a Chancen ISA?'),
    (icon: Icons.trending_up,          text: 'How does Chancen ISA impact my future income?'),
    (icon: Icons.attach_money,         text: 'Can I repay my Chancen ISA all at once?'),
    (icon: Icons.table_chart_outlined, text: 'How to budget in volatile situations?'),
  ];
}
