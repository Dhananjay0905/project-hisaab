/// RecurringPage — manage recurring transactions.
///
/// Sections:
/// • Active recurring items (sorted by nextDueDate)
/// • Paused recurring items
///
/// Interactions:
/// • FAB → bottom sheet to create a new recurring item
/// • Swipe left → delete
/// • Tap card → edit sheet
/// • Toggle button on card → pause / resume
library;

import 'package:flutter/material.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../../core/error/failures.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../domain/entities/recurring_transaction.dart';
import '../providers/recurring_provider.dart';

class RecurringPage extends ConsumerStatefulWidget {
  const RecurringPage({super.key});

  @override
  ConsumerState<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends ConsumerState<RecurringPage> {
  Future<void> _handleRefresh() async {
    await ref.read(recurringProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final asyncRecurring = ref.watch(recurringProvider);

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
              title: Text(
                'Recurring',
                style: AppTypography.titleLarge
                    .copyWith(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700),
              ),
            ),
            asyncRecurring.when(
              loading: () => const RecurringSkeleton(),
              error: (e, _) => AppErrorWidget.sliver(
                title: 'Failed to load recurring transactions',
                message: e.toString().replaceAll('Exception:', '').trim(),
                onRetry: () => ref.invalidate(recurringProvider),
              ),
              data: (items) {
                final active =
                    items.where((i) => i.isActive).toList()
                      ..sort((a, b) =>
                          a.nextDueDate.compareTo(b.nextDueDate));
                final paused = items.where((i) => !i.isActive).toList();

                if (items.isEmpty) {
                  return SliverFillRemaining(
                    child: _EmptyState(
                      onAdd: () => _showFormSheet(context, ref),
                    ),
                  );
                }

                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    MediaQuery.of(context).padding.bottom + AppSpacing.lg,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (active.isNotEmpty) ...[
                        _SectionHeader(label: 'Active'),
                        const SizedBox(height: AppSpacing.xs),
                        ...active.map((i) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _RecurringCard(item: i),
                            )),
                      ],
                      if (paused.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        _SectionHeader(label: 'Paused'),
                        const SizedBox(height: AppSpacing.xs),
                        ...paused.map((i) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _RecurringCard(item: i),
                            )),
                      ],
                    ]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormSheet(context, ref),
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        foregroundColor: Theme.of(context).colorScheme.onTertiary,
        icon: const Icon(Icons.repeat_rounded),
        label: Text('Add Recurring', style: AppTypography.labelLarge),
      ),
    );
  }

  void _showFormSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecurringFormSheet(ref: ref),
    );
  }
}

// ─── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: 2),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─── Recurring card ────────────────────────────────────────────────────────────

