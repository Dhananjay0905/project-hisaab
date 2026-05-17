/// Forgot password page — user enters email, we send a reset link via Brevo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../providers/auth_provider.dart';
import '../../../../../../../../../../core/theme/semantic_colors.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .forgotPassword(_emailCtrl.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(gradient: Theme.of(context).brightness == Brightness.dark ? AppColorsDark.backgroundGradient : AppColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(height: AppSpacing.xl),

                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: Theme.of(context).brightness == Brightness.dark ? AppColorsDark.primaryGradient : AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: const Icon(Icons.lock_reset_rounded,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(height: AppSpacing.xl),

                Text(
                  'Reset password',
                  style: AppTypography.headlineSmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  "Enter your account email and we'll send you a reset link.",
                  style: AppTypography.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl3),

                if (_sent) ...[
                  _SuccessBanner(email: _emailCtrl.text.trim()),
                  const SizedBox(height: AppSpacing.xl2),
                  GradientButton(
                    label: '← Back to sign in',
                    onPressed: () => context.go('/login'),
                  ),
                ] else ...[
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        AppTextField(
                          controller: _emailCtrl,
                          label: 'Email',
                          hint: 'you@email.com',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.email],
                          prefixIcon:
                              const Icon(Icons.email_outlined, size: 20),
                          validator: Validators.email,
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: AppSpacing.xl2),
                        if (_error != null) ...[
                          _ErrorBanner(message: _error!),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        GradientButton(
                          label: 'Send reset link',
                          onPressed: _loading ? null : _submit,
                          loading: _loading,
                          icon: Icons.send_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: SemanticColors.of(context).cashInSurface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: SemanticColors.of(context).cashIn.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_rounded,
                color: SemanticColors.of(context).cashIn, size: 28),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Reset link sent!',
              style: AppTypography.titleSmall.copyWith(color: SemanticColors.of(context).cashIn),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Check your inbox at $email for a password reset link. '
              "It expires in 1 hour.",
              style: AppTypography.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: SemanticColors.of(context).cashOutSurface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: SemanticColors.of(context).cashOut.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded,
                color: SemanticColors.of(context).cashOut, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style:
                    AppTypography.bodySmall.copyWith(color: SemanticColors.of(context).cashOut),
              ),
            ),
          ],
        ),
      );
}
