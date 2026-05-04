/// Verify email page — shown after registration.
/// Prompts user to check inbox and provides a resend option.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../providers/auth_provider.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key, required this.email});
  final String email;

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  bool _resentSuccessfully = false;
  bool _resending = false;
  int _resendCooldown = 0;

  Future<void> _resend() async {
    if (_resending || _resendCooldown > 0) return;
    setState(() => _resending = true);

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .resendVerificationEmail(widget.email);
      if (mounted) {
        setState(() {
          _resentSuccessfully = true;
          _resendCooldown = 60;
        });
        _startCooldown();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to resend. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startCooldown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCooldown--);
      return _resendCooldown > 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xl4),
                // Email illustration
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_rounded,
                    color: AppColors.onPrimary,
                    size: 48,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl3),

                Text(
                  'Check your inbox',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),

                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.6,
                    ),
                    children: [
                      const TextSpan(
                          text: "We've sent a verification link to\n"),
                      TextSpan(
                        text: widget.email,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl4),

                // Success banner
                if (_resentSuccessfully)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: AppSpacing.xl),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.cashInSurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color: AppColors.cashIn.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            color: AppColors.cashIn, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Verification email resent successfully.',
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.cashIn),
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(),

                // Resend button
                GradientButton(
                  label: _resendCooldown > 0
                      ? 'Resend in ${_resendCooldown}s'
                      : 'Resend verification email',
                  onPressed:
                      (_resendCooldown > 0 || _resending) ? null : _resend,
                  loading: _resending,
                  icon: Icons.refresh_rounded,
                ),
                const SizedBox(height: AppSpacing.md),

                // Back to login
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    '← Back to sign in',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