class _RecurringCard extends ConsumerWidget {
  const _RecurringCard({required this.item});
  final RecurringTransaction item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = item.isExpense;
    final sem = SemanticColors.of(context);
    final accentColor = isExpense ? sem.cashOut : sem.cashIn;
    final accentContainer = isExpense ? sem.cashOutSurface : sem.cashInSurface;
    final fmt = NumberFormat('#,##0', 'en_IN');
    final dateFmt = DateFormat('d MMM');
    final isDue = item.isDueToday && item.isActive;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
        child: Icon(Icons.delete_outline_rounded,
            color: Theme.of(context).colorScheme.error, size: 24),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) async {
        try {
          await ref.read(recurringProvider.notifier).remove(item.id);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Failed to delete.'),
                backgroundColor: Theme.of(context).colorScheme.error));
          }
        }
      },
      child: GestureDetector(
        onTap: () => _showEditSheet(context, ref),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppSpacing.md),
            boxShadow: Theme.of(context).brightness == Brightness.dark
                ? AppColorsDark.softShadow
                : AppColors.softShadow,
            border: isDue
                ? Border.all(
                    color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.4), width: 1.5)
                : null,
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Emoji avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    item.category?.emoji ?? (isExpense ? '💸' : '💰'),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            style: AppTypography.titleSmall
                                .copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isDue) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.tertiaryContainer
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Due today',
                                style: AppTypography.labelSmall.copyWith(
                                    color: Theme.of(context).colorScheme.tertiary,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          item.category?.name ?? 'Uncategorised',
                          style: AppTypography.bodySmall
                              .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        Text(' · ',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.outlineVariant, fontSize: 12)),
                        Text(
                          item.frequencyLabel,
                          style: AppTypography.bodySmall
                              .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        if (!item.isActive) ...[
                          Text(' · ',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.outlineVariant,
                                  fontSize: 12)),
                          Text('Paused',
                              style: AppTypography.bodySmall
                                  .copyWith(color: Theme.of(context).colorScheme.outline)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Next: ${dateFmt.format(item.nextDueDate)}',
                      style: AppTypography.labelSmall
                          .copyWith(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                  ],
                ),
              ),
              // Amount + toggle
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${fmt.format(item.amount)}',
                    style: AppTypography.titleSmall.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  GestureDetector(
                    onTap: () => ref
                        .read(recurringProvider.notifier)
                        .toggle(item.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.isActive
                            ? Theme.of(context).colorScheme.surfaceContainerLow
                            : SemanticColors.of(context).cashInSurface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.isActive ? 'Pause' : 'Resume',
                        style: AppTypography.labelSmall.copyWith(
                          color: item.isActive
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : SemanticColors.of(context).cashIn,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Cancel "${item.title}"?',
                style: AppTypography.titleMedium),
            content: Text(
              'This recurring transaction will be permanently removed.',
              style: AppTypography.bodySmall
                  .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Keep',
                    style: AppTypography.labelLarge
                        .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
              FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Delete',
                    style: AppTypography.labelLarge
                        .copyWith(color: Theme.of(context).colorScheme.onError)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecurringFormSheet(ref: ref, existing: item),
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(Icons.repeat_rounded,
              size: 36, color: Theme.of(context).colorScheme.tertiary),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('No recurring transactions',
            style: AppTypography.titleMedium
                .copyWith(color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Add subscriptions, salaries,\nor any regular payment.',
          style:
              AppTypography.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          onPressed: onAdd,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          ),
          icon: Icon(Icons.add_rounded, color: Theme.of(context).colorScheme.onTertiary),
          label: Text('Add Recurring',
              style: AppTypography.labelLarge
                  .copyWith(color: Theme.of(context).colorScheme.onTertiary)),
        ),
      ],
    );
  }
}

// ─── Add / Edit bottom sheet ───────────────────────────────────────────────────

class _RecurringFormSheet extends ConsumerStatefulWidget {
  const _RecurringFormSheet({required this.ref, this.existing});
  final WidgetRef ref;
  final RecurringTransaction? existing;

  @override
  ConsumerState<_RecurringFormSheet> createState() =>
      _RecurringFormSheetState();
}

