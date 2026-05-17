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
                            'Hisaab is a personal finance tracking app built and operated by its developer for private use among a group of trusted users. We are not a registered business. You can reach us at the contact information provided in the app.',
                      ),
                      const SizedBox(height: 14),
                      _PolicySection(
                        icon: Icons.folder_outlined,
                        title: '2. What Data We Collect',
                        content:
                            '• Your name and email address (for your account)\n'
                            '• A bcrypt hash of your password (we never store the plaintext)\n'
                            '• Financial records you enter: transactions, dues, splits, savings, wishlist items, recurring items\n'
                            '• Your currency preference and opening balance\n'
                            '• Server logs: IP address, request path, HTTP method, timestamp — retained for 30 days\n'
                            '• Your IP address is temporarily tracked in-memory to enforce rate limits and brute-force protection',
                      ),
                      const SizedBox(height: 14),
                      _PolicySection(
                        icon: Icons.lock_outline_rounded,
                        title: '3. What Is Encrypted',
                        content:
                            'Encrypted with AES-256-GCM:\n'
                            '• Transaction titles & notes\n'
                            '• Due titles, person names & notes\n'
                            '• Split titles, notes & participant names\n'
                            '• Wishlist item titles\n'
                            '• Recurring transaction titles\n\n'
                            'Stored as plaintext:\n'
                            '• Your name and email\n'
                            '• All numeric amounts (required for aggregations)\n'
                            '• Category names, dates, status flags\n\n'
                            '⚠️ Hisaab uses server-side encryption, not end-to-end encryption. The operator can technically decrypt encrypted fields.',
                      ),
                      const SizedBox(height: 14),
                      _PolicySection(
                        icon: Icons.key_outlined,
                        title: '4. Authentication & Sessions',
                        content:
                            '• Passwords are hashed with bcrypt (cost factor 12) — we cannot recover your password\n'
                            '• Access tokens (JWT): valid for 15 minutes\n'
                            '• Refresh tokens: valid for 30 days, stored as hashed records\n'
                            '• Both tokens are invalidated on logout and account deletion',
                      ),
                      const SizedBox(height: 14),
                      _PolicySection(
                        icon: Icons.gavel_rounded,
                        title: '5. Your Rights (GDPR & CCPA)',
                        content:
                            '• Right to Access: request a copy of your data\n'
                            '• Right to Deletion: delete your account (5-day grace period)\n'
                            '• Right to Rectification: update your name and email in-app\n'
                            '• Right to Portability: contact the developer for a data export\n'
                            '• We do not sell, share, or use your data for advertising',
                      ),
                      const SizedBox(height: 14),
                      _PolicySection(
                        icon: Icons.cookie_outlined,
                        title: '6. Cookies',
                        content:
                            'The Hisaab mobile app does not use cookies. Session tokens are stored in your device\'s secure storage (Android Keystore / iOS Keychain). The backend does not set any cookies.',
                      ),
                      const SizedBox(height: 14),
                      _PolicySection(
                        icon: Icons.cloud_outlined,
                        title: '7. Where Data Is Stored',
                        content:
                            '• Database: PostgreSQL hosted on Neon (Neon Tech, Inc.)\n'
                            '  Region: AWS ap-southeast-1 (Singapore)\n'
                            '• Backend: Node.js server hosted on Render\n'
                            '  Region: Oregon, USA\n'
                            '• Email delivery: Brevo (Sendinblue S.A.S., France)\n\n'
                            'Data is transmitted over HTTPS (TLS 1.2+) at all times.',
                      ),
                      const SizedBox(height: 14),
                      _PolicySection(
                        icon: Icons.edit_note_rounded,
                        title: '8. Changes to This Policy',
                        content:
                            'If we make material changes to this policy, existing users will be prompted to review and accept the updated version before using the app again.',
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
