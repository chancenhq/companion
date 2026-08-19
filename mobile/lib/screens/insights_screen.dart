import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/my_account_provider.dart';
import 'chat_conversation_screen.dart';

const Color _kGreen     = Color(0xFF84BD00);
const Color _kDarkGreen = Color(0xFF1F4834);
const Color _kPurple    = Color(0xFF986EF9);

// ─── ISA status ──────────────────────────────────────────────────────────────

// These four map directly to the values the Chancen ISA warehouse (via
// Metabase) can return for "ISA Status", plus `applicationStage` for
// students who don't have a row yet (the /api/v1/my_account 404 case —
// no ISA contract exists for them so far).
enum IsaStatus {
  applicationStage,
  contractSigned,
  graduated,
  droppedOut,
}

extension IsaStatusDisplay on IsaStatus {
  String get label {
    switch (this) {
      case IsaStatus.applicationStage: return 'Application';
      case IsaStatus.contractSigned:   return 'ISA Contract Signed';
      case IsaStatus.graduated:        return 'Graduated';
      case IsaStatus.droppedOut:       return 'Drop out';
    }
  }

  Color get color {
    switch (this) {
      case IsaStatus.applicationStage: return _kPurple;
      case IsaStatus.contractSigned:   return _kDarkGreen;
      case IsaStatus.graduated:        return const Color(0xFF10A861);
      case IsaStatus.droppedOut:       return const Color(0xFFE53935);
    }
  }

  IconData get icon {
    switch (this) {
      case IsaStatus.applicationStage: return Icons.hourglass_top_outlined;
      case IsaStatus.contractSigned:   return Icons.verified_outlined;
      case IsaStatus.graduated:        return Icons.school_outlined;
      case IsaStatus.droppedOut:       return Icons.warning_amber_outlined;
    }
  }

  static IsaStatus fromString(String s) {
    switch (s.toLowerCase().trim()) {
      case 'isa contract signed':
      case 'contract_signed':
      case 'contract signed':
        return IsaStatus.contractSigned;
      case 'graduated':
        return IsaStatus.graduated;
      case 'drop out':
      case 'dropout':
      case 'drop_out':
        return IsaStatus.droppedOut;
      default:
        // Covers empty/unknown status and the "no ISA record yet" case.
        return IsaStatus.applicationStage;
    }
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final token = await auth.getValidAccessToken();
    if (!mounted || token == null) return;
    await context.read<MyAccountProvider>().load(token);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _AccountSummaryView(onRefresh: _load);
  }
}

// ─── Summary view ─────────────────────────────────────────────────────────────

// Repayments data isn't returned by the Metabase question yet — null means
// "unavailable", not zero, so render it the same way the rest of the ISA
// cards render missing data.
String? _formatOrDash(double? value, NumberFormat fmt) {
  return value == null ? null : fmt.format(value);
}

class _AccountSummaryView extends StatelessWidget {
  const _AccountSummaryView({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstName = context.watch<AuthProvider>().user?.firstName ?? 'there';
    final provider = context.watch<MyAccountProvider>();
    final account = provider.account;
    final loading = provider.isLoading;
    final bg = theme.brightness == Brightness.light ? Colors.white : Colors.black;

    // Derive ISA status (null account → application stage)
    final isaStatus = account != null
        ? IsaStatusDisplay.fromString(account.status)
        : IsaStatus.applicationStage;

    final currency = account?.currency ?? 'KES';
    final fmt = NumberFormat.currency(
      locale: 'en',
      symbol: currency == 'KES' ? 'KSh ' : '$currency ',
      decimalDigits: 0,
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ColoredBox(
        color: bg,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GreetingCard(firstName: firstName, theme: theme),
              const SizedBox(height: 8),
              _AskAnythingTile(theme: theme),
              const SizedBox(height: 20),
              _SectionHeaderTile(theme: theme, isaStatus: isaStatus),
              const SizedBox(height: 16),
              switch (isaStatus) {
                // Still applying / no ISA contract on file yet — just the
                // progress explainer. ISA Status badge above already shows.
                IsaStatus.applicationStage =>
                  _ApplicationStageCard(theme: theme, loading: loading),

                // Contract signed but not graduated: show financing so far.
                // Instalment tracking isn't relevant until repayment starts —
                // later this card becomes tappable to drill into instalments.
                IsaStatus.contractSigned => _IsaFinancingCard(
                    theme: theme,
                    isaStatus: isaStatus,
                    totalFinanced: loading ? null : fmt.format(account!.totalFinanced),
                    repaymentsReceived: loading
                        ? null
                        : _formatOrDash(account!.repaymentsReceived, fmt),
                    loading: loading,
                  ),

                // Graduated or dropped out: repayment tracking is fully
                // relevant either way, so both cards are always expanded.
                IsaStatus.graduated || IsaStatus.droppedOut => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _IsaFinancingCard(
                        theme: theme,
                        isaStatus: isaStatus,
                        totalFinanced: loading ? null : fmt.format(account!.totalFinanced),
                        repaymentsReceived: loading
                            ? null
                            : _formatOrDash(account!.repaymentsReceived, fmt),
                        loading: loading,
                      ),
                      const SizedBox(height: 12),
                      _IsaInstalmentsCard(
                        theme: theme,
                        installmentsPaid: loading ? null : account!.installmentsPaid,
                        maxInstallments: loading ? null : account!.maxInstallments,
                        loading: loading,
                      ),
                    ],
                  ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Greeting ────────────────────────────────────────────────────────────────

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

// ─── Ask anything ────────────────────────────────────────────────────────────

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

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeaderTile extends StatelessWidget {
  const _SectionHeaderTile({required this.theme, required this.isaStatus});

  final ThemeData theme;
  final IsaStatus isaStatus;

  @override
  Widget build(BuildContext context) {
    final statusColor = (isaStatus == IsaStatus.contractSigned &&
            theme.brightness == Brightness.dark)
        ? _kGreen
        : isaStatus.color;

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'My Account',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isaStatus.icon, size: 13, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  isaStatus.label,
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
    );
  }
}

// ─── Application Stage card ───────────────────────────────────────────────────

class _ApplicationStageCard extends StatelessWidget {
  const _ApplicationStageCard({required this.theme, required this.loading});

  final ThemeData theme;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _kPurple.withValues(alpha: 0.18),
            blurRadius: 0,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _kPurple.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hourglass_top_outlined,
                    color: _kPurple,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your application is in progress',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Once your ISA is active, your financing details and repayment progress will appear here.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Divider(height: 1, color: theme.dividerColor),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.school_outlined,
                  label: 'Complete your studies',
                  theme: theme,
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.description_outlined,
                  label: 'Sign your ISA contract',
                  theme: theme,
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.trending_up_outlined,
                  label: 'Start your repayment journey',
                  theme: theme,
                ),
              ],
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.theme});

