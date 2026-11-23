import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/isa_transaction.dart';
import '../providers/auth_provider.dart';
import '../providers/isa_transactions_provider.dart';
import '../widgets/data_error_cards.dart';
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
    final headerCount = showStale ? 1 : 0;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: txns.length + headerCount,
      separatorBuilder: (_, i) {
        if (showStale && i == 0) return const SizedBox.shrink();
        return const Divider(height: 1, indent: 72);
      },
      itemBuilder: (context, i) {
        if (showStale && i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: StaleDataBanner(
              lastSyncedAt: provider.lastSyncedAt,
              onRetry: _load,
              isNetworkError: provider.networkError,
            ),
          );
        }
        return _TransactionTile(transaction: txns[i - headerCount]);
      },
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

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});
  final IsaTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final formattedAmount = NumberFormat.currency(
      symbol: transaction.currency,
      decimalDigits: 0,
    ).format(transaction.amount);

    final formattedDate = _formatDate(transaction.paymentDate);
    final isRepayment = transaction.paymentType.toLowerCase().contains('repayment');

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isRepayment
              ? colorScheme.primaryContainer
              : colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          isRepayment ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
          color: isRepayment
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSecondaryContainer,
          size: 20,
        ),
      ),
      title: Text(
        transaction.paymentType,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: formattedDate.isNotEmpty
          ? Text(formattedDate, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12))
          : null,
      trailing: Text(
        formattedAmount,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: isRepayment ? colorScheme.primary : colorScheme.onSurface,
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final date = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return raw;
    }
  }
}
