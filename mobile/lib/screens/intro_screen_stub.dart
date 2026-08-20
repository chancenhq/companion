import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'chat_conversation_screen.dart';

const Color _kGreen  = Color(0xFF84BD00);
const Color _kDarkGreen = Color(0xFF1F4834);
const Color _kPurple = Color(0xFF986EF9);

class InsightsPreviewScreen extends StatefulWidget {
  const InsightsPreviewScreen({super.key});

  @override
  State<InsightsPreviewScreen> createState() => _InsightsPreviewScreenState();
}

class _InsightsPreviewScreenState extends State<InsightsPreviewScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const _AccountSummaryView();
  }
}

class _AccountSummaryView extends StatelessWidget {
  const _AccountSummaryView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstName = context.watch<AuthProvider>().user?.firstName ?? 'there';
    final bg = theme.brightness == Brightness.light ? Colors.white : Colors.black;
    return ColoredBox(
      color: bg,
      child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GreetingCard(firstName: firstName, theme: theme),
          const SizedBox(height: 8),
          _AskAnythingTile(theme: theme),
          const SizedBox(height: 20),
          _SectionHeaderTile(theme: theme),
          const SizedBox(height: 16),
          _IsaFinancingCard(theme: theme),
          const SizedBox(height: 12),
          _IsaInstalmentsCard(theme: theme),
        ],
      ),
    ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.firstName, required this.theme});

  final String firstName;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, $firstName!',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your partner from learning to earning.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AskAnythingTile extends StatelessWidget {
  const _AskAnythingTile({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _kPurple.withValues(alpha: 0.25),
            blurRadius: 0,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: Card(
      margin: EdgeInsets.zero,
      color: theme.brightness == Brightness.light ? Colors.white : Colors.black,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ChatConversationScreen(chatId: null),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _kPurple.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: _kPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ask me anything',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _kPurple,
                      ),
                    ),
                    Text(
                      'Get instant answers about your ISA',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _SectionHeaderTile extends StatelessWidget {
  const _SectionHeaderTile({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Account',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Live data - Coming soon',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

enum IsaStatus {
  contractSigned,
  repaying,
  paused,
  serviceFeeMode,
  completed,
  defaulted,
}

extension IsaStatusDisplay on IsaStatus {
  String get label {
    switch (this) {
      case IsaStatus.contractSigned: return 'Graduated';
      case IsaStatus.repaying:       return 'Repaying';
      case IsaStatus.paused:         return 'Paused';
      case IsaStatus.serviceFeeMode: return 'Service Fee Mode';
      case IsaStatus.completed:      return 'Completed';
      case IsaStatus.defaulted:      return 'Defaulted';
    }
  }

  Color get color {
    switch (this) {
      case IsaStatus.contractSigned: return _kDarkGreen;
      case IsaStatus.repaying:       return const Color(0xFF10A861);
      case IsaStatus.paused:         return const Color(0xFFFFA726);
      case IsaStatus.serviceFeeMode: return const Color(0xFFFFA726);
      case IsaStatus.completed:      return const Color(0xFF10A861);
      case IsaStatus.defaulted:      return const Color(0xFFE53935);
    }
  }

  IconData get icon {
    switch (this) {
      case IsaStatus.contractSigned: return Icons.verified_outlined;
      case IsaStatus.repaying:       return Icons.trending_up;
      case IsaStatus.paused:         return Icons.pause_circle_outline;
      case IsaStatus.serviceFeeMode: return Icons.work_off_outlined;
      case IsaStatus.completed:      return Icons.check_circle_outline;
      case IsaStatus.defaulted:      return Icons.warning_amber_outlined;
    }
  }
}

class _IsaFinancingCard extends StatelessWidget {
  const _IsaFinancingCard({required this.theme});

  final ThemeData theme;

  static const _amountPaid    = 'KSh 45,000';
  static const _totalFinanced = 'KSh 268,240';
  static const _status        = IsaStatus.contractSigned;

  @override
  Widget build(BuildContext context) {
    final statusColor = (_status == IsaStatus.contractSigned && theme.brightness == Brightness.dark)
        ? _kGreen
        : _status.color;

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (theme.brightness == Brightness.light ? _kDarkGreen : _kGreen).withValues(alpha: 0.18),
            blurRadius: 0,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(_IsaIcons.financing, color: _kGreen, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  'ISA Financing',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_status.icon, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        _status.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Repayments Received',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Coming Soon',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 20),
            Divider(height: 1, color: theme.dividerColor),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _StatItem(
                    label: 'Repayments\nReceived',
                    value: _amountPaid,
                    theme: theme,
                    align: CrossAxisAlignment.start,
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
                Expanded(
                  child: _StatItem(
                    label: 'Total\nFinanced',
                    value: _totalFinanced,
                    theme: theme,
                    align: CrossAxisAlignment.end,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IsaInstalmentsCard extends StatelessWidget {
  const _IsaInstalmentsCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    const instalmentsPaid = 9;
    const maxInstalments = 108;
    const progress = 9 / 108;

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (theme.brightness == Brightness.light ? _kDarkGreen : _kGreen).withValues(alpha: 0.18),
            blurRadius: 0,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const _CircularProgress(progress: progress, color: _kGreen),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _kGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(_IsaIcons.instalments, color: _kGreen, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Instalments',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: theme.dividerColor),
                  const SizedBox(height: 14),
                  _StatItem(
                    label: 'Paid So Far',
                    value: '$instalmentsPaid',
                    theme: theme,
                    align: CrossAxisAlignment.start,
                  ),
                  const SizedBox(height: 10),
                  _StatItem(
                    label: 'Maximum No. of Instalments',
                    value: '$maxInstalments',
                    theme: theme,
                    align: CrossAxisAlignment.start,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

abstract class _IsaIcons {
  static const financing = Icons.account_balance_outlined;
  static const instalments = Icons.calendar_month_outlined;
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.theme,
    required this.align,
  });

  final String label;
  final String value;
  final ThemeData theme;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Coming Soon',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularProgress extends StatelessWidget {
  const _CircularProgress({required this.progress, this.color = _kGreen});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 76,
      height: 76,
      child: CustomPaint(
        painter: _CircularProgressPainter(
          progress: progress,
          trackColor: theme.colorScheme.outlineVariant,
          progressColor: color,
        ),
        child: Center(
          child: Text(
            'Soon',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  _CircularProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  static const _strokeWidth = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - _strokeWidth / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = _strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = _strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularProgressPainter old) =>
      old.progress != progress || old.trackColor != trackColor;
}
