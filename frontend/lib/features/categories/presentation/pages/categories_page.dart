/// CategoriesPage — manage income and expense categories.
///
/// Features:
/// • Two sections: Income & Expense
/// • Each row: emoji, name, optional "Starter" chip, edit/delete actions
/// • FAB → bottom sheet to add a new category
/// • Long-press → inline edit sheet
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/category.dart';
import '../providers/categories_provider.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCategories = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Categories',
              style: AppTypography.titleLarge.copyWith(
                  color: AppColors.onSurface, fontWeight: FontWeight.w700),
            ),
          ),
          asyncCategories.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text('Failed to load categories',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ),
            ),
            data: (categories) {
              final income = categories.where((c) => c.isIncome).toList();
              final expense = categories.where((c) => c.isExpense).toList();

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xl4 * 2,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _CategorySection(
                      title: 'Income',
                      categories: income,
                      accentColor: AppColors.cashIn,
                      accentContainer: AppColors.cashInContainer,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _CategorySection(
                      title: 'Expense',
                      categories: expense,
                      accentColor: AppColors.cashOut,
                      accentContainer: AppColors.cashOutContainer,
                    ),
                  ]),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Category', style: AppTypography.labelLarge),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryFormSheet(ref: ref),
    );
  }
}

// ─── Section widget ────────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.categories,
    required this.accentColor,
    required this.accentContainer,
  });

  final String title;
  final List<Category> categories;
  final Color accentColor;
  final Color accentContainer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.xs),
          child: Text(
            title.toUpperCase(),
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
        ),
        if (categories.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppSpacing.md),
              boxShadow: AppColors.softShadow,
            ),
            child: Center(
              child: Text(
                'No ${title.toLowerCase()} categories yet.',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppSpacing.md),
              boxShadow: AppColors.softShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < categories.length; i++) ...[
                  _CategoryRow(
                    category: categories[i],
                    accentColor: accentColor,
                    accentContainer: accentContainer,
                  ),
                  if (i < categories.length - 1)
                    const Divider(
                        height: 1,
                        indent: 60,
                        color: AppColors.surfaceContainer),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Category row ──────────────────────────────────────────────────────────────

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({
    required this.category,
    required this.accentColor,
    required this.accentContainer,
  });

  final Category category;
  final Color accentColor;
  final Color accentContainer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onLongPress: () => _showEditSheet(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: [
            // Emoji avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child:
                    Text(category.emoji, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Name + starter chip
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          category.name,
                          style: AppTypography.titleSmall
                              .copyWith(color: AppColors.onSurface),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (category.isDefault) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Starter',
                            style: AppTypography.labelSmall
                                .copyWith(color: AppColors.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (category.hasLimit)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Limit: ₹${category.monthlyLimit!.toStringAsFixed(0)}/mo',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  color: AppColors.onSurfaceVariant,
                  onPressed: () => _showEditSheet(context, ref),
                  visualDensity: VisualDensity.compact,
                ),
                if (!category.isDefault)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: AppColors.error,
                    onPressed: () => _confirmDelete(context, ref),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryFormSheet(ref: ref, existing: category),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete "${category.name}"?',
            style: AppTypography.titleMedium),
        content: Text(
          'This category will be permanently removed. '
          'Any transactions linked to it will remain, but will no longer have a category.',
          style: AppTypography.bodySmall
              .copyWith(color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.onSurfaceVariant)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref
                    .read(categoriesProvider.notifier)
                    .removeCategory(category.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('${category.emoji} ${category.name} deleted'),
                      backgroundColor: AppColors.onSurface,
                    ),
                  );
                }
              } on Failure catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.message),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: Text('Delete',
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.onError)),
          ),
        ],
      ),
    );
  }
}

// ─── Add / Edit bottom sheet ───────────────────────────────────────────────────

class _CategoryFormSheet extends StatefulWidget {
  const _CategoryFormSheet({required this.ref, this.existing});
  final WidgetRef ref;
  final Category? existing;

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final _nameController  = TextEditingController();
  final _emojiController = TextEditingController();
  final _limitController = TextEditingController();
  String _selectedType = 'EXPENSE';
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text  = widget.existing!.name;
      _emojiController.text = widget.existing!.emoji;
      _selectedType = widget.existing!.type;
      if (widget.existing!.hasLimit) {
        _limitController.text =
            widget.existing!.monthlyLimit!.toStringAsFixed(0);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _isEditing ? 'Edit Category' : 'New Category',
              style: AppTypography.titleLarge
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Emoji + Name row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Emoji field
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _emojiController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28),
                    maxLength: 2,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '😀',
                      hintStyle: const TextStyle(fontSize: 28),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Name field
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Category name',
                      hintStyle: AppTypography.bodyMedium
                          .copyWith(color: AppColors.outlineVariant),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Type toggle (hidden when editing — type is locked)
            if (!_isEditing) ...[
              Text('Type', style: AppTypography.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  _TypeChip(
                    label: 'Expense',
                    selected: _selectedType == 'EXPENSE',
                    color: AppColors.cashOut,
                    onTap: () => setState(() => _selectedType = 'EXPENSE'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _TypeChip(
                    label: 'Income',
                    selected: _selectedType == 'INCOME',
                    color: AppColors.cashIn,
                    onTap: () => setState(() => _selectedType = 'INCOME'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Monthly limit (EXPENSE only)
            if (_selectedType == 'EXPENSE') ...[
              Text('Monthly Limit (optional)',
                  style: AppTypography.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _limitController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: false),
                decoration: InputDecoration(
                  hintText: 'e.g. 5000',
                  prefixText: '₹ ',
                  hintStyle: AppTypography.bodyMedium
                      .copyWith(color: AppColors.outlineVariant),
                  helperText: 'Set a spending cap for this category this month.',
                  helperStyle: AppTypography.labelSmall
                      .copyWith(color: AppColors.onSurfaceVariant),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 14),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            if (_selectedType == 'INCOME')
              const SizedBox(height: AppSpacing.lg),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
                        _isEditing ? 'Save Changes' : 'Create Category',
                        style: AppTypography.labelLarge
                            .copyWith(color: AppColors.onPrimary),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name  = _nameController.text.trim();
    final emoji = _emojiController.text.trim();
    if (name.isEmpty || emoji.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both name and emoji.')),
      );
      return;
    }

    // Parse optional monthly limit
    double? monthlyLimit;
    final limitText = _limitController.text.trim();
    if (limitText.isNotEmpty) {
      monthlyLimit = double.tryParse(limitText);
      if (monthlyLimit == null || monthlyLimit < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Monthly limit must be a valid positive number.')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await widget.ref.read(categoriesProvider.notifier).updateCategory(
              widget.existing!.id,
              name: name,
              emoji: emoji,
              // Send null to clear limit if field was cleared; send value if set.
              monthlyLimit: limitText.isEmpty ? null : monthlyLimit,
            );
      } else {
        await widget.ref.read(categoriesProvider.notifier).addCategory(
              name: name,
              emoji: emoji,
              type: _selectedType,
              monthlyLimit: monthlyLimit,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } on Failure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
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
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? color : AppColors.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: selected ? color : AppColors.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
