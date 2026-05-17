/// SavingsPage — redesigned with new layout and wishlist inline checklist.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../wishlist/domain/entities/wishlist_item.dart';
import '../../../wishlist/presentation/providers/wishlist_provider.dart';
import '../../domain/entities/savings.dart';
import '../providers/savings_provider.dart';

enum _ViewMode { raw, minusWishlist, minusAll }

class SavingsPage extends ConsumerStatefulWidget {
  const SavingsPage({super.key});

  @override
  ConsumerState<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends ConsumerState<SavingsPage> {
  _ViewMode _mode = _ViewMode.raw;
  bool _showCashEdit = false;

  Future<void> _handleRefresh() async {
    ref.invalidate(savingsProvider);
    ref.invalidate(wishlistProvider);
    await Future.wait([
      ref.read(savingsProvider.future).catchError((_) => Savings.empty),
      ref.read(wishlistProvider.future).catchError((_) => <WishlistItem>[]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final savingsAsync = ref.watch(savingsProvider);
    final wishlistAsync = ref.watch(wishlistProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => context.pop(),
              ),
              title: Text('Savings',
                  style: AppTypography.titleLarge.copyWith(
                      color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, 120),
              sliver: savingsAsync.when(
              loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SliverFillRemaining(
                  child: Center(
                      child: Text('Error: $e',
                          style: TextStyle(color: Theme.of(context).colorScheme.error)))),
              data: (savings) {
                final wishlistItems = (wishlistAsync.valueOrNull ?? [])
                    .where((i) => !i.isPurchased)
                    .toList();
                final checkedTotal = wishlistItems
                    .where((i) => i.deductFromSavings)
                    .fold(0.0, (s, i) => s + (i.targetPrice ?? i.amountSaved));
                final overBudget = checkedTotal > savings.rawTotal && savings.rawTotal > 0;

                return SliverList(
                  delegate: SliverChildListDelegate([
                    // 1. Hero balance card
                    _BalanceHeroCard(
                      savings: savings,
                      mode: _mode,
                      wishlistItems: wishlistItems,
                      onEditTotal: () => _showEditTotalDialog(context),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 2. "Show spendable balance" toggle
                    _SpendableToggle(
                      value: savings.deductFromBalance,
                      savingsAmount: savings.rawTotal,
                      onChanged: (v) => ref
                          .read(savingsProvider.notifier)
                          .toggleDeductFromBalance(value: v),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 3. Cash in hand card (above chips)
                    _CashDeductionCard(
                      currentValue: savings.cashDeduction,
                      isExpanded: _showCashEdit,
                      onToggle: () =>
                          setState(() => _showCashEdit = !_showCashEdit),
                      onSave: (val) {
                        ref
                            .read(savingsProvider.notifier)
                            .updateCashDeduction(val);
                        setState(() => _showCashEdit = false);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 4. View mode chips
                    _ViewModeChips(
                      selected: _mode,
                      onChanged: (m) => setState(() => _mode = m),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 5. Over-budget warning
                    if (overBudget && _mode == _ViewMode.minusWishlist)
                      _OverBudgetWarning(
                        checkedTotal: checkedTotal,
                        savingsTotal: savings.rawTotal,
                      ),

                    // 6. Wishlist inline checklist (only when −Wishlist mode)
                    if (_mode == _ViewMode.minusWishlist) ...[
                      if (wishlistItems.isEmpty)
                        _EmptyWishlistHint(onTap: () => context.push('/wishlist'))
                      else ...[
                        _WishlistChecklist(
                          items: wishlistItems,
                          onToggle: (id) => ref
                              .read(wishlistProvider.notifier)
                              .toggleDeduct(id),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _WishlistTotal(
                          checkedTotal: checkedTotal,
                          rawTotal: savings.rawTotal,
                          overBudget: overBudget,
                        ),
                      ],
                    ],

                    // 7. −All breakdown
                    if (_mode == _ViewMode.minusAll)
                      _DeductionBreakdown(savings: savings),
                  ]),
                );
              },
            ),
          ),
          ],
        ),
      ),
    );
  }

  void _showEditTotalDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.md)),
        title: Text('Update Total Savings', style: AppTypography.titleMedium),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
          ],
          decoration: InputDecoration(
            hintText: 'Enter amount',
            prefixText: '₹ ',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.sm)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              if (val != null) {
                ref.read(savingsProvider.notifier).updateTotal(val);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Balance Card ────────────────────────────────────────────────────────

class _BalanceHeroCard extends StatelessWidget {
  const _BalanceHeroCard({
    required this.savings,
    required this.mode,
    required this.wishlistItems,
    required this.onEditTotal,
  });

  final Savings savings;
  final _ViewMode mode;
  final List<WishlistItem> wishlistItems;
  final VoidCallback onEditTotal;

  @override
  Widget build(BuildContext context) {
    final raw = savings.rawTotal;
    final cash = savings.cashDeduction;
    final checkedTotal = wishlistItems
        .where((i) => i.deductFromSavings)
        .fold(0.0, (s, i) => s + (i.targetPrice ?? i.amountSaved));

    double displayed;
    String label;
    switch (mode) {
      case _ViewMode.raw:
        displayed = raw;
        label = 'Total Savings';
      case _ViewMode.minusWishlist:
        displayed = (raw - checkedTotal).clamp(0.0, double.infinity);
        label = 'After Wishlist';
      case _ViewMode.minusAll:
        displayed = (raw - cash - checkedTotal).clamp(0.0, double.infinity);
        label = 'Net Savings';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: Theme.of(context).brightness == Brightness.dark ? AppColorsDark.primaryGradient : AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        boxShadow: Theme.of(context).brightness == Brightness.dark ? AppColorsDark.cardShadow : AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.labelMedium
                  .copyWith(color: Colors.white.withValues(alpha: 0.75))),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text('₹${displayed.toStringAsFixed(2)}',
                    style: AppTypography.balanceHero
                        .copyWith(color: Colors.white)),
              ),
              IconButton(
                onPressed: onEditTotal,
                icon: const Icon(Icons.edit_rounded,
                    color: Colors.white70, size: 20),
                tooltip: 'Edit total savings',
              ),
            ],
          ),
          if (mode != _ViewMode.raw) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Raw: ₹${raw.toStringAsFixed(2)}',
                style: AppTypography.labelSmall
                    .copyWith(color: Colors.white.withValues(alpha: 0.6))),
          ],
        ],
      ),
    );
  }
}

