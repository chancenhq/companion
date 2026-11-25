import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/isa_transaction.dart';
import '../providers/auth_provider.dart';
import '../providers/isa_transactions_provider.dart';
import '../theme/sure_colors.dart';
import '../theme/sure_spacing.dart';
import '../theme/sure_tokens.dart';
import '../widgets/data_error_cards.dart';
import '../widgets/money_text.dart';
import '../widgets/sure_button.dart';
import '../widgets/sure_card.dart';
import '../widgets/sure_icon.dart';
import '../widgets/sure_list_group.dart';
import '../widgets/verify_email_card.dart';

class IsaTransactionsScreen extends StatefulWidget {
  const IsaTransactionsScreen({super.key});

  @override
  State<IsaTransactionsScreen> createState() => _IsaTransactionsScreenState();
}

class _IsaTransactionsScreenState extends State<IsaTransactionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final token = await context.read<AuthProvider>().getValidAccessToken();
    if (!mounted || token == null) return;
    await context.read<IsaTransactionsProvider>().load(token);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final provider = context.watch<IsaTransactionsProvider>();
    final txns = provider.transactions;

    // First load (or a retry with nothing cached): full-screen spinner. On a
    // refresh with data already on screen, keep the list and let the
    // RefreshIndicator show its own spinner instead of blanking the screen.
    if (provider.isLoading && txns == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.verificationRequired) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [VerifyEmailCard(onVerified: _load)],
      );
    }

    final hasData = txns != null && txns.isNotEmpty;
    if (hasData) {
      return _buildList(txns, provider);
    }

    if (provider.networkError) {
      return _scrollWrap(DataErrorCard(
        icon: Icons.wifi_off_rounded,
        iconColor: const Color(0xFFE53935),
        title: 'No internet connection',
        body: 'Your payment history will load once you\'re back online. '
            'Pull down or tap Retry to try again.',
        onRetry: _load,
      ));
    }
    if (provider.upstreamError) {
      return _scrollWrap(DataErrorCard(
        icon: Icons.error_outline_rounded,
        iconColor: const Color(0xFFE53935),
        title: 'Unable to load payments',
        body: 'The data service returned an unexpected error. '
            'This is usually temporary — pull down or tap Retry to try again.',
        onRetry: _load,
      ));
    }
    if (provider.unavailable) {
      return _scrollWrap(const DataErrorCard(
        icon: Icons.cloud_off_rounded,
        iconColor: Color(0xFF986EF9),
        title: 'Payment data temporarily unavailable',
        body: 'We\'re having trouble reaching the Chancen data service right now. '
            'Your payments will appear once the connection is restored. '
            'Pull down to refresh and try again.',
      ));
    }

    return _buildEmpty(context, message: 'No transactions found.');
  }

  Widget _buildList(List<IsaTransaction> txns, IsaTransactionsProvider provider) {
    final showStale =
        provider.networkError || provider.upstreamError || provider.unavailable;

    return PaymentsList(
      transactions: txns,
      staleBanner: showStale
          ? StaleDataBanner(
              lastSyncedAt: provider.lastSyncedAt,
              onRetry: _load,
              isNetworkError: provider.networkError,
            )
          : null,
    );
  }

  /// Wraps an error card in a scrollable list so pull-to-refresh still works
  /// when there's nothing else on screen.
  Widget _scrollWrap(Widget child) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      children: [child],
    );
  }

  Widget _buildEmpty(BuildContext context, {required String message}) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 48, color: Theme.of(context).colorScheme.outlineVariant),
              const SizedBox(height: 12),
              Text(message,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ],
    );
  }
}

/// The grouped-by-category payments list. Kept as a standalone widget so it can
/// be rendered (and tested) from a plain list of transactions, independent of
/// the provider-based loading in [IsaTransactionsScreen].
class PaymentsList extends StatelessWidget {
  const PaymentsList({
    super.key,
    required this.transactions,
    this.staleBanner,
  });

  final List<IsaTransaction> transactions;

  /// Optional banner shown above the list when cached payments are still on
  /// screen after a failed refresh.
  final Widget? staleBanner;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = SureColors.of(context).palette;

