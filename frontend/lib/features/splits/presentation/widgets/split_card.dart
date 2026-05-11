/// SplitCard — expandable card showing a split and its participants.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../domain/entities/split.dart';
import '../providers/splits_provider.dart';

class SplitCard extends ConsumerStatefulWidget {
  const SplitCard({
    super.key,
    required this.split,
    required this.onDelete,
  });

  final SplitGroup split;
  final VoidCallback onDelete;

  @override
  ConsumerState<SplitCard> createState() => _SplitCardState();
}

class _SplitCardState extends ConsumerState<SplitCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnim;

  final _fmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnim = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }

  Future<void> _onParticipantToggle(SplitParticipant participant) async {
    if (participant.hasPaid) {
      await ref.read(splitsProvider.notifier).unmarkParticipantPaid(
        widget.split.id,
        participant.id,
      );
      return;
    }

    if (!mounted) return;
    // Returns null (cancelled), or a record of {createTransaction, amount}
    final result = await showDialog<({bool createTransaction, double amount})>(
      context: context,
      builder: (ctx) => _PayDialog(
        name: participant.name,
        expectedAmount: participant.amount,
        fmt: _fmt,
      ),
    );

    if (result == null) return;
    await ref.read(splitsProvider.notifier).markParticipantPaid(
      widget.split.id,
      participant.id,
      createTransaction: result.createTransaction,
      paidAmount: result.amount,
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Split?'),
        content: Text('Delete "${widget.split.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) widget.onDelete();
  }

  void _showEditSheet(BuildContext context) {
    final titleCtrl = TextEditingController(text: widget.split.title);
    final noteCtrl = TextEditingController(text: widget.split.note ?? '');
    bool saving = false;
    // Capture initial category from split
    Category? sheetCategory;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerLowest,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Edit Split',
                      style: AppTypography.titleLarge
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.lg),
                  // Title field
                  Text('Title', style: AppTypography.labelMedium),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: titleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'e.g. Dinner at Barbeque Nation',
                      filled: true,
                      fillColor:
                          Theme.of(ctx).colorScheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Category picker
                  Text('Category', style: AppTypography.labelMedium),
                  const SizedBox(height: AppSpacing.sm),
                  _EditSheetCategoryPicker(
                    currentCategoryId: widget.split.categoryId,
                    selected: sheetCategory,
                    onSelect: (c) => setSheetState(() => sheetCategory = c),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Note field
                  Text('Note (optional)', style: AppTypography.labelMedium),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Any additional details…',
                      filled: true,
                      fillColor:
                          Theme.of(ctx).colorScheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final title = titleCtrl.text.trim();
                              if (title.isEmpty) return;
                              setSheetState(() => saving = true);
                              try {
                                await ref
                                    .read(splitsProvider.notifier)
                                    .updateSplit(
                                      widget.split.id,
                                      title: title,
                                      note: noteCtrl.text.trim().isEmpty
                                          ? null
                                          : noteCtrl.text.trim(),
                                      categoryId: sheetCategory?.id,
                                    );
                                if (ctx.mounted) Navigator.of(ctx).pop();
                              } catch (_) {
                                setSheetState(() => saving = false);
                              }
                            },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.split;
    final progress = s.totalCount > 0 ? s.paidCount / s.totalCount : 0.0;
    final isFullyPaid = s.isFullyPaid;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFullyPaid
              ? SemanticColors.of(context).cashIn.withValues(alpha: 0.4)
              : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // ── Header row ──────────────────────────────────────────────────────
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title, style: AppTypography.titleSmall),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('MMM d, yyyy').format(s.date),
                              style: AppTypography.bodySmall.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (s.categoryName != null) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  if (s.categoryEmoji != null)
                                    Text(s.categoryEmoji!,
                                        style: const TextStyle(fontSize: 11)),
                                  const SizedBox(width: 3),
                                  Text(
                                    s.categoryName!,
                                    style: AppTypography.labelSmall.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      _PaidBadge(paidCount: s.paidCount, total: s.totalCount),
                      const SizedBox(width: AppSpacing.sm),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  Row(
                    children: [
                      Text(
                        '₹${_fmt.format(s.totalAmount)}',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (s.collectedAmount > 0)
                        Text(
                          'Collected ₹${_fmt.format(s.collectedAmount)}',
                          style: AppTypography.bodySmall.copyWith(
                            color: SemanticColors.of(context).cashIn,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isFullyPaid ? SemanticColors.of(context).cashIn : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded participant list ────────────────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnim,
            child: Column(
              children: [
                Divider(
                  height: 1,
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.3),
                ),
                ...s.participants.map((p) => _ParticipantRow(
                  participant: p,
                  fmt: _fmt,
                  onToggle: () => _onParticipantToggle(p),
                )),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _showEditSheet(context),
                        icon: const Icon(Icons.edit_outlined,
                            size: 16, color: AppColors.primary),
                        label: Text(
                          'Edit',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.primary),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _confirmDelete,
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 16, color: AppColors.error),
                        label: Text(
                          'Delete',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
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

// ─── Participant Row ──────────────────────────────────────────────────────────

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.participant,
    required this.fmt,
    required this.onToggle,
  });

  final SplitParticipant participant;
  final NumberFormat fmt;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final paid = participant.hasPaid;
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: paid ? SemanticColors.of(context).cashIn : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: paid ? SemanticColors.of(context).cashIn : Theme.of(context).colorScheme.outline,
                  width: 1.5,
                ),
              ),
              child: paid
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                participant.name,
                style: AppTypography.bodyMedium.copyWith(
                  decoration: paid ? TextDecoration.lineThrough : null,
                  color: paid
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              '₹${fmt.format(participant.amount)}',
              style: AppTypography.labelMedium.copyWith(
                color: paid ? SemanticColors.of(context).cashIn : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Paid Badge ───────────────────────────────────────────────────────────────

class _PaidBadge extends StatelessWidget {
  const _PaidBadge({required this.paidCount, required this.total});
  final int paidCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    final allPaid = paidCount == total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: allPaid
            ? SemanticColors.of(context).cashIn.withValues(alpha: 0.15)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        allPaid ? '✅ All paid' : '$paidCount/$total paid',
        style: AppTypography.labelSmall.copyWith(
          color: allPaid ? SemanticColors.of(context).cashIn : Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Pay Dialog ───────────────────────────────────────────────────────────────

/// Dialog shown when marking a participant as paid.
/// Lets the user:
///   1. Enter the actual amount received (may differ, e.g. friend gives ₹60 for ₹56 split).
///   2. Decide whether to log it as a Cash In transaction.
class _PayDialog extends StatefulWidget {
  const _PayDialog({
    required this.name,
    required this.expectedAmount,
    required this.fmt,
  });

  final String name;
  final double expectedAmount;
  final NumberFormat fmt;

  @override
  State<_PayDialog> createState() => _PayDialogState();
}

class _PayDialogState extends State<_PayDialog> {
  late final TextEditingController _amountCtrl;
  bool _logAsIncome = true;

  @override
  void initState() {
    super.initState();
    // Pre-fill with the expected split amount, no trailing .00 for whole numbers
    final exp = widget.expectedAmount;
    _amountCtrl = TextEditingController(
      text: exp.truncateToDouble() == exp
          ? exp.toStringAsFixed(0)
          : exp.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.name} paid! 🎉'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Their share: ₹${widget.fmt.format(widget.expectedAmount)}',
            style: AppTypography.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Amount field
          Text(
            'Amount actually received',
            style: AppTypography.labelMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '₹',
                    style: AppTypography.titleLarge.copyWith(
                      color: SemanticColors.of(context).cashIn,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '0',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Log as income toggle
          InkWell(
            onTap: () => setState(() => _logAsIncome = !_logAsIncome),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Checkbox(
                  value: _logAsIncome,
                  onChanged: (v) => setState(() => _logAsIncome = v ?? true),
                  activeColor: SemanticColors.of(context).cashIn,
                ),
                Expanded(
                  child: Text(
                    'Add as Cash In transaction',
                    style: AppTypography.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: SemanticColors.of(context).cashIn),
          onPressed: () {
            final entered = double.tryParse(_amountCtrl.text.trim());
            if (entered == null || entered <= 0) return;
            Navigator.pop(
              context,
              (createTransaction: _logAsIncome, amount: entered),
            );
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

// ─── Edit Sheet Category Picker ───────────────────────────────────────────────

class _EditSheetCategoryPicker extends ConsumerStatefulWidget {
  const _EditSheetCategoryPicker({
    required this.currentCategoryId,
    required this.selected,
    required this.onSelect,
  });

  final String? currentCategoryId;
  final Category? selected;
  final ValueChanged<Category?> onSelect;

  @override
  ConsumerState<_EditSheetCategoryPicker> createState() =>
      _EditSheetCategoryPickerState();
}

class _EditSheetCategoryPickerState
    extends ConsumerState<_EditSheetCategoryPicker> {
  bool _resolved = false;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(expenseCategoriesProvider);

    if (!_resolved && categories.isNotEmpty) {
      _resolved = true;
      if (widget.selected == null) {
        Category? target;
        if (widget.currentCategoryId != null) {
          target = categories
              .where((c) => c.id == widget.currentCategoryId)
              .firstOrNull;
        }
        target ??= categories
            .where((c) => c.name == 'Other Expenses')
            .firstOrNull ?? categories.first;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onSelect(target);
        });
      }
    }

    if (categories.isEmpty) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final isSelected = widget.selected?.id == cat.id;
          return GestureDetector(
            onTap: () {
              if (!isSelected) widget.onSelect(cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.cashOut
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.cashOut
                      : Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    cat.name,
                    style: AppTypography.labelMedium.copyWith(
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
