/// DueRecurringDialog — bottom sheet shown for each recurring item due today.
///
/// Behaviour:
/// • "Add Now" → confirms the transaction (creates it + advances nextDueDate)
/// • "Later"   → dismisses; will re-appear on next app open
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/entities/recurring_transaction.dart';
import '../providers/recurring_provider.dart';
import '../../../../../../../../../../core/theme/semantic_colors.dart';

class DueRecurringDialog extends ConsumerStatefulWidget {
  const DueRecurringDialog({super.key, required this.item});
  final RecurringTransaction item;

  @override
  ConsumerState<DueRecurringDialog> createState() =>
      _DueRecurringDialogState();
}

class _DueRecurringDialogState extends ConsumerState<DueRecurringDialog> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isExpense = item.isExpense;
    final accentColor = isExpense ? SemanticColors.of(context).cashOut : SemanticColors.of(context).cashIn;
    final accentContainer =
        isExpense ? SemanticColors.of(context).cashOutContainer : SemanticColors.of(context).cashInContainer;
    final fmt = NumberFormat('#,##0.00', 'en_IN');

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Icon + category
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: accentContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                item.category?.emoji ?? (isExpense ? '💸' : '💰'),
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Title
          Text(
            item.title,
            style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),

          // Amount + frequency
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '₹${fmt.format(item.amount)}',
                  style: AppTypography.titleMedium.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.frequencyLabel,
                  style: AppTypography.labelMedium
                      .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Message
          Text(
            'Your recurring ${isExpense ? 'expense' : 'income'} is due today.\nWould you like to add it now?',
            style: AppTypography.bodyMedium
                .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _loading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Later',
                      style: AppTypography.labelLarge
                          .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: _loading ? null : _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Add Now',
                          style: AppTypography.labelLarge
                              .copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    setState(() => _loading = true);
    try {
      await ref.read(recurringProvider.notifier).confirm(widget.item.id);
      if (mounted) {
        Navigator.of(context).pop(true); // true = confirmed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.item.title} added to transactions!'),
            backgroundColor: SemanticColors.of(context).cashIn,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to add transaction. Try again.'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
