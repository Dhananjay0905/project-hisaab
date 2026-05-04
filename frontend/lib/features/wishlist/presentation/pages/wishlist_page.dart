/// WishlistPage — list of items the user is saving up for.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/entities/wishlist_item.dart';
import '../providers/wishlist_provider.dart';

class WishlistPage extends ConsumerStatefulWidget {
  const WishlistPage({super.key});

  @override
  ConsumerState<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends ConsumerState<WishlistPage> {
  Future<void> _handleRefresh() async {
    ref.invalidate(wishlistProvider);
    await ref.read(wishlistProvider.future).catchError((_) => <WishlistItem>[]);
  }

  @override
  Widget build(BuildContext context) {
    final wishlistAsync = ref.watch(wishlistProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => context.pop(),
              ),
              title: Text(
                'Wishlist',
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            wishlistAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                    child: Text(
                  'Failed to load wishlist',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                )),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return SliverFillRemaining(
                    child: _EmptyState(onAdd: () => _showAddSheet(context, ref)),
                  );
                }

                final unpurchased =
                    items.where((i) => !i.isPurchased).toList();
                final purchased = items.where((i) => i.isPurchased).toList();

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.sm, AppSpacing.md, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (unpurchased.isNotEmpty) ...[
                        ...unpurchased.map((item) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _WishlistCard(item: item, ref: ref),
                            )),
                      ],
                      if (purchased.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm),
                          child: Text(
                            'Purchased',
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...purchased.map((item) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _WishlistCard(item: item, ref: ref),
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
        onPressed: () => _showAddSheet(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Item'),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WishlistItemSheet(
        ref: ref,
        onSave: (title, emoji, targetPrice, amountSaved, link) async {
          await ref.read(wishlistProvider.notifier).addItem(
                title: title,
                emoji: emoji,
                targetPrice: targetPrice,
                amountSaved: amountSaved,
                deductFromSavings: false, // controlled from Savings page checklist
                link: link,
              );
        },
      ),
    );
  }
}

// ─── Wishlist Card ────────────────────────────────────────────────────────────

class _WishlistCard extends StatelessWidget {
  const _WishlistCard({required this.item, required this.ref});
  final WishlistItem item;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final progress = item.progress;
    final isPurchased = item.isPurchased;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        boxShadow: AppColors.softShadow,
        border: isPurchased
            ? Border.all(color: AppColors.secondary.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.xs, AppSpacing.sm),
            child: Row(
              children: [
                // Emoji
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(item.emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Title + amounts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppTypography.titleSmall.copyWith(
                          color: isPurchased
                              ? AppColors.onSurfaceVariant
                              : AppColors.onSurface,
                          decoration: isPurchased
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '₹${item.amountSaved.toStringAsFixed(0)} saved',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (item.targetPrice != null) ...[
                            Text(
                              ' / ₹${item.targetPrice!.toStringAsFixed(0)}',
                              style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Action menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      size: 20, color: AppColors.onSurfaceVariant),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.sm)),
                  onSelected: (val) =>
                      _handleAction(context, val, item, ref),
                  itemBuilder: (_) => [
                    if (!isPurchased)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ]),
                      ),
                    if (!isPurchased)
                      const PopupMenuItem(
                        value: 'purchase',
                        child: Row(children: [
                          Icon(Icons.check_circle_rounded,
                              size: 18, color: AppColors.secondary),
                          SizedBox(width: 8),
                          Text('Mark Purchased'),
                        ]),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_rounded,
                            size: 18, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(color: AppColors.error)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Progress bar
          if (progress != null && !isPurchased) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceContainer,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        item.isComplete
                            ? AppColors.secondary
                            : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],

          // Link row
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: Row(
              children: [
                if (item.link != null) ...[
                  GestureDetector(
                    // In a real app: launch URL
                    child: Row(
                      children: [
                        const Icon(Icons.open_in_new_rounded,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 2),
                        Text('Link',
                            style: AppTypography.labelSmall
                                .copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
                if (isPurchased) ...[
                  const Icon(Icons.check_circle_rounded,
                      size: 16, color: AppColors.secondary),
                  const SizedBox(width: 4),
                  Text('Purchased',
                      style: AppTypography.labelSmall
                          .copyWith(color: AppColors.secondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleAction(
      BuildContext context, String action, WishlistItem item, WidgetRef ref) {
    switch (action) {
      case 'edit':
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _WishlistItemSheet(
            ref: ref,
            item: item,
            onSave: (title, emoji, targetPrice, amountSaved, link) async {
              await ref.read(wishlistProvider.notifier).updateItem(
                    item.id,
                    title: title,
                    emoji: emoji,
                    targetPrice: targetPrice,
                    amountSaved: amountSaved,
                    link: link,
                  );
            },
          ),
        );
      case 'purchase':
        ref.read(wishlistProvider.notifier).markPurchased(item.id);
      case 'delete':
        ref.read(wishlistProvider.notifier).deleteItem(item.id);
    }
  }
}


// ─── Add/Edit Bottom Sheet ────────────────────────────────────────────────────

typedef _WishlistSaveCallback = Future<void> Function(
  String title,
  String emoji,
  double? targetPrice,
  double amountSaved,
  String? link,
);

class _WishlistItemSheet extends StatefulWidget {
  const _WishlistItemSheet({
    required this.ref,
    required this.onSave,
    this.item,
  });

  final WidgetRef ref;
  final WishlistItem? item;
  final _WishlistSaveCallback onSave;

  @override
  State<_WishlistItemSheet> createState() => _WishlistItemSheetState();
}

class _WishlistItemSheetState extends State<_WishlistItemSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _emojiCtrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _savedCtrl;
  late final TextEditingController _linkCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _titleCtrl = TextEditingController(text: item?.title ?? '');
    _emojiCtrl = TextEditingController(text: item?.emoji ?? '🛍️');
    _targetCtrl = TextEditingController(
        text: item?.targetPrice?.toStringAsFixed(2) ?? '');
    _savedCtrl =
        TextEditingController(text: item?.amountSaved.toStringAsFixed(2) ?? '0');
    _linkCtrl = TextEditingController(text: item?.link ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _emojiCtrl.dispose();
    _targetCtrl.dispose();
    _savedCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md + bottom),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              isEdit ? 'Edit Item' : 'Add to Wishlist',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),

            // Emoji + Title row
            Row(
              children: [
                SizedBox(
                  width: 64,
                  child: TextField(
                    controller: _emojiCtrl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24),
                    maxLength: 2,
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.sm)),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Item name',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.sm)),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Target price + Amount saved
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Target price (optional)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.sm)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _savedCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Amount saved',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.sm)),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Link
            TextField(
              controller: _linkCtrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Product link (optional)',
                prefixIcon: const Icon(Icons.link_rounded, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.sm)),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.sm + 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.sm)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isEdit ? 'Save Changes' : 'Add to Wishlist',
                        style: AppTypography.labelLarge
                            .copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() => _loading = true);
    try {
      await widget.onSave(
        title,
        _emojiCtrl.text.trim().isEmpty ? '🛍️' : _emojiCtrl.text.trim(),
        _targetCtrl.text.isEmpty ? null : double.tryParse(_targetCtrl.text),
        double.tryParse(_savedCtrl.text) ?? 0,
        _linkCtrl.text.trim().isEmpty ? null : _linkCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => _loading = false);
    }
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🛍️', style: TextStyle(fontSize: 56)),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Your wishlist is empty',
              style:
                  AppTypography.titleMedium.copyWith(color: AppColors.onSurface),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Add items you\'re saving up for and track your progress.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add First Item'),
            ),
          ],
        ),
      ),
    );
  }
}
