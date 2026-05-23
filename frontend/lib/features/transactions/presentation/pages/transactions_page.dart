import 'package:flutter/material.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/constants/app_spacing.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
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
  Set<String> _selectedCategoryIds = {};
  _ViewMode _viewMode = _ViewMode.list;

  // Date period filter state
  String? _activePeriodLabel; // e.g. 'This Month', null = no date filter
  DateTime? _customStart;
  DateTime? _customEnd;

  // Calendar state
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  // Transactions cache for the currently focused month (calendar mode)
  List<Transaction> _calendarMonthTxns = [];
  bool _isLoadingCalendarMonth = false;

  bool get _hasActiveFilters =>
      _selectedCategoryIds.isNotEmpty || _activePeriodLabel != null;

  int get _activeFilterCount =>
      (_activePeriodLabel != null ? 1 : 0) + _selectedCategoryIds.length;

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

  void _applyCategoryFilter(Set<String> ids) {
    setState(() => _selectedCategoryIds = ids);
    final notifier = ref.read(transactionsProvider.notifier);
    notifier.applyFilters(notifier.filters.copyWith(
      categoryIds: ids.toList(),
      clearCategoryIds: ids.isEmpty,
    ));
  }

  void _applyDateFilter(String? label, DateTime? start, DateTime? end) {
    setState(() {
      _activePeriodLabel = label;
      _customStart = start;
      _customEnd = end;
    });
    final notifier = ref.read(transactionsProvider.notifier);
    notifier.applyFilters(notifier.filters.copyWith(
      startDate: start?.toUtc().toIso8601String(),
      endDate: end?.toUtc().toIso8601String(),
      clearStartDate: start == null,
      clearEndDate: end == null,
    ));
  }

  void _showFilterSheet() {
    final allCategories =
        ref.read(categoriesProvider).valueOrNull ?? <Category>[];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        allCategories: allCategories,
        selectedCategoryIds: Set.from(_selectedCategoryIds),
        activePeriodLabel: _activePeriodLabel,
        customStart: _customStart,
        customEnd: _customEnd,
        onApply: ({
          required Set<String> categoryIds,
          required String? periodLabel,
          required DateTime? start,
          required DateTime? end,
        }) {
          Navigator.pop(context);
          _applyCategoryFilter(categoryIds);
          _applyDateFilter(periodLabel, start, end);
        },
      ),
    );
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
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
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
                  color: Theme.of(context).colorScheme.outlineVariant,
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
                    .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                color: Theme.of(context).colorScheme.surfaceContainerLow,
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
                Row(
                  children: [
                    // Scrollable type chips
                    Expanded(
                      child: SingleChildScrollView(
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
                    ),
                    const SizedBox(width: 8),
                    // Filter icon button (pinned right) — opens unified filter sheet
                    _FilterIconButton(
                      isActive: _hasActiveFilters,
                      selectedCount: _activeFilterCount,
                      onTap: _showFilterSheet,
                      onClear: _hasActiveFilters
                          ? () {
                              _applyCategoryFilter({});
                              _applyDateFilter(null, null, null);
                            }
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // ── Filter Summary Bar (shown when any filter is active) ─────────
          if (_viewMode == _ViewMode.list)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _hasActiveFilters
                  ? _FilterSummaryBar(
                      txState: txState,
                      currencySymbol: currencySymbol,
                      periodLabel: _activePeriodLabel,
                      customStart: _customStart,
                      customEnd: _customEnd,
                      categoryCount: _selectedCategoryIds.length,
                    )
                  : const SizedBox.shrink(),
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
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8)
                .copyWith(bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg),
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
                    _DateGroupHeader(
                      label: _formatHeaderDate(tx.date),
                      transactions: page.items
                          .where((t) =>
                              _formatHeaderDate(t.date) ==
                              _formatHeaderDate(tx.date))
                          .toList(),
                      currencySymbol: currencySymbol,
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
      loading: () => const TransactionsSkeleton(),
      error: (err, _) => AppErrorWidget(
        title: 'Failed to load transactions',
        message: err.toString().replaceAll('Exception:', '').trim(),
        onRetry: () => ref.read(transactionsProvider.notifier).refresh(),
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
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(80)),
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
                border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(120)),
                borderRadius: BorderRadius.circular(10),
              ),
              formatButtonTextStyle: AppTypography.labelSmall.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
              titleTextStyle: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
              leftChevronIcon: Icon(Icons.chevron_left_rounded,
                  color: Theme.of(context).colorScheme.primary),
              rightChevronIcon: Icon(Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.primary),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: AppTypography.labelSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              weekendStyle: AppTypography.labelSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(150),
                fontWeight: FontWeight.w600,
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(40),
                shape: BoxShape.circle,
              ),
              todayTextStyle: AppTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: AppTypography.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              defaultTextStyle: AppTypography.bodyMedium,
              weekendTextStyle: AppTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              markersMaxCount: 3,
              markerSize: 6,
              markersAnchor: 0.7,
              markerDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
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
              ? const CompactTransactionListSkeleton()
              : _selectedDay == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app_rounded,
                              size: 48,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(80)),
                          const SizedBox(height: 12),
                          Text(
                            'Tap a date to see transactions',
                            style: AppTypography.bodyMedium.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Long-press for quick actions',
                            style: AppTypography.bodySmall.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(150),
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
                                      Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(80)),
                              const SizedBox(height: 12),
                              Text(
                                'No transactions on ${DateFormat('MMM d').format(_selectedDay!)}',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 20).copyWith(
                              bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg),
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
                                        color: Theme.of(context).colorScheme.primary,
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

    if (txDate == today) return 'Today';
    if (txDate == yesterday) return 'Yesterday';
    // Same year → "Mon, 5 May"; different year → "Mon, 5 May 2023"
    if (local.year == now.year) {
      return DateFormat('EEE, d MMM').format(local);
    }
    return DateFormat('EEE, d MMM yyyy').format(local);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Private widgets
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Date Group Header ────────────────────────────────────────────────────────