    final grouped = <IsaPaymentCategory, List<IsaTransaction>>{
      for (final category in IsaPaymentCategory.values) category: [],
    };
    for (final transaction in transactions) {
      grouped[transaction.category]!.add(transaction);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SureSpacing.xl,
        SureSpacing.xl,
        SureSpacing.xl,
        SureSpacing.huge,
      ),
      children: [
        if (staleBanner != null) ...[
          staleBanner!,
          const SizedBox(height: SureSpacing.xl),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                'Payments',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            IconButton(
              tooltip: l.paymentsExplainerAction,
              onPressed: () => _showPaymentsExplainer(context),
              icon: SureIcon(
                SureIcons.circleInfo,
                size: SureIconSize.lg,
                color: palette.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: SureSpacing.md),
        for (final category in IsaPaymentCategory.values)
          ..._section(
            context,
            category: category,
            transactions: grouped[category]!,
          ),
      ],
    );
  }
}

List<Widget> _section(
  BuildContext context, {
  required IsaPaymentCategory category,
  required List<IsaTransaction> transactions,
}) {
  if (transactions.isEmpty) return const [];

  return [
    SureListGroup(
      header: _sectionTitle(context, category),
      children: [
        for (final transaction in transactions)
          _PaymentRow(transaction: transaction),
      ],
    ),
    const SizedBox(height: SureSpacing.xxxl),
  ];
}

Future<void> _showPaymentsExplainer(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      final l = AppLocalizations.of(context);
      final palette = SureColors.of(context).palette;

      return Padding(
        padding: const EdgeInsets.fromLTRB(
          SureSpacing.xl,
          0,
          SureSpacing.xl,
          SureSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SureIcon(
              SureIcons.circleInfo,
              size: SureIconSize.xl,
              color: palette.info,
            ),
            const SizedBox(height: SureSpacing.lg),
            Text(
              l.paymentsExplainerTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: SureTokens.weightSemibold,
                  ),
            ),
            const SizedBox(height: SureSpacing.sm),
            Text(
              l.paymentsExplainerBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
            ),
            const SizedBox(height: SureSpacing.xxl),
            SureButton(
              label: l.commonClose,
              onPressed: () => Navigator.pop(context),
              variant: SureButtonVariant.secondary,
              size: SureButtonSize.lg,
              fullWidth: true,
            ),
          ],
        ),
      );
    },
  );
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.transaction});

  final IsaTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final palette = SureColors.of(context).palette;

    return SureListRow(
      leading: _PaymentTypeIcon(category: transaction.category),
      title: _paymentTitle(context, transaction),
      onTap: () => _showPaymentDetails(context, transaction),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatAmount(transaction),
            style: SureMoney.tabular(
              Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: SureTokens.weightSemibold,
                  ),
            ),
          ),
          const SizedBox(width: SureSpacing.md),
          SureIcon(
            SureIcons.chevronRight,
            size: SureIconSize.md,
            color: palette.textSubdued,
          ),
        ],
      ),
    );
  }
}

class _PaymentTypeIcon extends StatelessWidget {
  const _PaymentTypeIcon({required this.category});

  final IsaPaymentCategory category;

  @override
  Widget build(BuildContext context) {
    final palette = SureColors.of(context).palette;
    final (icon, foreground, background) = switch (category) {
      IsaPaymentCategory.chancenFunding => (
          SureIcons.handCoins,
          palette.info,
          palette.info.withValues(alpha: 0.1),
        ),
      IsaPaymentCategory.balanceReduction => (
          SureIcons.trendingDown,
          palette.success,
          palette.success.withValues(alpha: 0.1),
        ),
      IsaPaymentCategory.noPrincipalEffect => (
          SureIcons.receipt,
          palette.textSecondary,
          palette.surfaceInset,
        ),
      IsaPaymentCategory.other => (
          SureIcons.receipt,
          palette.textSecondary,
          palette.surfaceInset,
        ),
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(SureTokens.radiusLg),
      ),
      child: SureIcon(icon, size: SureIconSize.md, color: foreground),
    );
  }
}

