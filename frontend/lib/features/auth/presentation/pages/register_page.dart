/// Register page — scrollable with comfortable spacing.
///
/// Unlike login (which fits on one screen), register has 6+ fields
/// so a scroll is the right UX here — but with generous padding
/// and clear visual sections instead of cramming everything.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../providers/auth_provider.dart';
import '../../../../../../../../../../core/theme/semantic_colors.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _openingBalanceCtrl = TextEditingController();

  // Keys so we can re-validate confirm field when password changes
  final _confirmFieldKey = GlobalKey<FormFieldState>();

  String? _errorMessage;
  int _passwordStrength = 0; // 0=empty 1=weak 2=fair 3=strong
  bool _policyAccepted = false;

  void _onPasswordChanged(String value) {
    int strength = 0;
    if (value.isNotEmpty) strength = 1; // weak
    if (value.length >= 8 &&
        RegExp(r'[A-Za-z]').hasMatch(value) &&
        RegExp(r'[0-9]').hasMatch(value)) strength = 2; // fair
    if (value.length >= 10 &&
        RegExp(r'[A-Za-z]').hasMatch(value) &&
        RegExp(r'[0-9]').hasMatch(value) &&
        RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(value)) strength = 3; // strong
    setState(() => _passwordStrength = strength);
    // Re-validate confirm field so mismatch error updates live
    _confirmFieldKey.currentState?.validate();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _openingBalanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_policyAccepted) {
      setState(() => _errorMessage = 'You must accept the Privacy Policy and Terms of Service to continue.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    final openingBalance = double.tryParse(
          _openingBalanceCtrl.text.replaceAll(',', '.'),
        ) ??
        0.0;

    await ref.read(authNotifierProvider.notifier).register(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          openingBalance: openingBalance,
        );

    if (!mounted) return;

    ref.read(authNotifierProvider).whenOrNull(
      error: (error, _) {
        setState(() {
          if (error is Failure) {
            _errorMessage = error.message;
          } else {
            _errorMessage = error
                .toString()
                .replaceAll('Exception: ', '')
                .replaceAll('Error: ', '');
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
      authNotifierProvider.select((s) => s.isLoading),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(gradient: Theme.of(context).brightness == Brightness.dark ? AppColorsDark.backgroundGradient : AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Fixed header ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, 16, AppSpacing.screenH, 0,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: Theme.of(context).brightness == Brightness.dark ? AppColorsDark.softShadow : AppColors.softShadow,
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create account',
                            style: AppTypography.headlineSmall.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Start tracking your finances today',
                            style: AppTypography.bodySmall.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Scrollable form body ───────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── SECTION 1: Personal info ─────────────────
                        _SectionCard(
                          title: 'Personal info',
                          icon: Icons.person_rounded,
                          children: [
                            AppTextField(
                              controller: _nameCtrl,
                              label: 'Full name',
                              hint: 'Alex Johnson',
                              keyboardType: TextInputType.name,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                              prefixIcon: const Icon(
                                  Icons.person_outline_rounded,
                                  size: 20),
                              validator: Validators.name,
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              controller: _emailCtrl,
                              label: 'Email',
                              hint: 'you@email.com',
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              prefixIcon:
                                  const Icon(Icons.email_outlined, size: 20),
                              validator: Validators.email,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── SECTION 2: Security ──────────────────────
                        _SectionCard(
                          title: 'Security',
                          icon: Icons.shield_rounded,
                          children: [
                            // Password field — AppTextField auto-adds eye toggle
                            AppTextField(
                              controller: _passwordCtrl,
                              label: 'Password',
                              hint: 'Min. 8 chars, include a letter & number',
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 20),
                              onChanged: _onPasswordChanged,
                              validator: Validators.password,
                            ),

                            // Password strength bar
                            if (_passwordStrength > 0) ...[
                              const SizedBox(height: 10),
                              _PasswordStrengthBar(strength: _passwordStrength),
                            ],

                            const SizedBox(height: 14),

                            // Confirm password field — AppTextField auto-adds eye toggle
                            AppTextField(
                              key: _confirmFieldKey,
                              controller: _confirmCtrl,
                              label: 'Confirm password',
                              hint: 'Repeat your password',
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 20),
                              validator: (v) => Validators.confirmPassword(
                                  v, _passwordCtrl.text),
                            ),

                            const SizedBox(height: 10),

                            // Password rules hint
                            _PasswordRulesHint(strength: _passwordStrength),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── SECTION 3: Financial setup ───────────────
                        _SectionCard(
                          title: 'Financial setup',
                          icon: Icons.account_balance_wallet_rounded,
                          children: [
                            // Opening balance
                            Text(
                              'Opening balance',
                              style: AppTypography.labelMedium.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your current wallet/bank balance. Leave 0 if starting fresh.',
                              style: AppTypography.bodySmall.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 8),
                            AppTextField(
                              controller: _openingBalanceCtrl,
                              label: '',
                              hint: '0.00',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              textInputAction: TextInputAction.done,
                              prefixIcon: Align(
                                widthFactor: 1.0,
                                heightFactor: 1.0,
                                alignment: Alignment.center,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md),
                                  child: Text(
                                    '₹',
                                    style: AppTypography.titleMedium.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                ),
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}')),
                              ],
                              validator: Validators.optionalAmount,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── SECTION 4: Legal ──────────────────────────
                        _SectionCard(
                          title: 'Legal',
                          icon: Icons.gavel_rounded,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() => _policyAccepted = !_policyAccepted);
                              },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _policyAccepted,
                                      onChanged: (v) => setState(() => _policyAccepted = v ?? false),
                                      activeColor: Theme.of(context).colorScheme.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: RichText(
                                        text: TextSpan(
                                          style: AppTypography.bodySmall.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                          children: [
                                            const TextSpan(text: 'I have read and agree to the '),
                                            WidgetSpan(
                                              alignment: PlaceholderAlignment.baseline,
                                              baseline: TextBaseline.alphabetic,
                                              child: GestureDetector(
                                                onTap: () => context.push('/privacy-policy'),
                                                child: Text(
                                                  'Privacy Policy',
                                                  style: AppTypography.bodySmall.copyWith(
                                                    color: Theme.of(context).colorScheme.primary,
                                                    fontWeight: FontWeight.w600,
                                                    decoration: TextDecoration.underline,
                                                    decorationColor: Theme.of(context).colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const TextSpan(text: ' and '),
                                            WidgetSpan(
                                              alignment: PlaceholderAlignment.baseline,
                                              baseline: TextBaseline.alphabetic,
                                              child: GestureDetector(
                                                onTap: () => context.push('/terms-of-service'),
                                                child: Text(
                                                  'Terms of Service',
                                                  style: AppTypography.bodySmall.copyWith(
                                                    color: Theme.of(context).colorScheme.primary,
                                                    fontWeight: FontWeight.w600,
                                                    decoration: TextDecoration.underline,
                                                    decorationColor: Theme.of(context).colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Error banner
                        if (_errorMessage != null) ...[
                          _ErrorBanner(message: _errorMessage!),
                          const SizedBox(height: 14),
                        ],

                        // CTA
                        GradientButton(
                          label: 'Create account',
                          onPressed: isLoading ? null : _submit,
                          loading: isLoading,
                          icon: Icons.arrow_forward_rounded,
                        ),

                        const SizedBox(height: 20),

                        // Login link
                        Center(
                          child: GestureDetector(
                            onTap: () => context.pop(),
                            child: RichText(
                              text: TextSpan(
                                style: AppTypography.bodyMedium.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                children: [
                                  const TextSpan(
                                      text: 'Already have an account? '),
                                  TextSpan(
                                    text: 'Sign in →',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Password strength bar ─────────────────────────────────────────────────────

class _PasswordStrengthBar extends StatelessWidget {
  const _PasswordStrengthBar({required this.strength});
  final int strength; // 1=weak 2=fair 3=strong

  @override
  Widget build(BuildContext context) {
    final labels = ['', 'Weak', 'Fair', 'Strong'];
    final colors = [
      Colors.transparent,
      const Color(0xFFE53935), // weak — red
      const Color(0xFFF57C00), // fair — orange
      const Color(0xFF2E7D32), // strong — green
    ];
    final color = colors[strength];
    final label = labels[strength];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (i) {
            final filled = i < strength;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 4,
                margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                decoration: BoxDecoration(
                  color: filled ? color : Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Password rules hint ───────────────────────────────────────────────────────

class _PasswordRulesHint extends StatelessWidget {
  const _PasswordRulesHint({required this.strength});
  final int strength;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password requirements:',
            style: AppTypography.labelSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _RuleRow(text: 'At least 8 characters'),
          _RuleRow(text: 'At least one letter (a–z or A–Z)'),
          _RuleRow(text: 'At least one number (0–9)'),
          _RuleRow(
            text: 'Special character (!@#\$…) for strong password',
            isOptional: true,
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.text, this.isOptional = false});
  final String text;
  final bool isOptional;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(
            isOptional ? Icons.add_circle_outline_rounded : Icons.circle,
            size: isOptional ? 12 : 6,
            color: isOptional
                ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTypography.labelSmall.copyWith(
                color: isOptional
                    ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

/// Grouped card with a section title badge.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: Theme.of(context).brightness == Brightness.dark ? AppColorsDark.softShadow : AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: AppTypography.titleSmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
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
