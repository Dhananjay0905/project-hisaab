/// Reset password page — token comes from deep link query param.
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

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key, required this.token});
  final String token;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _success = false;
  String? _error;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).resetPassword(
            token: widget.token,
            newPassword: _newPasswordCtrl.text,
          );
      if (mounted) setState(() => _success = true);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = 'Reset link is invalid or has expired. '
                'Please request a new one.');
      }
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
                const SizedBox(height: AppSpacing.xl),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: Theme.of(context).brightness == Brightness.dark ? AppColorsDark.primaryGradient : AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: const Icon(Icons.key_rounded,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(height: AppSpacing.xl),

                Text(
                  'Set new password',
                  style: AppTypography.headlineSmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Choose a strong password for your account.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl3),

                if (_success) ...[
                  Container(
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
                          'Password updated!',
                          style: AppTypography.titleSmall
                              .copyWith(color: SemanticColors.of(context).cashIn),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Your password has been reset. '
                          'You can now sign in with your new password.',
                          style: AppTypography.bodySmall.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl2),
                  GradientButton(
                    label: 'Sign in',
                    onPressed: () => context.go('/login'),
                    icon: Icons.arrow_forward_rounded,
                  ),
                ] else ...[
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        AppTextField(
                          controller: _newPasswordCtrl,
                          label: 'New password',
                          hint: 'Min. 8 characters',
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          prefixIcon:
                              const Icon(Icons.lock_outline_rounded, size: 20),
                          validator: Validators.password,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _confirmCtrl,
                          label: 'Confirm new password',
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          prefixIcon:
                              const Icon(Icons.lock_outline_rounded, size: 20),
                          validator: (v) => Validators.confirmPassword(
                              v, _newPasswordCtrl.text),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: AppSpacing.xl2),
                        if (_error != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: SemanticColors.of(context).cashOutSurface,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Text(
                              _error!,
                              style: AppTypography.bodySmall
                                  .copyWith(color: SemanticColors.of(context).cashOut),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        GradientButton(
                          label: 'Set new password',
                          onPressed: _loading ? null : _submit,
                          loading: _loading,
                          icon: Icons.check_rounded,
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
