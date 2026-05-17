/// PrivacyPolicyPage — in-app viewer for the Hisaab Privacy Policy.
///
/// Styled to match the rest of the app (dark gradient, section cards).
/// Can be opened from the acceptance gate or from More → Legal.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

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
                            'Privacy Policy',
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
                      _PolicySection(
                        icon: Icons.info_outline_rounded,
                        title: '1. Who We Are',
                        content:
                            'Hisaab ("we", "us", "our") is a personal finance tracking application built and operated as an independent project. Hisaab is not a financial institution, bank, or regulated financial service.',
                      ),
                      const SizedBox(height: 14),
                      _PolicySection(
                        icon: Icons.folder_outlined,
                        title: '2. What Data We Collect',
                        content:
                            'Account Data:\n'
                            '• Display name, currency preference, opening balance, and creation date (Not encrypted).\n'
                            '• Email address (Not encrypted — required for login and emails).\n'
                            '• Password (bcrypt hash only — never stored as plaintext).\n\n'
                            'Financial Records:\n'
                            '• Transactions: Title & Note (AES-256-GCM encrypted). Amount, Type, Date, Category (Not encrypted).\n'
                            '• Categories: Name, Emoji, Type, Limit (Not encrypted).\n'
                            '• Dues: Title, Person\'s name, Note (AES-256-GCM encrypted). Amount, Date, Status (Not encrypted).\n'
                            '• Splits: Title, Note, Participant names (AES-256-GCM encrypted). Amounts, Date (Not encrypted).\n'
                            '• Savings: Total amount, Cash deduction (Not encrypted).\n'
                            '• Wishlist: Title (AES-256-GCM encrypted). Emoji, URL, Price, Amount saved (Not encrypted).\n'
                            '• Recurring: Title (AES-256-GCM encrypted). Amount, Type, Frequency, Next due date (Not encrypted).\n\n'
                            'Tokens & Technical Data:\n'
                            '• Auth tokens are stored in device secure storage.\n'
                            '• Server logs (IP, path, timestamp) retained for 30 days. IP is tracked in-memory for rate limiting.',
                      ),
                      const SizedBox(height: 14),
                      _PolicySection(
                        icon: Icons.lock_outline_rounded,
                        title: '3. What Is & Is Not Encrypted',
                        content:
                            'Encrypted with AES-256-GCM:\n'
                            '• Transaction titles and notes\n'
                            '• Due titles, person names, and notes\n'
                            '• Split titles, notes, and participant names\n'
                            '• Wishlist item titles\n'
                            '• Recurring transaction titles\n\n'
                            'Not Encrypted (stored as plaintext):\n'
                            '• Your name and email address\n'
                            '• All numeric amounts\n'
                            '• Category names and emojis\n'
                            '• Dates and timestamps\n'
                            '• Boolean flags (paid/unpaid, income/expense)\n'
                            '• Wishlist URLs\n\n'
                            '⚠️ Operator Access: Hisaab uses server-side encryption. The encryption key lives on the server. While we do not read your data, the operator is technically capable of decrypting it.',
                      ),
                      const SizedBox(height: 14),
                      _PolicySection(
                        icon: Icons.pie_chart_outline_rounded,
                        title: '4. How We Use Your Data',
                        content:
                            'We use your data for:\n'
                            '• Providing the app (storing and displaying records)\n'
                            '• Account authentication\n'
                            '• Sending transactional emails (verification, resets)\n'
                            '• Security monitoring and rate limiting\n'
                            '• Responding to support requests\n\n'
                            'We do not use your data for advertising, profiling, or sale to third parties. We have no advertising partners.',
                      ),
                      const SizedBox(height: 14),
                      _PolicySection(
                        icon: Icons.cloud_outlined,
                        title: '5. Where Your Data Is Stored',
                        content:
                            '• Database (Neon/AWS): ap-southeast-1 (Singapore)\n'
                            '• API Server (Render): Oregon, USA\n'
                            '• Email Delivery (Brevo): European Union (France)\n\n'
                            'Your data is transmitted over HTTPS at all times. Transfers to third countries are covered by Data Processing Agreements and Standard Contractual Clauses.',
                      ),
                      const SizedBox(height: 14),
                      _PolicySection(
                        icon: Icons.access_time_rounded,
                        title: '6. Data Retention',
                        content:
                            '• Your account and financial records are retained until you delete your account.\n'
                            '• Deleted account data is permanently erased after the 5-day grace period expires.\n'
                            '• Server access logs are purged after 30 days.\n'
                            '• Password reset / email change tokens expire in 1 hour.',
                      ),
                      const SizedBox(height: 14),
                      _PolicySection(
                        icon: Icons.delete_outline_rounded,
                        title: '7. Account Deletion & Erasure',
                        content:
                            'You can delete your account from More → Delete Account. This initiates a 5-day grace period. If you do not log in within 5 days, all your data is permanently and irreversibly deleted. There are no backups of your data after deletion.',
                      ),
                      const SizedBox(height: 14),
                      _PolicySection(
                        icon: Icons.cookie_outlined,
                        title: '8. Cookies & Local Storage',
                        content:
                            'Hisaab is a mobile app and does not use browser cookies. We use device secure storage (iOS Keychain / Android Keystore) to store your JWT access/refresh tokens. These are cleared when you log out.',
                      ),
                      const SizedBox(height: 14),
                      _PolicySection(
                        icon: Icons.gavel_rounded,
                        title: '9. Your Rights Under GDPR',
                        content:
                            'If you are in the EEA or UK, you have the right to:\n'
                            '• Access your data (view in-app)\n'
                            '• Rectify your data (update in Profile)\n'
                            '• Erasure (delete account)\n'
                            '• Data portability (email us for a JSON export)\n'
                            '• Object to or restrict processing\n'
                            '• Withdraw consent',
                      ),
                      const SizedBox(height: 14),
                      _PolicySection(
                        icon: Icons.shield_outlined,
                        title: '10. Your Rights Under CCPA',
                        content:
                            'California residents have the right to know, delete, and correct their personal information, and the right to non-discrimination. We do not sell or share your personal information. Contact us to exercise these rights.',
                      ),
                      const SizedBox(height: 14),
                      _PolicySection(
                        icon: Icons.child_care_rounded,
                        title: '11. Children\'s Privacy',
                        content:
                            'Hisaab is not directed at children under the age of 13 (or 16 in the EEA). We do not knowingly collect personal data from minors. If you believe a minor has created an account, please contact us for prompt deletion.',
                      ),
                      const SizedBox(height: 14),
                      _PolicySection(
                        icon: Icons.security_rounded,
                        title: '12. Security',
                        content:
                            'We protect your data using AES-256-GCM encryption, bcrypt hashing, JWT tokens, HTTPS, and rate limiting. However, no system is perfectly secure and we cannot guarantee absolute security.',
                      ),
                      const SizedBox(height: 14),
                      _PolicySection(
                        icon: Icons.edit_note_rounded,
                        title: '13. Changes to This Policy',
                        content:
                            'We may update this Privacy Policy from time to time. For significant changes, we will notify users via email or an in-app notice.',
                      ),
                      const SizedBox(height: 14),
                      _PolicySection(
                        icon: Icons.mail_outline_rounded,
                        title: '14. Contact Us',
                        content:
                            'If you have questions about this Privacy Policy or how we handle your data, please contact us at hisaab.app@gmail.com with the subject "Privacy Inquiry". We will respond within 14 business days.',
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

class _PolicySection extends StatelessWidget {
  const _PolicySection({
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
