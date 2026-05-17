/// DuesPage — the Dues tab (branch 2 of StatefulShellRoute).
///
/// Layout:
///   - Summary banner: total I owe / they owe me
///   - Two inner tabs: I Owe | They Owe Me
///   - DueCard with swipe-to-settle (right) and swipe-to-delete (left)
///   - FAB → AddDuePage
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../domain/entities/due.dart';
import '../providers/dues_provider.dart';
import '../../../splits/presentation/providers/splits_provider.dart';
import '../../../splits/presentation/pages/add_split_page.dart';
import '../../../splits/presentation/widgets/split_card.dart';
import 'add_due_page.dart';

class DuesPage extends ConsumerStatefulWidget {
  const DuesPage({super.key});

  @override
  ConsumerState<DuesPage> createState() => _DuesPageState();
}

class _DuesPageState extends ConsumerState<DuesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openAddDue() async {
    // Pre-select the tab type matching whichever dues tab is currently shown
    final initialType = _tabController.index == 1 ? 'THEY_OWE' : 'I_OWE';
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AddDuePage(initialType: initialType),
      ),
    );
    if (result == true && mounted) {
      ref.invalidate(duesSummaryProvider);
    }
  }

  Future<void> _openAddSplit() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const AddSplitPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final duesAsync = ref.watch(duesProvider);
    final summaryAsync = ref.watch(duesSummaryProvider);
    final splitsAsync = ref.watch(splitsProvider);
    final isSplitsTab = _tabController.index == 2;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            onRefresh: () async {
              ref.invalidate(duesProvider);
              ref.invalidate(duesSummaryProvider);
              await ref.read(duesProvider.future);
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // ── AppBar ────────────────────────────────────────────────────────
                SliverAppBar(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  surfaceTintColor: Colors.transparent,
                  pinned: true,
                  elevation: 0,
                  title: const Text('Dues'),
                  centerTitle: false,
                  bottom: TabBar(
                    controller: _tabController,
                    labelColor: SemanticColors.of(context).cashOut,
                    unselectedLabelColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    indicatorColor: SemanticColors.of(context).cashOut,
                    labelStyle: AppTypography.labelLarge
                        .copyWith(fontWeight: FontWeight.bold),
                    tabs: const [
                      Tab(text: '😬 I Owe'),
                      Tab(text: '🤝 They Owe Me'),
                      Tab(text: '🍽️ Splits'),
                    ],
                    onTap: (_) => setState(() {}),
                  ),
                ),

                // ── Summary banner (hidden on Splits tab) ─────────────────────────
                if (!isSplitsTab)
                  SliverToBoxAdapter(
                    child: summaryAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (s) => _SummaryBanner(
                        iOweTotal: s.iOweTotal,
                        theyOweTotal: s.theyOweTotal,
                      ),
                    ),
                  ),

                // ── Dues list (tabs 0 and 1 only) ────────────────────────────────
                if (!isSplitsTab)
                  duesAsync.when(
                    loading: () => const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline_rounded,
                                size: 48, color: SemanticColors.of(context).cashOut),
                            const SizedBox(height: 12),
                            Text(e.toString().replaceAll('Exception:', '').trim(),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => ref.invalidate(duesProvider),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (dues) {
                      final filtered = dues
                          .where(
                            (d) => _tabController.index == 0
                                ? d.isIOwe && !d.isPaid
                                : d.isTheyOwe && !d.isPaid,
                          )
                          .toList();

                      if (filtered.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 60),
                            child: _EmptyState(
                              isIOwe: _tabController.index == 0,
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          MediaQuery.of(context).padding.bottom + 80,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _DueCard(
                              due: filtered[i],
                              onSettle: () => _confirmSettle(filtered[i]),
                              onDelete: () => _confirmDelete(filtered[i]),
                              onEdit: () => _openEdit(filtered[i]),
                            ),
                            childCount: filtered.length,
                          ),
                        ),
                      );
                    },
                  ),
                // ── Splits list (tab 2) ───────────────────────────────────────
                if (isSplitsTab)
                  splitsAsync.when(
                    loading: () => const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline_rounded,
                                size: 48, color: SemanticColors.of(context).cashOut),
                            const SizedBox(height: 12),
                            Text(
                                e
                                    .toString()
                                    .replaceAll('Exception:', '')
                                    .trim(),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => ref.invalidate(splitsProvider),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (splits) {
                      if (splits.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 60),
                            child: _SplitsEmptyState(),
                          ),
                        );
                      }
                      return SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          MediaQuery.of(context).padding.bottom + AppSpacing.lg,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => SplitCard(
                              split: splits[i],
                              onDelete: () => ref
                                  .read(splitsProvider.notifier)
                                  .removeSplit(splits[i].id),
                            ),
                            childCount: splits.length,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          // ── FAB — context-aware ─────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            child: FloatingActionButton.extended(
              onPressed: isSplitsTab ? _openAddSplit : _openAddDue,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              icon: const Icon(Icons.add_rounded),
              label: Text(isSplitsTab ? 'New Split' : 'Add Due'),
              elevation: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _confirmSettle(Due due) async {
    bool logAsTransaction = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Settle Due'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mark "${due.title}" with ${due.personName} as settled?'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: logAsTransaction,
                    onChanged: (v) =>
                        setState(() => logAsTransaction = v ?? false),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      due.isIOwe
                          ? 'Log as Cash Out transaction'
                          : 'Log as Cash In transaction',
                      style: AppTypography.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: SemanticColors.of(context).cashIn),
              child: const Text('Settle'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(duesProvider.notifier).settleDue(
              due.id,
              logAsTransaction: logAsTransaction,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${due.title}" settled ✓'),
              backgroundColor: SemanticColors.of(context).cashIn,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    }
  }

  Future<void> _confirmDelete(Due due) async {
    final result = await ref
        .read(duesProvider.notifier)
        .removeDue(due.id)
        .then((_) => true)
        .catchError((_) => false);
    if (result && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${due.title}" deleted'),
          action: SnackBarAction(
            label: 'Undo',
            // Re-adding is not trivial — we just reload
            onPressed: () => ref.invalidate(duesProvider),
          ),
        ),
      );
    }
  }

  Future<void> _openEdit(Due due) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AddDuePage(existing: due),
      ),
    );
  }
}