// ─── Spendable Balance Toggle ─────────────────────────────────────────────────

class _SpendableToggle extends StatelessWidget {
  const _SpendableToggle({
    required this.value,
    required this.savingsAmount,
    required this.onChanged,
  });

  final bool value;
  final double savingsAmount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: value
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
            : Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(
          color:
              value ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3) : Theme.of(context).colorScheme.surfaceContainer,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.account_balance_wallet_rounded,
                size: 20, color: Theme.of(context).colorScheme.secondary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Show spendable balance on Home',
                    style: AppTypography.titleSmall),
                Text(
                  value
                      ? 'Home shows balance minus ₹${savingsAmount.toStringAsFixed(0)} savings'
                      : 'Home shows full balance',
                  style: AppTypography.bodySmall
                      .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: Theme.of(context).colorScheme.primary,
            activeTrackColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ─── Cash Deduction Card ──────────────────────────────────────────────────────

class _CashDeductionCard extends StatefulWidget {
  const _CashDeductionCard({
    required this.currentValue,
    required this.isExpanded,
    required this.onToggle,
    required this.onSave,
  });
  final double currentValue;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ValueChanged<double> onSave;

  @override
  State<_CashDeductionCard> createState() => _CashDeductionCardState();
}

class _CashDeductionCardState extends State<_CashDeductionCard> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.currentValue > 0
            ? widget.currentValue.toStringAsFixed(2)
            : '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: Theme.of(context).colorScheme.surfaceContainer),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: widget.onToggle,
            borderRadius: BorderRadius.circular(AppSpacing.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.wallet_rounded,
                        size: 20, color: Theme.of(context).colorScheme.tertiary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Offline Savings', style: AppTypography.titleSmall),
                         Text(
                          widget.currentValue > 0
                              ? '₹${widget.currentValue.toStringAsFixed(2)} kept separately'
                              : 'Cash/savings not in your main balance',
                          style: AppTypography.bodySmall
                              .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    widget.isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ],
              ),
            ),
          ),
          if (widget.isExpanded) ...[
            Divider(height: 1, color: Theme.of(context).colorScheme.surfaceContainer),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'))
                      ],
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixText: '₹ ',
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.sm)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: () {
                      widget.onSave(double.tryParse(_ctrl.text) ?? 0);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── View Mode Chips ──────────────────────────────────────────────────────────

class _ViewModeChips extends StatelessWidget {
  const _ViewModeChips({required this.selected, required this.onChanged});
  final _ViewMode selected;
  final ValueChanged<_ViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip(
          label: 'Raw',
          selected: selected == _ViewMode.raw,
          onTap: () => onChanged(_ViewMode.raw),
        ),
        const SizedBox(width: AppSpacing.sm),
        _Chip(
          label: '− Wishlist',
          selected: selected == _ViewMode.minusWishlist,
          onTap: () => onChanged(_ViewMode.minusWishlist),
        ),
        const SizedBox(width: AppSpacing.sm),
        _Chip(
          label: 'Net View',
          selected: selected == _ViewMode.minusAll,
          onTap: () => onChanged(_ViewMode.minusAll),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: AppTypography.labelMedium.copyWith(
              color: selected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
            )),
      ),
    );
  }
}

// ─── Over-budget Warning ──────────────────────────────────────────────────────

class _OverBudgetWarning extends StatelessWidget {
  const _OverBudgetWarning(
      {required this.checkedTotal, required this.savingsTotal});
  final double checkedTotal;
  final double savingsTotal;