class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({
    required this.label,
    required this.transactions,
    required this.currencySymbol,
  });

  final String label;
  final List<Transaction> transactions;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final income = transactions
        .where((t) => t.isIncome)
        .fold(0.0, (s, t) => s + t.amount);
    final expense = transactions
        .where((t) => !t.isIncome)
        .fold(0.0, (s, t) => s + t.amount);

    final sem = SemanticColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Row(
        children: [
          // Date label
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 8),
          // Hairline divider
          Expanded(
            child: Container(
              height: 1,
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
            ),
          ),
          // Daily totals
          if (income > 0) ...[
            const SizedBox(width: 8),
            Text(
              '+$currencySymbol${income.toStringAsFixed(0)}',
              style: AppTypography.labelSmall.copyWith(
                color: sem.cashIn,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (expense > 0) ...[
            const SizedBox(width: 6),
            Text(
              '-$currencySymbol${expense.toStringAsFixed(0)}',
              style: AppTypography.labelSmall.copyWith(
                color: sem.cashOut,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
          color: isActive ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isActive ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
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
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600, // constant font weight to prevent layout shift
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
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: AppTypography.bodyMedium
                      .copyWith(fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: Theme.of(context).colorScheme.outlineVariant),
          ],
        ),
      ),
    );
  }
}

// ─── Filter Summary Bar ──────────────────────────────────────────────────────

class _FilterSummaryBar extends StatelessWidget {
  const _FilterSummaryBar({
    required this.txState,
    required this.currencySymbol,
    required this.periodLabel,
    required this.customStart,
    required this.customEnd,
    required this.categoryCount,
  });

  final AsyncValue<TransactionPage> txState;
  final String currencySymbol;
  final String? periodLabel;
  final DateTime? customStart;
  final DateTime? customEnd;
  final int categoryCount;

  String get _periodText {
    if (periodLabel == 'Custom' && customStart != null && customEnd != null) {
      final fmt = DateFormat('d MMM');
      return '${fmt.format(customStart!)} – ${fmt.format(customEnd!)}';
    }
    return periodLabel ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    final cs = Theme.of(context).colorScheme;

    final isLoading = txState.isLoading;

    // Only read totals when data is fresh — never show stale values while loading
    final incomeTotal = isLoading ? null : (txState.valueOrNull?.incomeTotal ?? 0.0);
    final expenseTotal = isLoading ? null : (txState.valueOrNull?.expenseTotal ?? 0.0);
    final net = (incomeTotal != null && expenseTotal != null)
        ? incomeTotal - expenseTotal
        : null;
    final total = isLoading ? null : (txState.valueOrNull?.total ?? 0);

    // Build chip labels
    final chips = <String>[
      if (periodLabel != null) _periodText,
      if (categoryCount > 0)
        '$categoryCount ${categoryCount == 1 ? 'category' : 'categories'}',
    ];

    // Helper to format an amount or return placeholder
    String fmtAmount(double? val, {String prefix = ''}) =>
        val == null ? '---' : '$prefix$currencySymbol${val.toStringAsFixed(0)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Totals row
            Row(
              children: [
                // Cash In
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cash In',
                          style: AppTypography.labelSmall
                              .copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text(
                        fmtAmount(incomeTotal, prefix: '+'),
                        style: AppTypography.labelLarge.copyWith(
                          color: isLoading ? cs.onSurfaceVariant : sem.cashIn,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                // Cash Out
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cash Out',
                          style: AppTypography.labelSmall
                              .copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text(
                        fmtAmount(expenseTotal, prefix: '-'),
                        style: AppTypography.labelLarge.copyWith(
                          color: isLoading ? cs.onSurfaceVariant : sem.cashOut,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                // Net
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Net',
                        style: AppTypography.labelSmall
                            .copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(
                      net == null
                          ? '---'
                          : '${net >= 0 ? '+' : ''}$currencySymbol${net.abs().toStringAsFixed(0)}',
                      style: AppTypography.labelLarge.copyWith(
                        color: net == null
                            ? cs.onSurfaceVariant
                            : net >= 0
                                ? sem.cashIn
                                : sem.cashOut,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
              // Active filter chips + total count
              if (chips.isNotEmpty || (total != null && total > 0)) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        children: chips
                            .map((label) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: cs.primary.withAlpha(15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: cs.primary.withAlpha(60)),
                                  ),
                                  child: Text(
                                    label,
                                    style: AppTypography.labelSmall.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    Text(
                      total == null ? '...' : '$total txn${total == 1 ? '' : 's'}',
                      style: AppTypography.labelSmall
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Filter Icon Button (pinned right) ────────────────────────────────────────

class _FilterIconButton extends StatelessWidget {
  const _FilterIconButton({
    required this.isActive,
    required this.selectedCount,
    required this.onTap,
    this.onClear,
  });

  final bool isActive;
  final int selectedCount;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onClear,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? color.withAlpha(20) : surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : Theme.of(context).colorScheme.outlineVariant,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                Icons.tune_rounded,
                size: 20,
                color: isActive ? color : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (isActive)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Unified Filter Bottom Sheet ─────────────────────────────────────────────

// Period preset definitions
const _kPeriodLabels = [
  'Today',
  'This Week',
  'This Month',
  'Last 3 Months',
  'Last 6 Months',
  'This Year',
  'Custom',
];

/// Converts a period label to a [start, end] date range.
/// Returns [null, null] for 'Custom' (caller handles pickers).
List<DateTime?> _periodToDates(String label) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  switch (label) {
    case 'Today':
      return [today, DateTime(today.year, today.month, today.day, 23, 59, 59)];
    case 'This Week':
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      return [weekStart, DateTime(now.year, now.month, now.day, 23, 59, 59)];
    case 'This Month':
      return [
        DateTime(now.year, now.month, 1),
        DateTime(now.year, now.month, now.day, 23, 59, 59)
      ];
    case 'Last 3 Months':
      return [
        DateTime(now.year, now.month - 2, 1),
        DateTime(now.year, now.month, now.day, 23, 59, 59)
      ];
    case 'Last 6 Months':
      return [
        DateTime(now.year, now.month - 5, 1),
        DateTime(now.year, now.month, now.day, 23, 59, 59)
      ];
    case 'This Year':
      return [
        DateTime(now.year, 1, 1),
        DateTime(now.year, now.month, now.day, 23, 59, 59)
      ];
    default:
      return [null, null];
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.allCategories,
    required this.selectedCategoryIds,
    required this.activePeriodLabel,
    required this.customStart,
    required this.customEnd,
    required this.onApply,
  });

  final List<Category> allCategories;
  final Set<String> selectedCategoryIds;
  final String? activePeriodLabel;
  final DateTime? customStart;
  final DateTime? customEnd;
  final void Function({
    required Set<String> categoryIds,
    required String? periodLabel,
    required DateTime? start,
    required DateTime? end,
  }) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<String> _pendingCategoryIds;
  String? _pendingPeriodLabel;
  DateTime? _pendingCustomStart;
  DateTime? _pendingCustomEnd;

  @override
  void initState() {
    super.initState();
    _pendingCategoryIds = Set.from(widget.selectedCategoryIds);
    _pendingPeriodLabel = widget.activePeriodLabel;
    _pendingCustomStart = widget.customStart;
    _pendingCustomEnd = widget.customEnd;
  }

  void _toggleCategory(String id) {
    setState(() {
      if (_pendingCategoryIds.contains(id)) {
        _pendingCategoryIds.remove(id);
      } else {
        _pendingCategoryIds.add(id);
      }
    });
  }

  void _selectPeriod(String label) {
    setState(() {
      if (_pendingPeriodLabel == label) {
        // Tap again to deselect
        _pendingPeriodLabel = null;
        _pendingCustomStart = null;
        _pendingCustomEnd = null;
      } else {
        _pendingPeriodLabel = label;
        if (label != 'Custom') {
          final dates = _periodToDates(label);
          _pendingCustomStart = dates[0];
          _pendingCustomEnd = dates[1];
        }
      }
    });
  }

  Future<void> _pickCustomDate(bool isStart) async {
    final initial = isStart
        ? (_pendingCustomStart ?? DateTime.now())
        : (_pendingCustomEnd ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _pendingCustomStart = DateTime(picked.year, picked.month, picked.day);
      } else {
        _pendingCustomEnd =
            DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  void _clearAll() {
    setState(() {
      _pendingCategoryIds = {};
      _pendingPeriodLabel = null;
      _pendingCustomStart = null;
      _pendingCustomEnd = null;
    });
  }

  int get _totalActiveCount =>
      (_pendingPeriodLabel != null ? 1 : 0) + _pendingCategoryIds.length;

  bool get _hasAny =>
      _pendingPeriodLabel != null || _pendingCategoryIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final incomeCategories =
        widget.allCategories.where((c) => c.isIncome).toList();
    final expenseCategories =
        widget.allCategories.where((c) => c.isExpense).toList();
    final fmt = DateFormat('d MMM yyyy');

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // ── Drag handle ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  Text('Filters',
                      style: AppTypography.titleMedium
                          .copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_hasAny)
                    TextButton(
                      onPressed: _clearAll,
                      child: Text(
                        'Clear all',
                        style: AppTypography.labelMedium
                            .copyWith(color: cs.primary),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Scrollable content ────────────────────────────────────────
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                children: [

                  // ── Date Period section ──────────────────────────────
                  _SectionLabel(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date Period',
                    color: cs.primary,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _kPeriodLabels.map((label) {
                      final isSelected = _pendingPeriodLabel == label;
                      return GestureDetector(
                        onTap: () => _selectPeriod(label),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? cs.primary.withAlpha(25)
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? cs.primary
                                  : cs.outlineVariant,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            label,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: isSelected
                                      ? cs.primary
                                      : cs.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // Custom date pickers (shown when Custom is selected)
                  if (_pendingPeriodLabel == 'Custom') ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _DatePickerTile(
                            label: 'From',
                            date: _pendingCustomStart,
                            formatter: fmt,
                            onTap: () => _pickCustomDate(true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DatePickerTile(
                            label: 'To',
                            date: _pendingCustomEnd,
                            formatter: fmt,
                            onTap: () => _pickCustomDate(false),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 28),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  // ── Category section ─────────────────────────────────
                  _SectionLabel(
                    icon: Icons.label_outline_rounded,
                    label: 'Category',
                    color: cs.primary,
                  ),
                  const SizedBox(height: 12),

                  if (incomeCategories.isNotEmpty) ...[
                    _SectionLabel(
                      icon: Icons.arrow_downward_rounded,
                      label: 'Cash In',
                      color: SemanticColors.of(context).cashIn,
                    ),
                    const SizedBox(height: 10),
                    _CategoryChipGrid(
                      categories: incomeCategories,
                      selectedIds: _pendingCategoryIds,
                      onToggle: _toggleCategory,
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (expenseCategories.isNotEmpty) ...[
                    _SectionLabel(
                      icon: Icons.arrow_upward_rounded,
                      label: 'Cash Out',
                      color: SemanticColors.of(context).cashOut,
                    ),
                    const SizedBox(height: 10),
                    _CategoryChipGrid(
                      categories: expenseCategories,
                      selectedIds: _pendingCategoryIds,
                      onToggle: _toggleCategory,
                    ),
                  ],
                  if (widget.allCategories.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No categories yet',
                          style: AppTypography.bodyMedium.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),

                  // Bottom padding so last item isn't behind the button
                  const SizedBox(height: 80),
                ],
              ),
            ),

            // ── Apply button ──────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      // Validate custom range before applying
                      if (_pendingPeriodLabel == 'Custom' &&
                          (_pendingCustomStart == null ||
                              _pendingCustomEnd == null)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Please select both From and To dates')),
                        );
                        return;
                      }
                      widget.onApply(
                        categoryIds: _pendingCategoryIds,
                        periodLabel: _pendingPeriodLabel,
                        start: _pendingPeriodLabel != null
                            ? _pendingCustomStart
                            : null,
                        end: _pendingPeriodLabel != null
                            ? _pendingCustomEnd
                            : null,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _totalActiveCount == 0
                          ? 'Show All'
                          : 'Apply ($_totalActiveCount)',
                      style: AppTypography.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Date Picker Tile ─────────────────────────────────────────────────────────

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.label,
    required this.date,
    required this.formatter,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final DateFormat formatter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasDate = date != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hasDate
              ? cs.primary.withAlpha(15)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasDate ? cs.primary : cs.outlineVariant,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTypography.labelSmall
                    .copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              hasDate ? formatter.format(date!) : 'Tap to select',
              style: AppTypography.labelMedium.copyWith(
                color: hasDate ? cs.primary : cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _CategoryChipGrid extends StatelessWidget {
  const _CategoryChipGrid({
    required this.categories,
    required this.selectedIds,
    required this.onToggle,
  });
  final List<Category> categories;
  final Set<String> selectedIds;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((cat) {
        final isSelected = selectedIds.contains(cat.id);
        final color = cat.isIncome
            ? SemanticColors.of(context).cashIn
            : SemanticColors.of(context).cashOut;
        return GestureDetector(
          onTap: () => onToggle(cat.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withAlpha(30)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? color
                    : Theme.of(context).colorScheme.outlineVariant,
                width: 1, // constant width to prevent layout shift
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cat.emoji,
                    style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
                Text(
                  cat.name,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isSelected
                            ? color
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600, // constant font weight to prevent layout shift
                      ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