  final IconData icon;
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _kPurple),
        const SizedBox(width: 10),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─── ISA Financing card ───────────────────────────────────────────────────────

class _IsaFinancingCard extends StatelessWidget {
  const _IsaFinancingCard({
    required this.theme,
    required this.isaStatus,
    required this.totalFinanced,
    required this.repaymentsReceived,
    required this.loading,
  });

  final ThemeData theme;
  final IsaStatus isaStatus;
  final String? totalFinanced;
  final String? repaymentsReceived;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final statusColor = (isaStatus == IsaStatus.contractSigned &&
            theme.brightness == Brightness.dark)
        ? _kGreen
        : isaStatus.color;

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (theme.brightness == Brightness.light ? _kDarkGreen : _kGreen)
                .withValues(alpha: 0.18),
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
                      Icon(isaStatus.icon, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        isaStatus.label,
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
              'Total Financed',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              loading ? '—' : (totalFinanced ?? '—'),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            Divider(height: 1, color: theme.dividerColor),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: _StatItem(
                label: 'Repayments\nReceived',
                value: loading ? null : repaymentsReceived,
                theme: theme,
                align: CrossAxisAlignment.end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ISA Instalments card ─────────────────────────────────────────────────────

class _IsaInstalmentsCard extends StatelessWidget {
  const _IsaInstalmentsCard({
    required this.theme,
    required this.installmentsPaid,
    required this.maxInstallments,
    required this.loading,
  });

  final ThemeData theme;
  final int? installmentsPaid;
  final int? maxInstallments;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    // installmentsPaid isn't returned by the Metabase question yet — treat
    // it as "unknown", not zero, so the ring/label read "—" instead of 0%.
    final paid = installmentsPaid;
    final max = maxInstallments ?? 1;
    final progress = (paid != null && max > 0) ? (paid / max).clamp(0.0, 1.0) : 0.0;
    final pct = (progress * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (theme.brightness == Brightness.light ? _kDarkGreen : _kGreen)
                .withValues(alpha: 0.18),
            blurRadius: 0,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            _CircularProgress(
              progress: loading ? 0.0 : progress,
              color: _kGreen,
              label: loading ? '—' : (paid != null ? '$pct%' : '—'),
            ),
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
                        child: const Icon(_IsaIcons.instalments,
                            color: _kGreen, size: 18),
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
                    value: loading ? null : (paid != null ? '$paid' : null),
                    theme: theme,
                    align: CrossAxisAlignment.start,
                  ),
                  const SizedBox(height: 10),
                  _StatItem(
                    label: 'Maximum No. of Instalments',
                    value: loading ? null : '$max',
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

// ─── Shared widgets ───────────────────────────────────────────────────────────

abstract class _IsaIcons {
  static const financing   = Icons.account_balance_outlined;
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
  final String? value;
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
            value ?? '—',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularProgress extends StatelessWidget {
  const _CircularProgress({
    required this.progress,
    required this.label,
    this.color = _kGreen,
  });

  final double progress;
  final String label;
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
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
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

    if (progress > 0) {
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
  }

  @override
  bool shouldRepaint(_CircularProgressPainter old) =>
      old.progress != progress || old.trackColor != trackColor;
}