class _RecurringFormSheetState
    extends ConsumerState<_RecurringFormSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _type = 'EXPENSE';
  String _frequency = 'MONTHLY';
  DateTime _startDate = DateTime.now();
  Category? _selectedCategory;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _amountCtrl.text = e.amount.toStringAsFixed(0);
      _type = e.type;
      _frequency = e.frequency;
      _startDate = e.startDate;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final filteredCats =
        categories.where((c) => c.type == _type).toList();

    // Resolve existing category on load
    if (_isEditing && _selectedCategory == null) {
      final e = widget.existing!;
      if (e.category != null) {
        try {
          _selectedCategory = categories
              .firstWhere((c) => c.id == e.category!.id);
        } catch (_) {}
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: AppSpacing.md),
              Text(
                _isEditing ? 'Edit Recurring' : 'New Recurring',
                style: AppTypography.titleLarge
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Type toggle
              if (!_isEditing) ...[
                Row(
                  children: [
                    _TypeChip(
                      label: 'Expense',
                      selected: _type == 'EXPENSE',
                      color: SemanticColors.of(context).cashOut,
                      onTap: () => setState(() {
                        _type = 'EXPENSE';
                        _selectedCategory = null;
                      }),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _TypeChip(
                      label: 'Income',
                      selected: _type == 'INCOME',
                      color: SemanticColors.of(context).cashIn,
                      onTap: () => setState(() {
                        _type = 'INCOME';
                        _selectedCategory = null;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Title
              TextField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration('Title (e.g. Netflix, Salary)'),
              ),
              const SizedBox(height: AppSpacing.md),

              // Amount
              TextField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration('Amount (₹)'),
              ),
              const SizedBox(height: AppSpacing.md),

              // Category dropdown
              Text('Category', style: AppTypography.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<Category>(
                initialValue: _selectedCategory,
                hint: Text('Select category',
                    style: AppTypography.bodyMedium
                        .copyWith(color: Theme.of(context).colorScheme.outlineVariant)),
                items: filteredCats
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text('${c.emoji} ${c.name}',
                              style: AppTypography.bodyMedium),
                        ))
                    .toList(),
                onChanged: (c) => setState(() => _selectedCategory = c),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 14),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Frequency
              Text('Frequency', style: AppTypography.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                children: ['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY']
                    .map((f) => ChoiceChip(
                          label: Text(_freqLabel(f)),
                          selected: _frequency == f,
                          selectedColor:
                              Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.15),
                          labelStyle: AppTypography.labelMedium.copyWith(
                            color: _frequency == f
                                ? Theme.of(context).colorScheme.tertiary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          onSelected: (_) =>
                              setState(() => _frequency = f),
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.md),

              // Start date
              Text('Start Date', style: AppTypography.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        DateFormat('d MMMM yyyy').format(_startDate),
                        style: AppTypography.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Submit and Delete
              Row(
                children: [
                  if (_isEditing) ...[
                    IconButton(
                      onPressed: _saving ? null : _delete,
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                        foregroundColor: Theme.of(context).colorScheme.error,
                        padding: const EdgeInsets.all(14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.tertiary,
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _isEditing
                                  ? 'Save Changes'
                                  : 'Create Recurring',
                              style: AppTypography.labelLarge
                                  .copyWith(color: Theme.of(context).colorScheme.onTertiary),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodyMedium
            .copyWith(color: Theme.of(context).colorScheme.outlineVariant),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 14),
      );

  String _freqLabel(String f) {
    switch (f) {
      case 'DAILY':
        return 'Daily';
      case 'WEEKLY':
        return 'Weekly';
      case 'MONTHLY':
        return 'Monthly';
      case 'YEARLY':
        return 'Yearly';
      default:
        return f;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final amountStr = _amountCtrl.text.trim();
    if (title.isEmpty || amountStr.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fill in all fields and select a category.')));
      return;
    }
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid amount.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final notifier = widget.ref.read(recurringProvider.notifier);
      if (_isEditing) {
        await notifier.edit(
          widget.existing!.id,
          title: title,
          amount: amount,
          categoryId: _selectedCategory!.id,
          frequency: _frequency,
          startDate: _startDate,
        );
      } else {
        await notifier.add(
          title: title,
          amount: amount,
          type: _type,
          categoryId: _selectedCategory!.id,
          frequency: _frequency,
          startDate: _startDate,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on Failure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Delete "${widget.existing!.title}"?',
                style: AppTypography.titleMedium),
            content: Text(
              'This recurring transaction will be permanently removed.',
              style: AppTypography.bodySmall
                  .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Keep',
                    style: AppTypography.labelLarge
                        .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
              FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Delete',
                    style: AppTypography.labelLarge
                        .copyWith(color: Theme.of(context).colorScheme.onError)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _saving = true);
    try {
      await widget.ref.read(recurringProvider.notifier).remove(widget.existing!.id);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Failed to delete.'),
            backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─── Type chip ─────────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? color : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: selected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
