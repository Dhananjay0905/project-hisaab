/// 3-second undo snack bar for soft-delete flows.
///
/// Usage:
/// ```dart
/// UndoSnackBar.show(
///   context,
///   message: 'Transaction deleted',
///   onUndo: () => ref.read(...).undo(id),
///   onExpired: () => ref.read(...).permanentDelete(id),
/// );
/// ```
library;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';

class UndoSnackBar {
  UndoSnackBar._();

  static void show(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    required VoidCallback onExpired,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();

    bool undoPressed = false;

    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: duration,
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl2,
        ),
        content: _UndoSnackBarContent(
          message: message,
          duration: duration,
          onUndo: () {
            undoPressed = true;
            ScaffoldMessenger.of(context).clearSnackBars();
            onUndo();
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
      ),
    );

    controller.closed.then((_) {
      if (!undoPressed) onExpired();
    });
  }
}

class _UndoSnackBarContent extends StatefulWidget {
  const _UndoSnackBarContent({
    required this.message,
    required this.duration,
    required this.onUndo,
  });

  final String message;
  final Duration duration;
  final VoidCallback onUndo;

  @override
  State<_UndoSnackBarContent> createState() => _UndoSnackBarContentState();
}

class _UndoSnackBarContentState extends State<_UndoSnackBarContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timer;

  @override
  void initState() {
    super.initState();
    _timer = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.onSurface,
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          AnimatedBuilder(
            animation: _timer,
            builder: (_, __) => ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.md),
              ),
              child: LinearProgressIndicator(
                value: 1 - _timer.value,
                minHeight: 3,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.message,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.surface,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                TextButton(
                  onPressed: widget.onUndo,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryContainer,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'UNDO',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
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
