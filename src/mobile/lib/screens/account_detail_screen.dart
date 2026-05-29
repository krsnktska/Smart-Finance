import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/models/account_model.dart';
import 'package:mobile/models/category_spending_model.dart';
import 'package:mobile/models/transaction_model.dart';
import 'package:mobile/providers/accounts_provider.dart';
import 'package:mobile/providers/transactions_provider.dart';
import 'package:mobile/screens/transaction_form_screen.dart';

class AccountDetailScreen extends ConsumerStatefulWidget {
  final AccountModel account;

  const AccountDetailScreen({super.key, required this.account});

  @override
  ConsumerState<AccountDetailScreen> createState() =>
      _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
  String _activePreset = 'This Month';

  @override
  void initState() {
    super.initState();
    _applyPreset('This Month');
    Future.microtask(() {
      ref
          .read(transactionsProvider(widget.account.id).notifier)
          .loadTransactions();
    });
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _activePreset = preset;
      if (preset == 'This Month') {
        _fromDate = DateTime(now.year, now.month, 1);
        _toDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      } else if (preset == 'Last 30 Days') {
        _fromDate = now.subtract(const Duration(days: 30));
        _toDate = now;
      } else {
        // All Time
        _fromDate = null;
        _toDate = null;
      }
    });
  }

  void _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _activePreset = 'Custom';
        _fromDate = picked.start;
        _toDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
    }
  }

  void _refreshData() {
    ref
        .read(transactionsProvider(widget.account.id).notifier)
        .loadTransactions();
    ref.invalidate(accountSummaryProvider);
    ref.invalidate(categorySpendingProvider);
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null) return Colors.grey;
    try {
      final hex = hexColor.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final transactionsState = ref.watch(
      transactionsProvider(widget.account.id),
    );

    final params = (accountId: widget.account.id, from: _fromDate, to: _toDate);

    final summaryAsync = ref.watch(accountSummaryProvider(params));
    final categorySpendingAsync = ref.watch(categorySpendingProvider(params));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.account.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Wallet',
                onPressed: _showEditAccountDialog,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _refreshData,
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Period Filter',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetChip('This Month'),
                        const SizedBox(width: 8),
                        _buildPresetChip('Last 30 Days'),
                        const SizedBox(width: 8),
                        _buildPresetChip('All Time'),

                        // Вместо Spacer используем фиксированный отступ,
                        // чтобы кнопка не прижималась вплотную к чипам
                        const SizedBox(width: 16),

                        OutlinedButton.icon(
                          onPressed: _selectCustomDateRange,
                          icon: const Icon(Icons.date_range, size: 16),
                          label: Text(
                            _activePreset == 'Custom' ? 'Custom' : 'Range',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_fromDate != null || _toDate != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Showing: ${_formatDate(_fromDate)} - ${_formatDate(_toDate)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Financial Summary Cards
          SliverToBoxAdapter(
            child: summaryAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(child: Text('Error loading summary: $err')),
              ),
              data: (summary) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [Colors.grey[900]!, Colors.grey[800]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          'Net Balance',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${summary.balance >= 0 ? '+' : ''}${summary.balance.toStringAsFixed(2)} ${widget.account.currency}',
                          style: TextStyle(
                            color: summary.balance >= 0
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.arrow_downward,
                                      color: Colors.greenAccent[400],
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Income',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '+${summary.totalIncome.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: Colors.white24,
                            ),
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.arrow_upward,
                                      color: Colors.redAccent[400],
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Expenses',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '-${summary.totalExpense.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Categories Breakdown Section
          SliverToBoxAdapter(
            child: categorySpendingAsync.when(
              loading: () => const SizedBox(),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(child: Text('Error loading categories: $err')),
              ),
              data: (spendings) {
                if (spendings.isEmpty) return const SizedBox();
                final totalSpend = spendings.fold<double>(
                  0,
                  (sum, item) => sum + item.totalAmount,
                );
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Spending by Category',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Custom Donut Chart and legend
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 100,
                                height: 100,
                                child: CustomPaint(
                                  painter: DonutChartPainter(
                                    spendings: spendings,
                                    colors: spendings
                                        .map((s) => _parseColor(s.color))
                                        .toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  children: spendings.take(4).map((spending) {
                                    final percentage = totalSpend > 0
                                        ? (spending.totalAmount / totalSpend) *
                                              100
                                        : 0.0;
                                    final catColor = _parseColor(
                                      spending.color,
                                    );
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4.0,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: catColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${spending.emoji ?? ""} ${spending.name}',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${percentage.toStringAsFixed(0)}%',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Linear progress breakdowns
                          ...spendings.map((spending) {
                            final percentage = totalSpend > 0
                                ? (spending.totalAmount / totalSpend)
                                : 0.0;
                            final catColor = _parseColor(spending.color);
                            return Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${spending.emoji ?? "💰"} ${spending.name} (${spending.transactionCount})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${spending.totalAmount.toStringAsFixed(2)} ${widget.account.currency}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percentage,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      catColor,
                                    ),
                                    minHeight: 8,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Transactions title
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 16.0,
                bottom: 8.0,
              ),
              child: Text(
                'Transaction History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Transactions list
          if (transactionsState.isLoading &&
              transactionsState.transactions.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (transactionsState.error != null &&
              transactionsState.transactions.isEmpty)
            SliverFillRemaining(
              child: Center(child: Text('Error: ${transactionsState.error}')),
            )
          else if (transactionsState.transactions.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No transactions registered yet for this wallet.'),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final transaction =
                    transactionsState.transactions[transactionsState
                            .transactions
                            .length -
                        1 -
                        index];
                final isIncome = transaction.type == TransactionType.income;
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 6.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isIncome
                          ? Colors.green[50]
                          : Colors.red[50],
                      child: Icon(
                        isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isIncome ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(
                      transaction.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_formatDateTime(transaction.occurredAt)),
                        if (transaction.categories.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: transaction.categories.map((cat) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: cat.categoryColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (cat.emoji != null) ...[
                                      Text(
                                        cat.emoji!,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      const SizedBox(width: 2),
                                    ],
                                    Text(
                                      cat.name,
                                      style: TextStyle(
                                        color: cat.categoryColor.withOpacity(
                                          0.9,
                                        ),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${isIncome ? '+' : '-'}${transaction.value.toStringAsFixed(2)} ${transaction.currency}',
                          style: TextStyle(
                            color: isIncome ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        PopupMenuButton<String>(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                          onSelected: (val) {
                            if (val == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TransactionFormScreen(
                                    accountId: widget.account.id,
                                    currency: widget.account.currency,
                                    transaction: transaction,
                                  ),
                                ),
                              ).then((_) => _refreshData());
                            } else if (val == 'delete') {
                              _confirmDeleteTransaction(transaction.id);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }, childCount: transactionsState.transactions.length),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionFormScreen(
                accountId: widget.account.id,
                currency: widget.account.currency,
              ),
            ),
          ).then((_) => _refreshData());
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
      ),
    );
  }

  Widget _buildPresetChip(String preset) {
    final isActive = _activePreset == preset;
    return ChoiceChip(
      label: Text(preset),
      selected: isActive,
      onSelected: (selected) {
        if (selected) {
          _applyPreset(preset);
        }
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'All';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showEditAccountDialog() {
    final nameController = TextEditingController(text: widget.account.name);
    final currencyController = TextEditingController(
      text: widget.account.currency,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: currencyController,
              decoration: const InputDecoration(
                hintText: 'Currency (USD, EUR, etc.)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              final success = await ref
                  .read(accountsProvider.notifier)
                  .updateAccount(
                    accountId: widget.account.id,
                    name: nameController.text,
                    currency: currencyController.text,
                  );

              navigator.pop();
              if (success) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Wallet updated!'),
                    backgroundColor: Colors.green,
                  ),
                );
                // Also load the updated info for widget
                setState(() {});
                _refreshData();
              } else {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Error updating wallet'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTransaction(String transactionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text(
          'This action will delete this transaction from history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              final success = await ref
                  .read(transactionsProvider(widget.account.id).notifier)
                  .deleteTransaction(transactionId);

              navigator.pop();
              if (success) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Transaction deleted'),
                    backgroundColor: Colors.green,
                  ),
                );
                _refreshData();
              } else {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Error deleting transaction'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final List<CategorySpendingModel> spendings;
  final List<Color> colors;

  DonutChartPainter({required this.spendings, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = spendings.fold<double>(
      0,
      (sum, item) => sum + item.totalAmount,
    );
    if (total == 0) {
      final paint = Paint()
        ..color = Colors.grey[300]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14;
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width / 2 - 10,
        paint,
      );
      return;
    }

    double startAngle = -3.1415926535 / 2; // Start from top
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2 - 10,
    );

    for (int i = 0; i < spendings.length; i++) {
      final sweepAngle = (spendings[i].totalAmount / total) * 2 * 3.1415926535;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
