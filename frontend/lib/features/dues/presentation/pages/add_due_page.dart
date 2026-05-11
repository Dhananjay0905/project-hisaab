/// AddDuePage — slide-up sheet for creating or editing a due entry.
///
/// Design mirrors AddTransactionPage — I_OWE/THEY_OWE toggle changes accent.
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
import '../../domain/entities/due.dart';
import '../providers/dues_provider.dart';

class AddDuePage extends ConsumerStatefulWidget {
  const AddDuePage({super.key, this.existing, this.initialType = 'I_OWE'});

  /// If provided, the page opens in edit mode pre-filled with [existing].
  final Due? existing;

  /// The type to pre-select when creating a new due.
  /// Ignored when [existing] is set (edit mode uses existing.type).
  final String initialType;

  @override
  ConsumerState<AddDuePage> createState() => _AddDuePageState();
}

class _AddDuePageState extends ConsumerState<AddDuePage>
    with SingleTickerProviderStateMixin {
  late String _type;

  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _personNameController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime? _selectedDueDate;
  bool _isSubmitting = false;
  String? _errorMessage;
  Category? _selectedCategory;

  late AnimationController _typeAnimController;
  late Animation<Color?> _accentAnimation;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? widget.initialType;
    _amountController.text = e != null ? e.amount.toStringAsFixed(0) : '';
    _titleController.text = e?.title ?? '';
    _personNameController.text = e?.personName ?? '';
    _noteController.text = e?.note ?? '';
    _selectedDueDate = e?.dueDate;
    // category is resolved after first build when categories load

    _typeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _accentAnimation = ColorTween(
      begin: AppColors.cashOut, // I_OWE = red
      end: AppColors.cashIn,   // THEY_OWE = green
    ).animate(CurvedAnimation(parent: _typeAnimController, curve: Curves.easeInOut));

    if (_type == 'THEY_OWE') _typeAnimController.forward();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _personNameController.dispose();
    _noteController.dispose();
    _typeAnimController.dispose();
    super.dispose();
  }

  void _toggleType(String newType) {
    if (newType == _type) return;
    setState(() {
      _type = newType;
      _selectedCategory = null; // clear category when type changes
    });
    if (newType == 'THEY_OWE') {
      _typeAnimController.forward();
    } else {
      _typeAnimController.reverse();
    }
    HapticFeedback.selectionClick();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _selectedDueDate = picked);
  }

  Future<void> _submit() async {
    final amountStr = _amountController.text.trim();
    final title = _titleController.text.trim();
    final personName = _personNameController.text.trim();

    if (amountStr.isEmpty || double.tryParse(amountStr) == null) {
      setState(() => _errorMessage = 'Please enter a valid amount.');
      return;
    }
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Please enter a title (what is it for?).');
      return;
    }
    if (personName.isEmpty) {
      setState(() => _errorMessage = 'Please enter the person\'s name.');
      return;
    }
    if (_selectedCategory == null) {
      setState(() => _errorMessage = 'Please select a category.');
      return;
    }

    setState(() { _isSubmitting = true; _errorMessage = null; });

    try {
      final note = _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim();

      if (_isEditing) {
        await ref.read(duesProvider.notifier).updateDue(
              widget.existing!.id,
              title: title,
              personName: personName,
              amount: double.parse(amountStr),
              type: _type,
              note: note,
              dueDate: _selectedDueDate,
              categoryId: _selectedCategory?.id,
            );
      } else {
        await ref.read(duesProvider.notifier).addDue(
              title: title,
              personName: personName,
              amount: double.parse(amountStr),
              type: _type,
              note: note,
              dueDate: _selectedDueDate,
              categoryId: _selectedCategory?.id,
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _accentAnimation,
      builder: (context, _) {
        final accent = _accentAnimation.value ?? AppColors.cashOut;
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────────────────────────
              SliverAppBar(
                backgroundColor: Theme.of(context).colorScheme.surface,
                surfaceTintColor: Colors.transparent,
                pinned: true,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                title: Text(
                  _isEditing ? 'Edit Due' : 'New Due',
                  style: AppTypography.titleLarge,
                ),
                centerTitle: true,
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg,
                    MediaQuery.of(context).padding.bottom + AppSpacing.xl2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Type toggle ─────────────────────────────────────────
                      _TypeToggle(
                        selected: _type,
                        onChanged: _toggleType,
                        iOweColor: SemanticColors.of(context).cashOut,
                        theyOweColor: SemanticColors.of(context).cashIn,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ── Amount ──────────────────────────────────────────────
                      _SectionLabel('Amount'),
                      const SizedBox(height: AppSpacing.xs),
                      _AmountField(
                        controller: _amountController,
                        accentColor: accent,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Category ─────────────────────────────────────────────
                      _SectionLabel('Category'),
                      const SizedBox(height: AppSpacing.sm),
                      _DueCategoryRow(
                        type: _type,
                        selected: _selectedCategory,
                        existingCategoryId: widget.existing?.categoryId,
                        onSelect: (cat) => setState(() => _selectedCategory = cat),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Person name ─────────────────────────────────────────
                      _SectionLabel('Person Name'),
                      const SizedBox(height: AppSpacing.xs),
                      _InputField(
                        controller: _personNameController,
                        hint: 'e.g. Rahul, Mom, John',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Title ───────────────────────────────────────────────
                      _SectionLabel('What is it for?'),
                      const SizedBox(height: AppSpacing.xs),
                      _InputField(
                        controller: _titleController,
                        hint: 'e.g. Dinner split, Rent advance',
                        icon: Icons.notes_rounded,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Note ────────────────────────────────────────────────
                      _SectionLabel('Note (optional)'),
                      const SizedBox(height: AppSpacing.xs),
                      _InputField(
                        controller: _noteController,
                        hint: 'Any extra details…',
                        icon: Icons.chat_bubble_outline_rounded,
                        maxLines: 2,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Due date ────────────────────────────────────────────
                      _SectionLabel('Due Date (optional)'),
                      const SizedBox(height: AppSpacing.xs),
                      _DatePickerTile(
                        selectedDate: _selectedDueDate,
                        onTap: _pickDueDate,
                        onClear: () => setState(() => _selectedDueDate = null),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ── Error ────────────────────────────────────────────────
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: SemanticColors.of(context).cashOut.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  color: SemanticColors.of(context).cashOut, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: AppTypography.bodySmall
                                      .copyWith(color: SemanticColors.of(context).cashOut),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      // ── Save button ─────────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  _isEditing ? 'Save Changes' : 'Add Due',
                                  style: AppTypography.labelLarge
                                      .copyWith(color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({
    required this.selected,
    required this.onChanged,
    required this.iOweColor,
    required this.theyOweColor,
  });

  final String selected;
  final ValueChanged<String> onChanged;
  final Color iOweColor;
  final Color theyOweColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _ToggleOption(
            label: '😬 I Owe',
            isSelected: selected == 'I_OWE',
            color: iOweColor,
            onTap: () => onChanged('I_OWE'),
          ),
          _ToggleOption(
            label: '🤝 They Owe Me',
            isSelected: selected == 'THEY_OWE',
            color: theyOweColor,
            onTap: () => onChanged('THEY_OWE'),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.labelLarge.copyWith(
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.labelMedium.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, required this.accentColor});
  final TextEditingController controller;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '₹',
              style: AppTypography.headlineMedium.copyWith(color: accentColor),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '0',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.selectedDate,
    required this.onTap,
    required this.onClear,
  });

  final DateTime? selectedDate;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasDate = selectedDate != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 20,
              color: hasDate
                  ? AppColors.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasDate
                    ? DateFormat('MMM d, yyyy').format(selectedDate!)
                    : 'No deadline set',
                style: AppTypography.bodyMedium.copyWith(
                  color: hasDate
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (hasDate)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Due Category Row (horizontal chips) ─────────────────────────────────────

class _DueCategoryRow extends ConsumerStatefulWidget {
  const _DueCategoryRow({
    required this.type,
    required this.selected,
    required this.onSelect,
    this.existingCategoryId,
  });

  /// 'I_OWE' → EXPENSE categories (red accent)
  /// 'THEY_OWE' → INCOME categories (green accent)
  final String type;
  final Category? selected;
  final ValueChanged<Category?> onSelect;
  final String? existingCategoryId;

  @override
  ConsumerState<_DueCategoryRow> createState() => _DueCategoryRowState();
}

class _DueCategoryRowState extends ConsumerState<_DueCategoryRow> {
  bool _defaultSet = false;

  @override
  Widget build(BuildContext context) {
    final catType = widget.type == 'I_OWE' ? 'EXPENSE' : 'INCOME';
    final categories = ref.watch(
      catType == 'EXPENSE' ? expenseCategoriesProvider : incomeCategoriesProvider,
    );

    // Resolve pre-selected category (edit mode or default)
    if (!_defaultSet && categories.isNotEmpty) {
      _defaultSet = true;
      Category? target;
      if (widget.existingCategoryId != null) {
        target = categories.where((c) => c.id == widget.existingCategoryId).firstOrNull;
      }
      target ??= categories
          .where((c) => c.name == (catType == 'EXPENSE' ? 'Other Expenses' : 'Other Income'))
          .firstOrNull ?? categories.first;
      if (widget.selected == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onSelect(target);
        });
      }
    }

    final accent = widget.type == 'I_OWE' ? AppColors.cashOut : AppColors.cashIn;

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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? accent
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? accent
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