Future<void> _showPaymentDetails(
  BuildContext context,
  IsaTransaction transaction,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      final l = AppLocalizations.of(context);
      final palette = SureColors.of(context).palette;

      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          SureSpacing.xl,
          0,
          SureSpacing.xl,
          SureSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.paymentsDetailTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: SureTokens.weightSemibold,
                  ),
            ),
            const SizedBox(height: SureSpacing.xxl),
            Center(
              child: Column(
                children: [
                  _PaymentTypeIcon(category: transaction.category),
                  const SizedBox(height: SureSpacing.lg),
                  Text(
                    _formatAmount(transaction),
                    style: SureMoney.tabular(
                      Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: SureTokens.weightSemibold,
                          ),
                    ),
                  ),
                  const SizedBox(height: SureSpacing.xs),
                  Text(
                    _sectionTitle(context, transaction.category),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SureSpacing.xxxl),
            SureCard(
              elevated: false,
              child: Text(
                _categoryDescription(context, transaction.category),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.textSecondary,
                    ),
              ),
            ),
            const SizedBox(height: SureSpacing.xxxl),
            SureListGroup(
              children: [
                SureListRow(
                  title: l.paymentsDetailRecordedType,
                  trailing: Text(_paymentTitle(context, transaction)),
                ),
                SureListRow(
                  title: l.paymentsDetailDate,
                  trailing: Text(_formatDate(transaction.paymentDate)),
                ),
                SureListRow(
                  title: l.paymentsDetailCurrency,
                  trailing: Text(
                    transaction.currency.trim().isEmpty
                        ? l.paymentsUnknownValue
                        : transaction.currency,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SureSpacing.xxxl),
            SureButton(
              label: l.commonClose,
              onPressed: () => Navigator.pop(context),
              variant: SureButtonVariant.secondary,
              size: SureButtonSize.lg,
              fullWidth: true,
            ),
          ],
        ),
      );
    },
  );
}

String _formatAmount(IsaTransaction transaction) {
  return NumberFormat.currency(
    symbol: transaction.currency.isEmpty ? '' : '${transaction.currency} ',
    decimalDigits: transaction.amount % 1 == 0 ? 0 : 2,
  ).format(transaction.amount);
}

String _formatDate(String raw) {
  if (raw.isEmpty) return '—';
  try {
    final date = DateTime.parse(raw);
    return DateFormat('dd MMM yyyy').format(date);
  } catch (_) {
    return raw;
  }
}

String _sectionTitle(BuildContext context, IsaPaymentCategory category) {
  final l = AppLocalizations.of(context);
  return switch (category) {
    IsaPaymentCategory.chancenFunding => l.paymentsChancenFundingSection,
    IsaPaymentCategory.balanceReduction => l.paymentsBalanceReductionSection,
    IsaPaymentCategory.noPrincipalEffect => l.paymentsNoPrincipalEffectSection,
    IsaPaymentCategory.other => l.paymentsOtherSection,
  };
}

String _paymentTitle(BuildContext context, IsaTransaction transaction) {
  final l = AppLocalizations.of(context);
  return switch (transaction.normalizedPaymentType) {
    'admin fee' => l.paymentsItemAdministrationFee,
    'application fee' || 'application fees' => l.paymentsItemApplicationFee,
    'deposit' => l.paymentsItemDeposit,
    'dropout penalty' || 'drop out penalty' => l.paymentsItemDropoutPenalty,
    'penalty fee' => l.paymentsItemPenaltyFee,
    'pei payment' => l.paymentsItemChancenFunding,
    'cobooth monthly flat payment' => l.paymentsItemMonthlyPayment,
    'cobooth payment' => l.paymentsItemBalancePayment,
    'commitment fee' || 'commitment fees' => l.paymentsItemCommitmentPayment,
    'commitment payment' => l.paymentsItemCommitmentPayment,
    'contribution fee' => l.paymentsItemContributionPayment,
    'drop out fee' => l.paymentsItemDropoutPayment,
    'repayment' => l.paymentsItemRepayment,
    'write off collection payment' => l.paymentsItemCollectionPayment,
    _ => l.paymentsOtherItem,
  };
}

String _categoryDescription(
  BuildContext context,
  IsaPaymentCategory category,
) {
  final l = AppLocalizations.of(context);
  return switch (category) {
    IsaPaymentCategory.chancenFunding => l.paymentsChancenFundingDescription,
    IsaPaymentCategory.balanceReduction =>
      l.paymentsBalanceReductionDescription,
    IsaPaymentCategory.noPrincipalEffect =>
      l.paymentsNoPrincipalEffectDescription,
    IsaPaymentCategory.other => l.paymentsOtherDescription,
  };
}
