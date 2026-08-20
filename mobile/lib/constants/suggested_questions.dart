import 'package:flutter/material.dart';

/// Suggested questions shown on the empty chat screen.
///
/// l10n upgrade path: when Flutter localisation is added to the mobile app,
/// replace this const list with a function that accepts [BuildContext] and
/// returns localised strings via AppLocalizations. The call site in
/// _EmptyState requires only a one-line change.
const List<({IconData icon, String text})> suggestedQuestions = [
  (icon: Icons.help_outline,         text: 'What is a Chancen ISA?'),
  (icon: Icons.trending_up,          text: 'How does Chancen ISA impact my future income?'),
  (icon: Icons.attach_money,         text: 'Can I repay my Chancen ISA all at once?'),
  (icon: Icons.table_chart_outlined, text: 'How to budget in volatile situations?'),
];
