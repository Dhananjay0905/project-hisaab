/// TermsOfServicePage — in-app viewer for the Hisaab Terms of Service.
///
/// Mirrors the exact styling of PrivacyPolicyPage.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              // ── Header ────────────────────────────────────────────────────
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
                          color: cs.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: isDark
                              ? AppColorsDark.softShadow
                              : AppColors.softShadow,
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Terms of Service',
                            style: AppTypography.headlineSmall.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Last updated: May 2025',
                            style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Scrollable body ───────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ToSSection(
                        icon: Icons.handshake_outlined,
                        title: '1. Acceptance of Terms',
                        content:
                            'By creating an account and using Hisaab, you agree to these Terms of Service. If you do not agree, please do not use the app. Continued use after any update to these terms constitutes acceptance.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.person_outline_rounded,
                        title: '2. Eligibility',
                        content:
                            'Hisaab is a private app available by invitation only. You must be at least 13 years old to use it. You are responsible for maintaining the confidentiality of your account credentials.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.check_circle_outline_rounded,
                        title: '3. Acceptable Use',
                        content:
                            'You agree to use Hisaab only for lawful personal finance tracking. You must not:\n'
                            '• Attempt to reverse-engineer or exploit the app\n'
                            '• Use the app to store illegal or harmful content\n'
                            '• Share your account credentials with others\n'
                            '• Attempt to access another user\'s data\n'
                            '• Perform automated scraping or abuse the API',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.cloud_done_outlined,
                        title: '4. Service Availability',
                        content:
                            'Hisaab is provided on a best-effort basis. We do not guarantee 100% uptime. The service may be updated, modified, or discontinued at any time without prior notice. We are not liable for any data loss due to service interruptions.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.lock_outline_rounded,
                        title: '5. Your Data & Privacy',
                        content:
                            'Your use of the app is governed by our Privacy Policy, which is incorporated into these terms by reference. You retain ownership of all financial data you enter. We do not sell or share your data with third parties for marketing purposes.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.warning_amber_rounded,
                        title: '6. Disclaimer of Warranties',
                        content:
                            'Hisaab is provided "as is" without any warranty, express or implied. We do not warrant that the app will be error-free, secure, or uninterrupted. Financial data displayed in the app is based solely on what you enter — we do not provide financial advice.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.shield_outlined,
                        title: '7. Limitation of Liability',
                        content:
                            'To the fullest extent permitted by law, the developer shall not be liable for any indirect, incidental, or consequential damages arising from your use of Hisaab, including loss of data or financial loss.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.delete_outline_rounded,
                        title: '8. Account Termination',
                        content:
                            'You may delete your account at any time from the app. Account deletion is subject to a 5-day grace period during which you can recover your account by logging back in. After 5 days, all your data is permanently deleted.\n\n'
                            'We reserve the right to terminate accounts that violate these terms.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.edit_note_rounded,
                        title: '9. Changes to These Terms',
                        content:
                            'We may update these Terms of Service at any time. When we do, existing users will be required to review and accept the new terms before continuing to use the app.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.balance_rounded,
                        title: '10. Governing Law',
                        content:
                            'These terms are governed by the laws of India. Any disputes will be resolved through good-faith negotiation between the parties.',
                      ),
                      const SizedBox(height: 28),
                    ],
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

// ─── Section card ─────────────────────────────────────────────────────────────

class _ToSSection extends StatelessWidget {
  const _ToSSection({
    required this.icon,
    required this.title,
    required this.content,
  });

  final IconData icon;
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow:
            isDark ? AppColorsDark.softShadow : AppColors.softShadow,
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
                child: Icon(icon, size: 16, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: AppTypography.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
