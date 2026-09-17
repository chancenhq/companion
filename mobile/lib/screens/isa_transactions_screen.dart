import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/isa_transaction.dart';
import '../providers/auth_provider.dart';
import '../services/isa_transactions_service.dart';

class IsaTransactionsScreen extends StatefulWidget {
  const IsaTransactionsScreen({super.key});

  @override
  State<IsaTransactionsScreen> createState() => _IsaTransactionsScreenState();
}

class _IsaTransactionsScreenState extends State<IsaTransactionsScreen> {
  final _service = IsaTransactionsService();

  List<IsaTransaction>? _transactions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = await context.read<AuthProvider>().getValidAccessToken();
      if (token == null) { if (mounted) setState(() { _loading = false; }); return; }
      final result = await _service.fetchTransactions(token);
      final filtered = result.where((t) {
        final type = t.paymentType.toLowerCase();
        return type.contains('repayment') || type.contains('commitment');
      }).toList();
      if (mounted) setState(() { _transactions = filtered; _loading = false; });
    } on IsaTransactionsUnavailableException {
      if (mounted) setState(() { _error = 'Repayment data is not configured yet.'; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Unable to load transactions. Try again later.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildEmpty(context, message: _error!);
    }

    final txns = _transactions ?? [];
    if (txns.isEmpty) {
      return _buildEmpty(context, message: 'No repayment transactions found.');
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: txns.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) => _TransactionTile(transaction: txns[i]),
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