// ─── Summary Banner ───────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.iOweTotal, required this.theyOweTotal});
  final double iOweTotal;
  final double theyOweTotal;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compact();
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryChip(
              label: 'I Owe',
              amount: fmt.format(iOweTotal),
              color: SemanticColors.of(context).cashOut,
              icon: Icons.arrow_upward_rounded,
            ),
          ),
          Container(
              width: 1,
              height: 40,
              color: Theme.of(context).colorScheme.outlineVariant),
          Expanded(
            child: _SummaryChip(
              label: 'I Receive',
              amount: fmt.format(theyOweTotal),
              color: SemanticColors.of(context).cashIn,
              icon: Icons.arrow_downward_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final String amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: AppTypography.labelSmall.copyWith(color: color)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '₹$amount',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── Due Card ─────────────────────────────────────────────────────────────────

class _DueCard extends StatelessWidget {
  const _DueCard({
    required this.due,
    required this.onSettle,
    required this.onDelete,
    required this.onEdit,
  });

  final Due due;
  final VoidCallback onSettle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final isOverdue = due.isOverdue;
    final accent = due.isIOwe ? SemanticColors.of(context).cashOut : SemanticColors.of(context).cashIn;

    return Dismissible(
      key: ValueKey(due.id),
      background: _SwipeBackground(
        color: SemanticColors.of(context).cashIn,
        icon: Icons.check_rounded,
        label: 'Settle',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        color: SemanticColors.of(context).cashOut,
        icon: Icons.delete_outline_rounded,
        label: 'Delete',
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onSettle();
          return false; // settle dialog handles removal
        } else {
          onDelete();
          return false; // we manage removal ourselves
        }
      },
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOverdue
                  ? SemanticColors.of(context).cashOut.withValues(alpha: 0.5)
                  : Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // Avatar circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    due.personName.isNotEmpty
                        ? due.personName[0].toUpperCase()
                        : '?',
                    style: AppTypography.titleLarge.copyWith(color: accent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        due.personName,
                        style: AppTypography.titleSmall
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        due.title,
                        style: AppTypography.bodySmall.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (due.categoryName != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (due.categoryEmoji != null)
                              Text(due.categoryEmoji!,
                                  style: const TextStyle(fontSize: 11)),
                            const SizedBox(width: 3),
                            Text(
                              due.categoryName!,
                              style: AppTypography.labelSmall.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (due.dueDate != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${isOverdue ? '⚠️ Overdue: ' : 'Due: '}${DateFormat('MMM d').format(due.dueDate!)}',
                          style: AppTypography.labelSmall.copyWith(
                            color: isOverdue
                                ? SemanticColors.of(context).cashOut
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                            fontWeight:
                                isOverdue ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${NumberFormat.compact().format(due.amount)}',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Settle button
                    GestureDetector(
                      onTap: onSettle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: SemanticColors.of(context).cashIn.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Settle',
                          style: AppTypography.labelSmall.copyWith(
                              color: SemanticColors.of(context).cashIn,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 2),
          Text(label,
              style: AppTypography.labelSmall.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isIOwe});
  final bool isIOwe;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isIOwe ? '🎉' : '🤑', style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          Text(
            isIOwe ? 'You don\'t owe anyone!' : 'Nobody owes you anything yet.',
            style: AppTypography.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            isIOwe
                ? 'Debt-free is the way to be.'
                : 'Add dues to track who owes you.',
            style: AppTypography.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Splits Empty State ───────────────────────────────────────────────────────

class _SplitsEmptyState extends StatelessWidget {
  const _SplitsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🍽️', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          Text('No splits yet!', style: AppTypography.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Tap "New Split" to split a bill with friends.',
            style: AppTypography.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
