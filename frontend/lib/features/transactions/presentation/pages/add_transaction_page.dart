/// AddTransactionPage — slide-up sheet modal for creating OR editing a transaction.
///
/// Design:
///  - Full-screen modal with top drag handle (iOS sheet feel)
///  - INCOME / EXPENSE toggle at the top — changes accent color
///  - Amount display big & centered with currency symbol
///  - Category picker (horizontal scroll chips from [categoriesProvider])
///  - Title + optional Note fields
///  - Date picker (defaults to today)
///  - When [editTransaction] is supplied the page is in edit mode:
///    pre-fills all fields, title becomes "Edit Transaction",
///    Save does a PATCH, and a Delete button appears.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/upi_transaction_data.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/providers/budget_check_provider.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../analytics/presentation/providers/analytics_provider.dart';
import '../../domain/entities/transaction.dart';
import '../../presentation/providers/transactions_provider.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  const AddTransactionPage({
    super.key,
    this.initialType = 'EXPENSE',
    this.initialDate,
    this.editTransaction,
    this.upiData,
  });
  final String initialType;
  final DateTime? initialDate;
  /// When provided, the page opens in edit mode pre-filled with these values.
  final Transaction? editTransaction;
  /// When provided, the page opens with OCR-parsed UPI transaction data pre-filled.
  final UpiTransactionData? upiData;

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage>
    with SingleTickerProviderStateMixin {
  // Type toggle
  late String _type;

  // Controllers
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  // State
  Category? _selectedCategory;
  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;
  bool _excludeFromAnalytics = false;
  String? _errorMessage;
  bool _showUpiBanner = false;

  late AnimationController _typeAnimController;
  late Animation<Color?> _accentAnimation;

  bool get _isEditing => widget.editTransaction != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.editTransaction;
    _type = edit?.type ?? widget.initialType;
    _selectedDate = edit?.date.toLocal() ?? widget.initialDate ?? DateTime.now();
    if (edit != null) {
      _amountController.text = edit.amount.toStringAsFixed(
          edit.amount.truncateToDouble() == edit.amount ? 0 : 2);
      _titleController.text  = edit.title;
      _noteController.text   = edit.note ?? '';
      _excludeFromAnalytics  = edit.excludeFromAnalytics;
      final local = edit.date.toLocal();
      if (local.hour != 0 || local.minute != 0) {
        _selectedTime = TimeOfDay(hour: local.hour, minute: local.minute);
      }
    }
    _typeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _accentAnimation = ColorTween(
      begin: Colors.red,   // placeholder — overwritten in didChangeDependencies()
      end: Colors.green,   // placeholder — overwritten in didChangeDependencies()
    ).animate(CurvedAnimation(parent: _typeAnimController, curve: Curves.easeInOut));
    if (_type == 'INCOME') _typeAnimController.forward();
    _amountController.addListener(() => setState(() {}));

    // Pre-fill from UPI OCR data (takes lower priority than editTransaction)
    final upi = widget.upiData;
    if (upi != null && !_isEditing) {
      if (upi.isIncome) {
        _type = 'INCOME';
        _typeAnimController.forward();
      }
      if (upi.amount != null) {
        _amountController.text = upi.amount!.truncateToDouble() == upi.amount!
            ? upi.amount!.toStringAsFixed(0)
            : upi.amount!.toStringAsFixed(2);
      }
      if (upi.date != null) _selectedDate = upi.date!;
      if (upi.time != null) _selectedTime = upi.time;
      // Title and note are intentionally NOT pre-filled — user writes their own.
      _showUpiBanner = upi.hasAnyData;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(categorySpendProvider((null, null)).future).ignore();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-seed the tween whenever the theme changes (e.g. colorblind toggle).
    final sem = SemanticColors.of(context);
    _accentAnimation = ColorTween(
      begin: sem.cashOut,
      end: sem.cashIn,
    ).animate(CurvedAnimation(parent: _typeAnimController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    _typeAnimController.dispose();
    super.dispose();
  }

  void _toggleType(String newType) {
    if (newType == _type) return;
    setState(() {
      _type = newType;
      _selectedCategory = null;
      if (newType == 'INCOME') {
        _typeAnimController.forward();
      } else {
        _typeAnimController.reverse();
      }
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        // Force 12-hour AM/PM format regardless of device locale
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    final amountStr = _amountController.text.trim();
    final title = _titleController.text.trim();

    if (amountStr.isEmpty || double.tryParse(amountStr) == null) {
      setState(() => _errorMessage = 'Please enter a valid amount.');
      return;
    }
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Please enter a title.');
      return;
    }

    setState(() { _isSubmitting = true; _errorMessage = null; });

    try {
      final finalDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime?.hour ?? DateTime.now().hour,
        _selectedTime?.minute ?? DateTime.now().minute,
      ).toUtc();
      final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

      if (_isEditing) {
        await ref.read(transactionsProvider.notifier).updateTransaction(
              widget.editTransaction!.id,
              title: title,
              amount: double.parse(amountStr),
              type: _type,
              date: finalDate,
              note: note,
              categoryId: _selectedCategory?.id,
              excludeFromAnalytics: _excludeFromAnalytics,
            );
      } else {
        await ref.read(transactionsProvider.notifier).addTransaction(
              title: title,
              amount: double.parse(amountStr),
              type: _type,
              date: finalDate,
              note: note,
              categoryId: _selectedCategory?.id,
              excludeFromAnalytics: _excludeFromAnalytics,
            );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  Future<void> _deleteTransaction() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text(
            'Are you sure you want to delete "${widget.editTransaction!.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(transactionsProvider.notifier)
          .removeTransaction(widget.editTransaction!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(
      _type == 'INCOME' ? incomeCategoriesProvider : expenseCategoriesProvider,
    );

    // Pre-select category:
    // - Edit mode: match the transaction's category by ID
    // - Create mode: fall back to "Other Income" / "Other Expenses"
    if (_selectedCategory == null && categories.isNotEmpty) {
      final editCatId = widget.editTransaction?.categoryId;
      Category? target;
      if (editCatId != null) {
        target = categories.where((c) => c.id == editCatId).firstOrNull;
      }
      target ??= () {
        final name = _type == 'INCOME' ? 'Other Income' : 'Other Expenses';
        return categories.where((c) => c.name == name).firstOrNull;
      }();
      if (target != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedCategory == null) {
            setState(() => _selectedCategory = target);
          }
        });
      }
    }

    return AnimatedBuilder(
      animation: _accentAnimation,
      builder: (context, _) {
        final accentColor = _accentAnimation.value ?? SemanticColors.of(context).cashOut;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: true,
              child: Column(
                children: [
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                    child: Row(
                      children: [
                        Text(
                          _isEditing ? 'Edit Transaction' : 'Add Transaction',
                          style: AppTypography.titleMedium
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        if (_isEditing)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: _isSubmitting ? null : _deleteTransaction,
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                              foregroundColor: Theme.of(context).colorScheme.error,
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        if (_isEditing) const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // INCOME / EXPENSE toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                    child: _TypeToggle(
                      activeType: _type,
                      onToggle: _toggleType,
                    ),
                  ),

                  // UPI auto-fill banner
                  if (_showUpiBanner)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                      child: _UpiBanner(
                        onDismiss: () => setState(() => _showUpiBanner = false),
                      ),
                    ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: AppSpacing.lg,
                        right: AppSpacing.lg,
                        top: AppSpacing.md,
                        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Amount field
                          _AmountField(
                            controller: _amountController,
                            accentColor: accentColor,
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Category picker
                          if (categories.isNotEmpty) ...[
                            Text('Category',
                                style: AppTypography.labelMedium.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            const SizedBox(height: AppSpacing.sm),
                            _CategoryPicker(
                              categories: categories,
                              selected: _selectedCategory,
                              accentColor: accentColor,
                              onSelect: (cat) =>
                                  setState(() => _selectedCategory = cat),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text('You can manage your categories from the Settings page.',
                                style: AppTypography.bodySmall.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
                            const SizedBox(height: AppSpacing.sm),
                            // Budget warning banner
                            _BudgetWarningBanner(
                              categoryId: _type == 'EXPENSE'
                                  ? _selectedCategory?.id
                                  : null,
                              amount: double.tryParse(
                                      _amountController.text.trim()) ??
                                  0.0,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],

                          // Title field
                          _FormField(
                            controller: _titleController,
                            label: 'Title',
                            hint: 'e.g. Groceries, Salary',
                            icon: Icons.title_rounded,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Note field
                          _FormField(
                            controller: _noteController,
                            label: 'Note (optional)',
                            hint: 'Add a memo…',
                            icon: Icons.notes_rounded,
                            minLines: 1,
                            maxLines: 3,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Date picker
                          _DatePicker(
                            date: _selectedDate,
                            onTap: _pickDate,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Time picker (optional)
                          _TimePicker(
                            time: _selectedTime,
                            onTap: _pickTime,
                            onClear: () => setState(() => _selectedTime = null),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // ── Exclude from analytics toggle ────────────────────
                          Builder(builder: (context) {
                            final catExcluded =
                                _selectedCategory?.excludeFromAnalytics ?? false;
                            // If the category is already excluded, lock the
                            // toggle ON — the category-level flag covers it.
                            final effectiveValue =
                                catExcluded || _excludeFromAnalytics;
                            return Container(
                              decoration: BoxDecoration(
                                color: catExcluded
                                    ? Theme.of(context).colorScheme.surfaceContainerLow
                                        .withValues(alpha: 0.5)
                                    : Theme.of(context).colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: Theme.of(context).colorScheme.outlineVariant
                                        .withValues(alpha: 0.5)),
                              ),
                              child: SwitchListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md, vertical: 2),
                                title: Text(
                                  'Exclude from analytics',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: catExcluded
                                        ? Theme.of(context).colorScheme.onSurfaceVariant
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  catExcluded
                                      ? 'Controlled by the "${_selectedCategory!.name}" category setting.'
                                      : 'This transaction won\'t count in charts or totals.',
                                  style: AppTypography.labelSmall.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                                value: effectiveValue,
                                activeThumbColor:
                                    catExcluded ? Theme.of(context).colorScheme.outlineVariant : accentColor,
                                // null disables the switch widget
                                onChanged: catExcluded
                                    ? null
                                    : (v) => setState(
                                        () => _excludeFromAnalytics = v),
                              ),
                            );
                          }),
                          const SizedBox(height: AppSpacing.lg),

                          // Error message
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: Text(
                                _errorMessage!,
                                style: AppTypography.bodySmall
                                    .copyWith(color: Theme.of(context).colorScheme.error),
                              ),
                            ),

                          // Submit button
                          SizedBox(
                            width: double.infinity,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    accentColor,
                                    accentColor.withValues(alpha: 0.75),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: FilledButton(
                                onPressed: _isSubmitting ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      )
                                    : Text(
                                        _type == 'INCOME'
                                            ? 'Add Income'
                                            : 'Add Expense',
                                        style: AppTypography.labelLarge.copyWith(
                                          color: ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Budget Warning Banner ─────────────────────────────────────────────────────

class _BudgetWarningBanner extends ConsumerWidget {
  const _BudgetWarningBanner({required this.categoryId, required this.amount});
  final String? categoryId;
  final double amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (categoryId == null || amount <= 0) return const SizedBox.shrink();

    // Synchronous read — no loading/error states, result is instant.
    final result = ref.watch(budgetCheckProvider((categoryId, amount)));

    if (result == null || !result.shouldWarn) return const SizedBox.shrink();

    final isExceeded = result.status == BudgetStatus.exceeded;
    final color = isExceeded
        ? const Color(0xFFE53935)
        : const Color(0xFFE65100);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.message,
                style: AppTypography.bodySmall.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Type Toggle ──────────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.activeType, required this.onToggle});
  final String activeType;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _TypeOption(
            label: 'Expense',
            emoji: '📤',
            isActive: activeType == 'EXPENSE',
            activeColor: sem.cashOut,
            onTap: () => onToggle('EXPENSE'),
          ),
          _TypeOption(
            label: 'Income',
            emoji: '📥',
            isActive: activeType == 'INCOME',
            activeColor: sem.cashIn,
            onTap: () => onToggle('INCOME'),
          ),
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.label,
    required this.emoji,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: isActive
                      ? (ThemeData.estimateBrightnessForColor(activeColor) == Brightness.dark
                          ? Colors.white
                          : Colors.black87)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Amount Field ─────────────────────────────────────────────────────────────

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.accentColor,
  });

  final TextEditingController controller;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount',
            style: AppTypography.labelSmall.copyWith(color: accentColor),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '₹',
                style: AppTypography.displaySmall.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  style: AppTypography.displaySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    filled: false,
                    hintText: '0.00',
                    hintStyle: AppTypography.displaySmall.copyWith(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      fontWeight: FontWeight.w300,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Category Picker ──────────────────────────────────────────────────────────

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.selected,
    required this.accentColor,
    required this.onSelect,
  });

  final List<Category> categories;
  final Category? selected;
  final Color accentColor;
  final ValueChanged<Category?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final isSelected = selected?.id == cat.id;
          return GestureDetector(
            onTap: () {
              if (!isSelected) onSelect(cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? accentColor
                      : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
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
                          ? (ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
                              ? Colors.white
                              : Colors.black87)
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
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

// ─── Form Field ───────────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTypography.labelMedium
                .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 1.5),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

// ─── Date Picker ──────────────────────────────────────────────────────────────

class _DatePicker extends StatelessWidget {
  const _DatePicker({required this.date, required this.onTap});
  final DateTime date;
  final VoidCallback onTap;

  String _format(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final local = d.toLocal();
    final target = DateTime(local.year, local.month, local.day);
    if (target == today) return 'Today';
    if (target == yesterday) return 'Yesterday';
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${local.day} ${months[local.month]} ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 20,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              _format(date),
              style: AppTypography.bodyMedium
                  .copyWith(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.outlineVariant),
          ],
        ),
      ),
    );
  }
}

// ─── Time Picker ──────────────────────────────────────────────────────────────

class _TimePicker extends StatelessWidget {
  const _TimePicker({required this.time, required this.onTap, required this.onClear});
  final TimeOfDay? time;
  final VoidCallback onTap;
  final VoidCallback onClear;

  String _format(TimeOfDay? t) {
    if (t == null) return 'Add time (optional)';
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final hasTime = time != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 20,
                color: hasTime ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(width: 10),
            Text(
              _format(time),
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                color: hasTime ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            const Spacer(),
            if (hasTime)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded, size: 18,
                    color: Theme.of(context).colorScheme.outlineVariant),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.outlineVariant),
          ],
        ),
      ),
    );
  }
}

// ─── UPI Auto-fill Banner ─────────────────────────────────────────────────────

/// Shown when the Add Transaction modal is opened from a UPI screenshot share.
/// Lets the user know the fields were auto-filled and they should verify them.
class _UpiBanner extends StatelessWidget {
  const _UpiBanner({required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    const bannerColor = Color(0xFF00796B); // teal-700
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: bannerColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bannerColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filled from UPI screenshot',
                    style: AppTypography.labelSmall.copyWith(
                      color: bannerColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Please verify the details before saving.',
                    style: AppTypography.labelSmall.copyWith(
                      color: bannerColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close_rounded, size: 16, color: bannerColor),
            ),
          ],
        ),
      ),
    );
  }
}
