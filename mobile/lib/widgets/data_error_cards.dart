import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Full error/empty-state card used when a data fetch fails and there's no
/// cached data to show: icon chip, title, body, and an optional Retry button.
///
/// Pass [onRetry] as null for failures the user can't action by retrying
/// (e.g. a service that isn't configured yet), which hides the button.
class DataErrorCard extends StatelessWidget {
  const DataErrorCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    this.onRetry,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.18),
            blurRadius: 0,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded, size: 16, color: iconColor),
              label: Text('Retry', style: TextStyle(color: iconColor)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact banner shown when stale cached data is on screen but the latest
/// refresh failed: last-synced time, a short status line, and an inline Retry.
class StaleDataBanner extends StatelessWidget {
  const StaleDataBanner({
    super.key,
    required this.lastSyncedAt,
    required this.onRetry,
    required this.isNetworkError,
  });

  final DateTime? lastSyncedAt;
  final Future<void> Function() onRetry;
  final bool isNetworkError;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('d MMM').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const color = Color(0xFFE53935);
    final syncText = lastSyncedAt != null
        ? 'Last synced ${_timeAgo(lastSyncedAt!)}'
        : 'Showing saved data';
    final statusText = isNetworkError
        ? 'No internet connection'
        : 'Could not refresh — showing saved data';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(
            isNetworkError ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  syncText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  statusText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Retry',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
