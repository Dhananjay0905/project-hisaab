/// Unified error + retry widget used across all pages.
///
/// Three usage modes:
///  1. **Default (fullscreen):**
///     ```dart
///     AppErrorWidget(
///       message: 'Could not load data',
///       onRetry: () => ref.read(provider.notifier).refresh(),
///     )
///     ```
///  2. **Sliver** — for pages that use `CustomScrollView`:
///     ```dart
///     AppErrorWidget.sliver(message: '...', onRetry: () => ...)
///     ```
///  3. **Compact / inline** — for sections inside a scrolling page
///     (e.g. analytics where two providers load independently):
///     ```dart
///     AppErrorWidget.compact(message: '...', onRetry: () => ...)
///     ```
library;

import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';

// ─── Fullscreen error (non-sliver) ──────────────────────────────────────────

class AppErrorWidget extends StatelessWidget {
  const AppErrorWidget({
    super.key,
    this.message,
    this.onRetry,
    this.title = 'Could not load data',
  });

  /// Short title shown below the icon.
  final String title;

  /// Optional longer description shown below the title.
  final String? message;

  /// Called when the user taps "Try again". If null, the button is hidden.
  final VoidCallback? onRetry;

  /// Wraps the error widget in a [SliverFillRemaining] for sliver-based pages.
  static Widget sliver({
    String title = 'Could not load data',
    String? message,
    VoidCallback? onRetry,
  }) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: AppErrorWidget(
        title: title,
        message: message,
        onRetry: onRetry,
      ),
    );
  }

  /// Compact inline variant — a small card for use inside scrollable lists
  /// where multiple sections load independently (e.g. analytics).
  static Widget compact({
    String? message,
    VoidCallback? onRetry,
  }) {
    return _CompactErrorWidget(message: message, onRetry: onRetry);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: cs.outlineVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message!,
                style: AppTypography.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Compact / inline variant ─────────────────────────────────────────────────

class _CompactErrorWidget extends StatelessWidget {
  const _CompactErrorWidget({this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 20,
            color: cs.onErrorContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message ?? 'Could not load data.',
              style: AppTypography.bodySmall.copyWith(
                color: cs.onErrorContainer,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Retry',
                style: AppTypography.labelMedium.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
