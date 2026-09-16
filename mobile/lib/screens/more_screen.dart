import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'calendar_screen.dart';
import 'recent_transactions_screen.dart';

const _kPlayStoreUrl = 'https://play.google.com/store/apps/details?id=tech.chancen.companion';
const _kShareMessage =
    "I've been using Chancen Companion to track my ISA and stay on top of my finances. "
    "Check it out!\n\n"
    "$_kPlayStoreUrl";

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _shareApp(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    Share.share(
      _kShareMessage,
      subject: 'Try Chancen Companion',
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: ListView(
        children: [
          _buildMenuItem(
            context: context,
            icon: Icons.calendar_month,
            title: 'Account Calendar',
            subtitle: 'View monthly balance changes by account',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CalendarScreen()),
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          _buildMenuItem(
            context: context,
            icon: Icons.receipt_long,
            title: 'Recent Transactions',
            subtitle: 'View recent transactions across all accounts',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecentTransactionsScreen()),
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          _buildMenuItem(
            context: context,
            icon: Icons.share_rounded,
            title: 'Share Companion',
            subtitle: 'Invite friends and colleagues to the app',
            onTap: () => _shareApp(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: colorScheme.onPrimaryContainer),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle, style: TextStyle(color: colorScheme.onSurfaceVariant)),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
