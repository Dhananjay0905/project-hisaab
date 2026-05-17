/// HomePage — the dashboard screen (Branch 0 of StatefulShellRoute).
///
/// Sections:
///  1. Hero balance card (gradient, current balance, income/expense chips)
///  2. This month quick stats row
///  3. Recent transactions list (last 5)
///  4. Top spending categories bar
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/theme_mode_provider.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/domain/entities/summary.dart';
import '../../../dashboard/presentation/providers/summary_provider.dart';
import '../../../savings/presentation/providers/savings_provider.dart';

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning,';
  if (h < 17) return 'Good afternoon,';
  return 'Good evening,';
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _hasShownRecoveryBanner = false;

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final userAsync = ref.watch(authNotifierProvider);
    final userName = userAsync.valueOrNull is AuthAuthenticated
        ? (userAsync.valueOrNull as AuthAuthenticated)
                .user
                .name
                .split(' ')
                .first
        : 'there';

    final themeMode = ref.watch(themeModeProvider);
    final cs = Theme.of(context).colorScheme;

    // Show recovery banner exactly once per session
    final authState = userAsync.valueOrNull;
    if (!_hasShownRecoveryBanner &&
        authState is AuthAuthenticated &&
        authState.accountRecovered) {
      _hasShownRecoveryBanner = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Account deletion cancelled. Welcome back!',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 5),
          ),
        );
      });
    }


    return Scaffold(
      backgroundColor: cs.surface,
      body: RefreshIndicator(
        color: cs.primary,
        onRefresh: () => ref.read(dashboardSummaryProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // ── App Bar (pinned — status bar always has a solid background) ──
            SliverAppBar(
              backgroundColor: cs.surface,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              elevation: 0,
              expandedHeight: 100,
              title: Text('Hisaab', style: AppTypography.titleLarge),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: Icon(
                      switch (themeMode) {
                        ThemeMode.light  => Icons.light_mode_rounded,
                        ThemeMode.dark   => Icons.dark_mode_rounded,
                        ThemeMode.system => Icons.brightness_auto_rounded,
                      },
                      color: cs.onSurfaceVariant,
                    ),
                    tooltip: switch (themeMode) {
                      ThemeMode.light  => 'Light mode',
                      ThemeMode.dark   => 'Dark mode',
                      ThemeMode.system => 'System mode',
                    },
                    onPressed: () =>
                        ref.read(themeModeProvider.notifier).cycle(),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 48,
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${_greeting()} $userName 👋',
                        style: AppTypography.bodyMedium
                            .copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Content ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: summaryAsync.when(
                loading: () => const _LoadingState(),
                error: (e, _) => _ErrorState(
                  message: e.toString().replaceAll('Exception:', '').trim(),
                  onRetry: () =>
                      ref.read(dashboardSummaryProvider.notifier).refresh(),
                ),
                data: (summary) => _DashboardContent(summary: summary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



// ─── Dashboard Content (when data is ready) ───────────────────────────────────

class _DashboardContent extends ConsumerStatefulWidget {
  const _DashboardContent({required this.summary});
  final Summary summary;

  @override
  ConsumerState<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends ConsumerState<_DashboardContent> {
  bool _balanceVisible = false;

  @override
  Widget build(BuildContext context) {
    // Use valueOrNull — if savings hasn't loaded yet it defaults to 0/false,
    // which avoids changing the returned widget type mid-layout (the source
    // of the Scaffold "Each child must be laid out exactly once" assertion).
    final savings = ref.watch(savingsProvider).valueOrNull;
    final isSpendable = savings?.deductFromBalance ?? false;
    final displayBalance = isSpendable
        ? (widget.summary.currentBalance - (savings?.rawTotal ?? 0))
        : widget.summary.currentBalance;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BalanceCard(
            summary: widget.summary,
            displayBalance: displayBalance,
            balanceVisible: _balanceVisible,
            onToggleVisibility: () =>
                setState(() => _balanceVisible = !_balanceVisible),
          ),
          const SizedBox(height: AppSpacing.lg),
          _MonthStatsRow(summary: widget.summary),
          const SizedBox(height: AppSpacing.xl),
          if (widget.summary.recentTransactions.isNotEmpty) ...[
            _SectionHeader(
              title: 'Recent Transactions',
              onSeeAll: () => GoRouter.of(context).go('/history'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _RecentTransactionsList(
                transactions: widget.summary.recentTransactions),
            const SizedBox(height: AppSpacing.xl),
          ],
          if (widget.summary.topCategories.isNotEmpty) ...[
            _SectionHeader(title: 'Top Spending', onSeeAll: null),
            const SizedBox(height: AppSpacing.sm),
            _TopCategoriesList(categories: widget.summary.topCategories),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}


// ─── Balance Card ─────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.summary,
    required this.displayBalance,
    required this.balanceVisible,
    required this.onToggleVisibility,
  });
  final Summary summary;
  final double displayBalance;
  final bool balanceVisible;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: Theme.of(context).brightness == Brightness.dark ? AppColorsDark.heroCardGradient : AppColors.heroCardGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row with eye toggle
          Row(
            children: [
              Text(
                'Current Balance',
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onToggleVisibility,
                child: Icon(
                  balanceVisible
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Balance — hidden or shown with smooth animation
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: balanceVisible
                ? Text(
                    fmt.format(displayBalance),
                    key: const ValueKey('visible'),
                    style: AppTypography.displayMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Text(
                    '₹  •••••',
                    key: const ValueKey('hidden'),
                    style: AppTypography.displayMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _BalanceChip(
                label: 'Income',
                amount: fmt.format(summary.totalIncome),
                icon: Icons.arrow_downward_rounded,
                color: const Color(0xFF5CFD80),
              ),
              const SizedBox(width: AppSpacing.md),
              _BalanceChip(
                label: 'Expenses',
                amount: fmt.format(summary.totalExpenses),
                icon: Icons.arrow_upward_rounded,
                color: const Color(0xFFF74B6D),
              ),
            ],
          ),
        ],
      ),
    );
  }
}



class _BalanceChip extends StatelessWidget {
  const _BalanceChip({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final String amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              Text(
                amount,
                style: AppTypography.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Month Stats Row ──────────────────────────────────────────────────────────

class _MonthStatsRow extends StatelessWidget {
  const _MonthStatsRow({required this.summary});
  final Summary summary;

  @override
  Widget build(BuildContext context) {
    final month = DateFormat.MMMM().format(DateTime.now());
    final fmt = NumberFormat.compactCurrency(symbol: '₹', decimalDigits: 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$month Overview',
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Income',
                value: fmt.format(summary.thisMonth.income),
                icon: Icons.arrow_downward_rounded,
                accentColor: SemanticColors.of(context).cashIn,
                bgColor: SemanticColors.of(context).cashInSurface,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                label: 'Expenses',
                value: fmt.format(summary.thisMonth.expenses),
                icon: Icons.arrow_upward_rounded,
                accentColor: SemanticColors.of(context).cashOut,
                bgColor: SemanticColors.of(context).cashOutSurface,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                label: 'Txns',
                value: summary.thisMonth.transactionCount.toString(),
                icon: Icons.receipt_long_rounded,
                accentColor: Theme.of(context).colorScheme.primary,
                bgColor: Theme.of(context).colorScheme.surfaceContainerLow,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 18),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});
  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
        const Spacer(),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: Text(
              'See all',
              style: AppTypography.labelMedium.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
      ],
    );
  }
}

// ─── Recent Transactions ──────────────────────────────────────────────────────

class _RecentTransactionsList extends StatelessWidget {
  const _RecentTransactionsList({required this.transactions});
  final List<RecentTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? AppColorsDark.softShadow : AppColors.softShadow,
      ),
      child: Column(
        children: transactions
            .asMap()
            .entries
            .map((entry) {
              final i = entry.key;
              final tx = entry.value;
              return _TransactionTile(
                tx: tx,
                showDivider: i < transactions.length - 1,
              );
            })
            .toList(),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx, required this.showDivider});
  final RecentTransaction tx;
  final bool showDivider;

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat.MMMd().format(d);
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.isIncome;
    final sem = SemanticColors.of(context);
    final amountColor = isIncome ? sem.cashIn : sem.cashOut;
    final amountPrefix = isIncome ? '+' : '-';
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
          child: Row(
            children: [
              // Category emoji avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isIncome
                      ? SemanticColors.of(context).cashInSurface
                      : SemanticColors.of(context).cashOutSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    tx.categoryEmoji ?? (isIncome ? '📥' : '📤'),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Title + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.title,
                      style: AppTypography.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tx.categoryName != null
                          ? '${tx.categoryName} · ${_dateLabel(tx.date)}'
                          : _dateLabel(tx.date),
                      style: AppTypography.bodySmall.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),

              // Amount
              Text(
                '$amountPrefix${fmt.format(tx.amount)}',
                style: AppTypography.titleSmall.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: AppSpacing.md + 44 + AppSpacing.md,
            endIndent: AppSpacing.md,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
          ),
      ],
    );
  }
}

// ─── Top Categories ───────────────────────────────────────────────────────────

class _TopCategoriesList extends StatelessWidget {
  const _TopCategoriesList({required this.categories});
  final List<TopCategory> categories;

  @override
  Widget build(BuildContext context) {
    final fmt =
        NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? AppColorsDark.softShadow : AppColors.softShadow,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: categories.map((cat) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            cat.name,
                            style: AppTypography.bodySmall
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Text(
                            fmt.format(cat.total),
                            style: AppTypography.bodySmall
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (cat.percentage / 100).clamp(0.0, 1.0),
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                          color: SemanticColors.of(context).cashOut,
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${cat.percentage.toStringAsFixed(0)}%',
                  style: AppTypography.labelSmall
                      .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Loading / Error States ───────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Center(
        child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(Icons.cloud_off_rounded,
              size: 56, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: AppSpacing.md),
          Text('Could not load data', style: AppTypography.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: AppTypography.bodySmall
                .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
