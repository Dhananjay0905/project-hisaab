/// AddSplitPage — slide-up modal for creating a new bill split.
///
/// User enters: title, total amount, number of people, names of each person.
/// Per-person amount is calculated automatically (equal split).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../providers/splits_provider.dart';

class AddSplitPage extends ConsumerStatefulWidget {
  const AddSplitPage({super.key});

  @override
  ConsumerState<AddSplitPage> createState() => _AddSplitPageState();
}

class _AddSplitPageState extends ConsumerState<AddSplitPage> {
  final _titleController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _noteController = TextEditingController();

  int _participantCount = 2; // minimum 1 other person + you = 2 total
  late List<TextEditingController> _nameControllers;
  DateTime _selectedDate = DateTime.now();
  Category? _selectedCategory;

  bool _isSubmitting = false;
  String? _errorMessage;

  final _currencyFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _nameControllers = List.generate(_participantCount - 1, (_) => TextEditingController());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _totalAmountController.dispose();
    _noteController.dispose();
    for (final c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _adjustCount(int delta) {
    final newCount = (_participantCount + delta).clamp(2, 20);
    if (newCount == _participantCount) return;

    setState(() {
      final diff = newCount - _participantCount;
      if (diff > 0) {
        for (var i = 0; i < diff; i++) {
          _nameControllers.add(TextEditingController());
        }
      } else {
        final removed = _nameControllers.sublist(newCount - 1);
        for (final c in removed) {
          c.dispose();
        }
        _nameControllers = _nameControllers.sublist(0, newCount - 1);
      }
      _participantCount = newCount;
    });
  }

  double get _perPerson {
    final total = double.tryParse(_totalAmountController.text.trim()) ?? 0;
    if (_participantCount < 1) return 0;
    return total / _participantCount;
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final totalStr = _totalAmountController.text.trim();
    final total = double.tryParse(totalStr);

    if (title.isEmpty) {
      setState(() => _errorMessage = 'Please enter a title.');
      return;
    }
    if (total == null || total <= 0) {
      setState(() => _errorMessage = 'Please enter a valid total amount.');
      return;
    }
    if (_selectedCategory == null) {
      setState(() => _errorMessage = 'Please select a category.');
      return;
    }

    final names = _nameControllers.map((c) => c.text.trim()).toList();
    if (names.any((n) => n.isEmpty)) {
      setState(() => _errorMessage = 'Please enter all participant names.');
      return;
    }

    setState(() { _isSubmitting = true; _errorMessage = null; });

    try {
      await ref.read(splitsProvider.notifier).addSplit(
        title: title,
        totalAmount: total,
        participantNames: names,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        date: _selectedDate,
        categoryId: _selectedCategory?.id,
      );
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
    final perPerson = _perPerson;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // ── Header ────────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            title: Text('New Split', style: AppTypography.titleLarge),
            centerTitle: true,
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                MediaQuery.of(context).padding.bottom + AppSpacing.xl2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Info banner ───────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text('🍽️', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You paid the bill. Enter how many people are splitting it (including yourself), and their names. We\'ll track who pays you back.',
                            style: AppTypography.bodySmall.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Title ─────────────────────────────────────────────────
                  _Label('What was it for?'),
                  const SizedBox(height: AppSpacing.xs),
                  _Field(
                    controller: _titleController,
                    hint: 'e.g. Dinner at Barbeque Nation',
                    icon: Icons.receipt_long_rounded,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Total amount ──────────────────────────────────────────
                  _Label('Total Bill Amount'),
                  const SizedBox(height: AppSpacing.xs),
                  _AmountField(
                    controller: _totalAmountController,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Category ──────────────────────────────────────────────
                  _Label('Category'),
                  const SizedBox(height: AppSpacing.sm),
                  _SplitCategoryPicker(
                    selected: _selectedCategory,
                    onSelect: (cat) => setState(() => _selectedCategory = cat),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── People counter ────────────────────────────────────────
                  _Label('Number of People (including you)'),
                  const SizedBox(height: AppSpacing.xs),
                  _PeopleCounter(
                    count: _participantCount,
                    onDecrement: () => _adjustCount(-1),
                    onIncrement: () => _adjustCount(1),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // ── Per-person chip ───────────────────────────────────────
                  if (perPerson > 0)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: SemanticColors.of(context).cashInSurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Each person pays ₹${_currencyFmt.format(perPerson)}',
                          style: AppTypography.labelMedium.copyWith(
                            color: SemanticColors.of(context).cashIn,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Participant names ─────────────────────────────────────
                  _Label('Friends\' Names (others, not you)'),
                  const SizedBox(height: AppSpacing.xs),
                  ...List.generate(_nameControllers.length, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _Field(
                      controller: _nameControllers[i],
                      hint: 'Person ${i + 1} name',
                      icon: Icons.person_outline_rounded,
                    ),
                  )),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Note ──────────────────────────────────────────────────
                  _Label('Note (optional)'),
                  const SizedBox(height: AppSpacing.xs),
                  _Field(
                    controller: _noteController,
                    hint: 'Any details…',
                    icon: Icons.notes_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Date ───────────────────────────────────────────────────
                  _Label('Date'),
                  const SizedBox(height: AppSpacing.xs),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('MMM d, yyyy').format(_selectedDate),
                            style: AppTypography.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Error ─────────────────────────────────────────────────
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: Theme.of(context).colorScheme.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTypography.bodySmall
                                  .copyWith(color: Theme.of(context).colorScheme.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // ── Save button ───────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
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
                              'Create Split',
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
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTypography.labelMedium.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

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
            child: Text('₹', style: AppTypography.headlineMedium.copyWith(color: Theme.of(context).colorScheme.primary)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
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

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final ValueChanged<String>? onChanged;

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
        onChanged: onChanged,
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

class _PeopleCounter extends StatelessWidget {
  const _PeopleCounter({
    required this.count,
    required this.onDecrement,
    required this.onIncrement,
  });
  final int count;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.group_outlined, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count people',
              style: AppTypography.bodyLarge,
            ),
          ),
          _CounterButton(
            icon: Icons.remove_rounded,
            onTap: count > 2 ? onDecrement : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          _CounterButton(
            icon: Icons.add_rounded,
            onTap: count < 20 ? onIncrement : null,
          ),
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ─── Split Category Picker ────────────────────────────────────────────────────

class _SplitCategoryPicker extends ConsumerStatefulWidget {
  const _SplitCategoryPicker({
    required this.selected,
    required this.onSelect,
  });

  final Category? selected;
  final ValueChanged<Category?> onSelect;

  @override
  ConsumerState<_SplitCategoryPicker> createState() => _SplitCategoryPickerState();
}

class _SplitCategoryPickerState extends ConsumerState<_SplitCategoryPicker> {
  bool _defaultSet = false;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(expenseCategoriesProvider);

    // Pre-select "Other Expenses" by default on first load
    if (!_defaultSet && categories.isNotEmpty) {
      _defaultSet = true;
      if (widget.selected == null) {
        final defaultCat = categories
            .where((c) => c.name == 'Other Expenses')
            .firstOrNull;
        final toSelect = defaultCat ?? categories.first;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onSelect(toSelect);
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? SemanticColors.of(context).cashOut
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? SemanticColors.of(context).cashOut
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