  @override
  Widget build(BuildContext context) {
    final over = checkedTotal - savingsTotal;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: const Color(0xFFFFCA28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFF57F17), size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Selected wishlist items exceed savings by ₹${over.toStringAsFixed(2)}. Uncheck some items.',
              style: AppTypography.bodySmall
                  .copyWith(color: const Color(0xFF7B5B00)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Wishlist Inline Checklist ────────────────────────────────────────────────

class _WishlistChecklist extends StatelessWidget {
  const _WishlistChecklist({required this.items, required this.onToggle});
  final List<WishlistItem> items;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: Theme.of(context).colorScheme.surfaceContainer),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm + 2, AppSpacing.md, AppSpacing.xs),
            child: Text('Wishlist Items',
                style: AppTypography.labelSmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 1.1)),
          ),
          ...items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            return Column(
              children: [
                InkWell(
                  onTap: () => onToggle(item.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: Row(
                      children: [
                        // Checkbox
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: item.deductFromSavings
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: item.deductFromSavings
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outlineVariant,
                              width: 2,
                            ),
                          ),
                          child: item.deductFromSavings
                              ? Icon(Icons.check_rounded,
                                  size: 14, color: Theme.of(context).colorScheme.onPrimary)
                              : null,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(item.emoji,
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title,
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w500,
                                    decoration: item.deductFromSavings
                                        ? null
                                        : null,
                                  )),
                              if (item.targetPrice != null || item.amountSaved > 0)
                                Text(
                                    item.targetPrice != null
                                        ? '₹${item.targetPrice!.toStringAsFixed(0)} target'
                                        : '₹${item.amountSaved.toStringAsFixed(0)} saved',
                                    style: AppTypography.bodySmall.copyWith(
                                        color: Theme.of(context).colorScheme.secondary)),
                            ],
                          ),
                        ),
                        Text(
                          item.deductFromSavings
                              ? '−₹${(item.targetPrice ?? item.amountSaved).toStringAsFixed(0)}'
                              : '',
                          style: AppTypography.labelMedium.copyWith(
                              color: SemanticColors.of(context).cashOut,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                if (i < items.length - 1)
                  Divider(
                      height: 1,
                      indent: 56,
                      color: Theme.of(context).colorScheme.surfaceContainer),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ─── Wishlist Total Row ───────────────────────────────────────────────────────

class _WishlistTotal extends StatelessWidget {
  const _WishlistTotal({
    required this.checkedTotal,
    required this.rawTotal,
    required this.overBudget,
  });
  final double checkedTotal;
  final double rawTotal;
  final bool overBudget;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: overBudget
            ? Theme.of(context).colorScheme.error.withValues(alpha: 0.08)
            : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(
          color: overBudget
              ? Theme.of(context).colorScheme.error.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total wishlist deduction',
              style: AppTypography.bodySmall
                  .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text('−₹${checkedTotal.toStringAsFixed(2)}',
              style: AppTypography.titleSmall.copyWith(
                  color: overBudget ? Theme.of(context).colorScheme.error : SemanticColors.of(context).cashOut,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─── Empty Wishlist Hint ──────────────────────────────────────────────────────

class _EmptyWishlistHint extends StatelessWidget {
  const _EmptyWishlistHint({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          border: Border.all(color: Theme.of(context).colorScheme.surfaceContainer),
        ),
        child: Row(
          children: [
            const Text('🛍️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text('No wishlist items yet. Tap to add some.',
                  style: AppTypography.bodySmall
                      .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.outlineVariant),
          ],
        ),
      ),
    );
  }
}

// ─── −All Breakdown ───────────────────────────────────────────────────────────

class _DeductionBreakdown extends StatelessWidget {
  const _DeductionBreakdown({required this.savings});
  final Savings savings;

  @override
  Widget build(BuildContext context) {
    final raw = savings.rawTotal;
    final cash = savings.cashDeduction;
    final wishlist = savings.wishlistDeduction;
    final effective = savings.effectiveTotal;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: Theme.of(context).colorScheme.surfaceContainer),
      ),
      child: Column(
        children: [
          _Row(label: 'Raw Savings', value: raw),
          _Row(label: '− Wishlist (target prices)', value: -wishlist),
          _Row(label: '− Offline Savings', value: -cash),
          Divider(height: 16, color: Theme.of(context).colorScheme.surfaceContainer),
          _Row(label: 'Net Savings', value: effective, isTotal: true),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.isTotal = false});
  final String label;
  final double value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: isTotal
                  ? AppTypography.titleSmall
                  : AppTypography.bodySmall
                      .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(
            '${value < 0 ? '' : ''}₹${value.abs().toStringAsFixed(2)}',
            style: isTotal
                ? AppTypography.titleSmall.copyWith(
                    color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)
                : AppTypography.bodySmall.copyWith(
                    color: value < 0 ? SemanticColors.of(context).cashOut : Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}
