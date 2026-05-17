/// AccountDeletionScheduledPage — shown after the user confirms account deletion.
///
/// Explains the 5-day grace period and lets the user know how to cancel.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../providers/auth_provider.dart';

class AccountDeletionScheduledPage extends ConsumerWidget {
  const AccountDeletionScheduledPage({super.key, required this.scheduledDeleteAt});

  final DateTime scheduledDeleteAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final deleteDate = DateFormat('MMMM d, yyyy').format(scheduledDeleteAt);

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // ── Icon ────────────────────────────────────────────────────────
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_forever_rounded,
                  size: 52,
                  color: cs.error,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Title ───────────────────────────────────────────────────────
              Text(
                'Account Deletion Scheduled',
                style: AppTypography.headlineSmall.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),

              Text(
                'Your account is scheduled for permanent deletion on',
                style: AppTypography.bodyMedium.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),

              // ── Date pill ───────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: cs.error.withValues(alpha: 0.4)),
                ),
                child: Text(
                  deleteDate,
                  style: AppTypography.titleLarge.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Grace period info card ───────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.restore_rounded,
                      iconColor: const Color(0xFF22C55E),
                      title: 'Changed your mind?',
                      subtitle:
                          'Simply log back in before $deleteDate and your account will be fully restored — no questions asked.',
                    ),
                    const Divider(height: AppSpacing.lg),
                    _InfoRow(
                      icon: Icons.email_outlined,
                      iconColor: cs.primary,
                      title: 'Check your email',
                      subtitle:
                          'We\'ve sent a confirmation to your registered email with the deletion date.',
                    ),
                    const Divider(height: AppSpacing.lg),
                    _InfoRow(
                      icon: Icons.warning_amber_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      title: 'This cannot be undone after the date',
                      subtitle:
                          'All your transactions, savings, dues, and settings will be permanently erased.',
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── CTA ─────────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  // Set auth state to Unauthenticated — the router will
                  // then redirect to /login automatically.
                  onPressed: () => ref.read(authNotifierProvider.notifier).goToLogin(),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Go to Login'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              Text(
                'You have been signed out of all devices.',
                style: AppTypography.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Info Row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.labelMedium.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
