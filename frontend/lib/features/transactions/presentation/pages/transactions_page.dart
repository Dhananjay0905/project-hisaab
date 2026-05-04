import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/constants/app_colors.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/transaction.dart';
import '../providers/transactions_provider.dart';
import 'add_transaction_page.dart';

// ─── View Mode ────────────────────────────────────────────────────────────────

enum _ViewMode { list, calendar }

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String? _selectedType; // null = All, 'INCOME', 'EXPENSE'
  _ViewMode _viewMode = _ViewMode.list;

  // Calendar state
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  // Transactions cache for the currently focused month (calendar mode)
  List<Transaction> _calendarMonthTxns = [];
  bool _isLoadingCalendarMonth = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(transactionsProvider.notifier).loadNextPage();
    }
  }

  void _applySearch(String value) {
    final notifier = ref.read(transactionsProvider.notifier);
    notifier.applyFilters(notifier.filters.copyWith(
      search: value.isEmpty ? null : value,
      clearSearch: value.isEmpty,
    ));
  }

  void _applyTypeFilter(String? type) {
    setState(() => _selectedType = type);
    final notifier = ref.read(transactionsProvider.notifier);
    notifier.applyFilters(notifier.filters.copyWith(
      type: type,
      clearType: type == null,
    ));
  }

  // ── Calendar helpers ──────────────────────────────────────────────────────

  void _switchToCalendar() {
    setState(() => _viewMode = _ViewMode.calendar);
    _fetchCalendarMonth(_focusedDay);
  }

  void _switchToList() {
    setState(() => _viewMode = _ViewMode.list);
  }

  Future<void> _fetchCalendarMonth(DateTime month) async {
    setState(() => _isLoadingCalendarMonth = true);
    final repo = ref.read(transactionRepositoryProvider);
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    try {
      final page = await repo.getTransactions(
        page: 1,
        limit: 200,
        startDate: firstDay.toUtc().toIso8601String(),
        endDate: lastDay.toUtc().toIso8601String(),
        type: _selectedType,
      );
      setState(() {
        _calendarMonthTxns = page.items;
        _isLoadingCalendarMonth = false;
      });
    } catch (_) {
      setState(() => _isLoadingCalendarMonth = false);
    }
  }

  List<Transaction> _getTransactionsForDay(DateTime day) {
    return _calendarMonthTxns.where((tx) {
      final local = tx.date.toLocal();
      return local.year == day.year &&
          local.month == day.month &&
          local.day == day.day;
    }).toList();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
  }

  void _onPageChanged(DateTime focusedDay) {
    _focusedDay = focusedDay;
    _fetchCalendarMonth(focusedDay);
  }

  void _onDayLongPressed(DateTime day, DateTime focusedDay) {
    HapticFeedback.mediumImpact();
    _showDayContextMenu(day);
  }

  void _showDayContextMenu(DateTime day) {
    final dayTxns = _getTransactionsForDay(day);
    final formatted = DateFormat('MMM d, yyyy').format(day);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(formatted,
                style: AppTypography.titleMedium
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
                '${dayTxns.length} transaction${dayTxns.length == 1 ? '' : 's'}',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 20),
            _ContextMenuItem(
              icon: Icons.visibility_rounded,
              label: 'View transactions',
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _selectedDay = day;
                  _focusedDay = day;
                });
              },
            ),
            const SizedBox(height: 8),
            _ContextMenuItem(
              icon: Icons.add_rounded,
              label: 'Add Cash In / Out for $formatted',
              onTap: () {
                Navigator.pop(ctx);
                // Navigate to add transaction — the date will be pre-filled
                // via the route extra parameter
                Navigator.of(context).push(MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => _AddTransactionForDate(date: day),
                ));
              },
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  void _openEditSheet(Transaction tx) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AddTransactionPage(editTransaction: tx),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final txState = ref.watch(transactionsProvider);
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final currencySymbol =
        authState is AuthAuthenticated ? authState.user.currencySymbol : '₹';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('History'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          // View mode toggle
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ModeToggleButton(
                    icon: Icons.format_list_bulleted_rounded,
                    isActive: _viewMode == _ViewMode.list,
                    onTap: _switchToList,
                  ),
                  _ModeToggleButton(
                    icon: Icons.calendar_month_rounded,
                    isActive: _viewMode == _ViewMode.calendar,
                    onTap: _switchToCalendar,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search & Filter (always visible) ─────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_viewMode == _ViewMode.list)
                  TextField(
                    controller: _searchController,
                    onSubmitted: _applySearch,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search transactions...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _applySearch('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withAlpha(128),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (val) => setState(() {}),
                  ),
                if (_viewMode == _ViewMode.list) const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: _selectedType == null,
                        onSelected: () => _applyTypeFilter(null),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Cash In',
                        isSelected: _selectedType == 'INCOME',
                        onSelected: () => _applyTypeFilter('INCOME'),
                        selectedColor: SemanticColors.of(context).cashIn,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Cash Out',
                        isSelected: _selectedType == 'EXPENSE',
                        onSelected: () => _applyTypeFilter('EXPENSE'),
                        selectedColor: SemanticColors.of(context).cashOut,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          Expanded(
            child: _viewMode == _ViewMode.list
                ? _buildListView(txState, currencySymbol)
                : _buildCalendarView(currencySymbol),
          ),
        ],
      ),
    );
  }

  // ─── List View ──────────────────────────────────────────────────────────

  Widget _buildListView(
      AsyncValue<TransactionPage> txState, String currencySymbol) {
    return txState.when(
      data: (page) {
        if (page.items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(51),
                ),
                const SizedBox(height: 16),
                Text(
                  'No transactions found',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(128),
                      ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(transactionsProvider.notifier).refresh();
          },
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8)
                .copyWith(bottom: 120),
            itemCount: page.items.length + (page.hasNext ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == page.items.length) {
                return const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final tx = page.items[index];
              final prevTx = index > 0 ? page.items[index - 1] : null;
              final showHeader = prevTx == null ||
                  _formatHeaderDate(tx.date) != _formatHeaderDate(prevTx.date);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showHeader)
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(
                        _formatHeaderDate(tx.date),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                  Dismissible(
                    key: ValueKey(tx.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    confirmDismiss: (dir) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Transaction?'),
                          content: Text(
                              'Are you sure you want to delete "${tx.title}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (_) {
                      ref
                          .read(transactionsProvider.notifier)
                          .removeTransaction(tx.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${tx.title} deleted')),
                      );
                    },
                    child: _TransactionTile(
                      transaction: tx,
                      currencySymbol: currencySymbol,
                      onLongPress: () => _openEditSheet(tx),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text('Failed to load transactions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () =>
                  ref.read(transactionsProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Calendar View ──────────────────────────────────────────────────────

  Widget _buildCalendarView(String currencySymbol) {
    final selectedDayTxns = _selectedDay != null
        ? _getTransactionsForDay(_selectedDay!)
        : <Transaction>[];

    return Column(
      children: [
        // Calendar widget
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outlineVariant.withAlpha(80)),
          ),
          child: TableCalendar<Transaction>(
            firstDay: DateTime(2000),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) =>
                _selectedDay != null && isSameDay(_selectedDay!, day),
            calendarFormat: _calendarFormat,
            onFormatChanged: (format) =>
                setState(() => _calendarFormat = format),
            onDaySelected: _onDaySelected,
            onDayLongPressed: _onDayLongPressed,
            onPageChanged: _onPageChanged,
            eventLoader: _getTransactionsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
              CalendarFormat.twoWeeks: '2 Weeks',
              CalendarFormat.week: 'Week',
            },
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: true,
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: AppColors.primary.withAlpha(120)),
                borderRadius: BorderRadius.circular(10),
              ),
              formatButtonTextStyle: AppTypography.labelSmall.copyWith(
                color: AppColors.primary,
              ),
              titleTextStyle: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
              leftChevronIcon: const Icon(Icons.chevron_left_rounded,
                  color: AppColors.primary),
              rightChevronIcon: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.primary),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: AppTypography.labelSmall.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              weekendStyle: AppTypography.labelSmall.copyWith(
                color: AppColors.onSurfaceVariant.withAlpha(150),
                fontWeight: FontWeight.w600,
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              todayDecoration: BoxDecoration(
                color: AppColors.primary.withAlpha(40),
                shape: BoxShape.circle,
              ),
              todayTextStyle: AppTypography.bodyMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
              selectedDecoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: AppTypography.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              defaultTextStyle: AppTypography.bodyMedium,
              weekendTextStyle: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              markersMaxCount: 3,
              markerSize: 6,
              markersAnchor: 0.7,
              markerDecoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders<Transaction>(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;
                final hasIncome = events.any((t) => t.isIncome);
                final hasExpense = events.any((t) => t.isExpense);
                return Positioned(
                  bottom: 2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasIncome)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: SemanticColors.of(context).cashIn,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (hasExpense)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: SemanticColors.of(context).cashOut,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Day transactions list
        Expanded(
          child: _isLoadingCalendarMonth
              ? const Center(child: CircularProgressIndicator())
              : _selectedDay == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app_rounded,
                              size: 48,
                              color: AppColors.onSurfaceVariant.withAlpha(80)),
                          const SizedBox(height: 12),
                          Text(
                            'Tap a date to see transactions',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Long-press for quick actions',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.onSurfaceVariant.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    )
                  : selectedDayTxns.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_busy_rounded,
                                  size: 48,
                                  color:
                                      AppColors.onSurfaceVariant.withAlpha(80)),
                              const SizedBox(height: 12),
                              Text(
                                'No transactions on ${DateFormat('MMM d').format(_selectedDay!)}',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20)
                              .copyWith(bottom: 120),
                          itemCount: selectedDayTxns.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              // Summary header
                              final income = selectedDayTxns
                                  .where((t) => t.isIncome)
                                  .fold(0.0, (sum, t) => sum + t.amount);
                              final expense = selectedDayTxns
                                  .where((t) => t.isExpense)
                                  .fold(0.0, (sum, t) => sum + t.amount);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Text(
                                      DateFormat('EEEE, MMM d')
                                          .format(_selectedDay!),
                                      style: AppTypography.titleSmall.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (income > 0)
                                      Text(
                                        '+$currencySymbol${income.toStringAsFixed(0)}',
                                        style:
                                            AppTypography.labelMedium.copyWith(
                                          color: SemanticColors.of(context).cashIn,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    if (income > 0 && expense > 0)
                                      const SizedBox(width: 8),
                                    if (expense > 0)
                                      Text(
                                        '-$currencySymbol${expense.toStringAsFixed(0)}',
                                        style:
                                            AppTypography.labelMedium.copyWith(
                                          color: SemanticColors.of(context).cashOut,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }
                            return _TransactionTile(
                              transaction: selectedDayTxns[index - 1],
                              currencySymbol: currencySymbol,
                              onLongPress: () =>
                                  _openEditSheet(selectedDayTxns[index - 1]),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  String _formatHeaderDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final local = date.toLocal();
    final txDate = DateTime(local.year, local.month, local.day);
    final shortDate = DateFormat('dd/MM/yy').format(local);

    if (txDate == today) {
      return 'Today ($shortDate)';
    } else if (txDate == yesterday) {
      return 'Yesterday ($shortDate)';
    } else {
      return '${DateFormat('MMM d, yyyy').format(local)} ($shortDate)';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Private widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _ModeToggleButton extends StatelessWidget {
  const _ModeToggleButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isActive ? Colors.white : AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.selectedColor,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onSelected;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = selectedColor ?? Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color
                : Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isSelected
                    ? (isDark || selectedColor == null
                        ? Colors.white
                        : Colors.white)
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.currencySymbol,
    this.onLongPress,
  });

  final Transaction transaction;
  final String currencySymbol;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;
    final color = isIncome
        ? SemanticColors.of(context).cashIn
        : Theme.of(context).colorScheme.onSurface;
    final sign = isIncome ? '+' : '-';

    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withAlpha(128),
          ),
        ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              transaction.category?.emoji ?? (isIncome ? '💰' : '💳'),
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (transaction.note != null &&
                    transaction.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    transaction.note!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // Show time only when user explicitly set one (non-midnight)
                Builder(builder: (_) {
                  final local = transaction.date.toLocal();
                  if (local.hour == 0 && local.minute == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      DateFormat('h:mm a').format(local),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '$sign$currencySymbol${transaction.amount.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
      ),
    );
  }
}

class _ContextMenuItem extends StatelessWidget {
  const _ContextMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: AppTypography.bodyMedium
                      .copyWith(fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.outlineVariant),
          ],
        ),
      ),
    );
  }
}

/// Minimal wrapper that opens AddTransactionPage with a pre-filled date.
class _AddTransactionForDate extends StatelessWidget {
  const _AddTransactionForDate({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return AddTransactionPage(initialDate: date);
  }
}
