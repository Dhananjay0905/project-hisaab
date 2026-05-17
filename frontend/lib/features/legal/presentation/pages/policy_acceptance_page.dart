/// PolicyAcceptancePage — shown to existing users who haven't accepted the
/// Privacy Policy & Terms of Service yet.
///
/// Cannot be dismissed. User must accept or logout.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/error/failures.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class PolicyAcceptancePage extends ConsumerStatefulWidget {
  const PolicyAcceptancePage({super.key});

  @override
  ConsumerState<PolicyAcceptancePage> createState() =>
      _PolicyAcceptancePageState();
}

class _PolicyAcceptancePageState extends ConsumerState<PolicyAcceptancePage> {
  String? _errorMessage;

  Future<void> _accept() async {
    setState(() => _errorMessage = null);
    await ref.read(authNotifierProvider.notifier).acceptPolicy();
    if (!mounted) return;

    ref.read(authNotifierProvider).whenOrNull(
      error: (error, _) {
        setState(() {
          _errorMessage = error is Failure
              ? error.message
              : 'Something went wrong. Please try again.';
        });
      },
    );
  }

  Future<void> _logout() async {
    await ref.read(authNotifierProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoading = ref.watch(
      authNotifierProvider.select((s) => s.isLoading),
    );

    return Scaffold(
      backgroundColor: cs.surface,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColorsDark.backgroundGradient
              : AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Scrollable content ────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.xl,
                    AppSpacing.screenH,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.shield_rounded,
                          size: 46,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Title
                      Text(
                        'Before you continue',
                        style: AppTypography.headlineSmall.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      Text(
                        'We\'ve updated our policies. Please review and accept them to continue using Hisaab.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // What's covered card
                      _PolicySummaryCard(cs: cs),

                      const SizedBox(height: AppSpacing.lg),

                      // Links
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _PolicyLink(
                            label: 'Privacy Policy',
                            onTap: () => context.push('/privacy-policy'),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm),
                            child: Text(
                              '·',
                              style: AppTypography.bodyMedium.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          _PolicyLink(
                            label: 'Terms of Service',
                            onTap: () => context.push('/terms-of-service'),
                          ),
                        ],
                      ),

                      // Error
                      if (_errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _ErrorBanner(message: _errorMessage!),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Fixed bottom actions ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  0,
                  AppSpacing.screenH,
                  AppSpacing.lg,
                ),
                child: Column(
                  children: [
                    GradientButton(
                      label: 'I Accept & Continue',
                      onPressed: isLoading ? null : _accept,
                      loading: isLoading,
                      icon: Icons.check_rounded,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: isLoading ? null : _logout,
                      child: Text(
                        'Logout',
                        style: AppTypography.bodyMedium.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Policy summary card ──────────────────────────────────────────────────────

class _PolicySummaryCard extends StatelessWidget {
  const _PolicySummaryCard({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? AppColorsDark.softShadow
            : AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.info_outline_rounded,
                    size: 16, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'What\'s covered',
                style: AppTypography.titleSmall.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _BulletRow(
            icon: Icons.lock_outline_rounded,
            text: 'What data we collect and how we store it',
            cs: cs,
          ),
          const SizedBox(height: AppSpacing.sm),
          _BulletRow(
            icon: Icons.security_rounded,
            text: 'Which fields are encrypted (AES-256-GCM)',
            cs: cs,
          ),
          const SizedBox(height: AppSpacing.sm),
          _BulletRow(
            icon: Icons.gavel_rounded,
            text: 'Your rights under GDPR & CCPA',
            cs: cs,
          ),
          const SizedBox(height: AppSpacing.sm),
          _BulletRow(
            icon: Icons.balance_rounded,
            text: 'Rules for using Hisaab fairly',
            cs: cs,
          ),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({
    required this.icon,
    required this.text,
    required this.cs,
  });
  final IconData icon;
  final String text;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: cs.primary.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
}

// ─── Policy link ──────────────────────────────────────────────────────────────

class _PolicyLink extends StatelessWidget {
  const _PolicyLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
}

// ─── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style:
                  AppTypography.bodySmall.copyWith(color: cs.error),
            ),
          ),
        ],
      ),
    );
  }
}
