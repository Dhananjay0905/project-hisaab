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
                            'By creating an account and using Hisaab, you agree to be bound by these Terms of Service. If you do not agree, do not use the App. Continued use after changes are posted constitutes acceptance.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.description_outlined,
                        title: '2. Description of Service',
                        content:
                            'Hisaab is a personal finance tracking application. It allows you to record transactions, manage categories, track dues, split expenses, and set savings goals.\n\n'
                            'Hisaab is not a bank, payment processor, or financial institution. Nothing in the App constitutes financial, investment, tax, or legal advice.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.person_outline_rounded,
                        title: '3. Eligibility',
                        content:
                            'You must be at least 13 years old (or 16 in the European Economic Area) to use Hisaab. By using the App, you represent that you meet this requirement.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.account_circle_outlined,
                        title: '4. Your Account',
                        content:
                            'You are responsible for providing accurate registration info, keeping your password confidential, and all activity under your account. You may not create multiple accounts to circumvent restrictions.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.check_circle_outline_rounded,
                        title: '5. Acceptable Use',
                        content:
                            'You agree to use Hisaab only for lawful personal finance tracking. You must not:\n'
                            '• Use Hisaab for any illegal purpose (money laundering, fraud)\n'
                            '• Reverse-engineer or tamper with the App or servers\n'
                            '• Use automated bots or scrapers\n'
                            '• Attempt to access another user\'s data\n'
                            '• Distribute malware',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.data_usage_rounded,
                        title: '6. Your Data',
                        content:
                            'You own all financial data you enter. Our use of your data is governed by our Privacy Policy. We do not guarantee the availability or backup of your data. You are responsible for maintaining your own records.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.copyright_outlined,
                        title: '7. Intellectual Property',
                        content:
                            'The Hisaab application, design, logo, and codebase are the property of the developer. You may not copy, modify, distribute, or create derivative works of the App without permission.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.cloud_done_outlined,
                        title: '8. Availability and Modifications',
                        content:
                            'We may modify, suspend, or discontinue the Service at any time without notice. If we plan to permanently shut down, we will try to provide 30 days\' notice via email. We are not liable for any loss resulting from changes to the Service.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.delete_outline_rounded,
                        title: '9. Termination',
                        content:
                            'You may delete your account at any time (subject to a 5-day grace period). We reserve the right to suspend or terminate your account if you violate these Terms or engage in harmful behaviour.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.warning_amber_rounded,
                        title: '10. Disclaimer of Warranties',
                        content:
                            'The Service is provided "as is" and "as available". We do not warrant that the Service will be uninterrupted, error-free, or secure, or that any financial calculations are accurate. Verify important data with primary sources.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.shield_outlined,
                        title: '11. Limitation of Liability',
                        content:
                            'To the fullest extent permitted by law, Hisaab and its developer shall not be liable for any indirect, incidental, or consequential damages, loss of data, or financial loss. Our total liability shall not exceed INR 0 (zero rupees).',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.gavel_rounded,
                        title: '12. Indemnification',
                        content:
                            'You agree to indemnify and hold harmless Hisaab and its developer from any claims or damages arising from your use of the Service in violation of these Terms or applicable law.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.balance_rounded,
                        title: '13. Governing Law',
                        content:
                            'These Terms are governed by the laws of India. Any disputes will first be attempted to be resolved through good-faith negotiation, and if unresolved, subject to the exclusive jurisdiction of the courts in India.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.cut_outlined,
                        title: '14. Severability',
                        content:
                            'If any provision of these Terms is found to be unenforceable, it will be modified to the minimum extent necessary, and the remaining provisions will continue in full force.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.article_outlined,
                        title: '15. Entire Agreement',
                        content:
                            'These Terms and the Privacy Policy constitute the entire agreement between you and Hisaab regarding the Service.',
                      ),
                      const SizedBox(height: 14),
                      _ToSSection(
                        icon: Icons.mail_outline_rounded,
                        title: '16. Contact',
                        content:
                            'For questions about these Terms, email us at hisaab.app@gmail.com with the subject "Terms of Service Inquiry". We will respond within 14 business days.',
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
