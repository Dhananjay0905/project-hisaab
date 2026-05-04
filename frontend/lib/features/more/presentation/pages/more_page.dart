/// MorePage — hub for Savings, Wishlist, Categories, Recurring, Profile.
/// Replaces the old "Me" placeholder tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/colorblind_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'More',
              style: AppTypography.titleLarge
                  .copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
            ),
          ),

          // ── Sections ─────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl4 * 2, // bottom padding for nav bar
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionHeader(label: 'Finance'),
                const SizedBox(height: AppSpacing.xs),
                _MenuCard(
                  items: [
                    _MenuItem(
                      icon: Icons.savings_rounded,
                      iconColor: AppColors.secondary,
                      label: 'Savings',
                      subtitle: 'Track your savings pot',
                      onTap: () => context.push('/savings'),
                    ),
                    _MenuItem(
                      icon: Icons.favorite_rounded,
                      iconColor: const Color(0xFFE91E63),
                      label: 'Wishlist',
                      subtitle: 'Items you are saving up for',
                      onTap: () => context.push('/wishlist'),
                    ),
                    _MenuItem(
                      icon: Icons.repeat_rounded,
                      iconColor: AppColors.tertiary,
                      label: 'Recurring',
                      subtitle: 'Subscriptions & regular payments',
                      onTap: () => context.push('/recurring'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionHeader(label: 'Insights'),
                const SizedBox(height: AppSpacing.xs),
                _MenuCard(
                  items: [
                    _MenuItem(
                      icon: Icons.bar_chart_rounded,
                      iconColor: const Color(0xFF6C63FF),
                      label: 'Analytics',
                      subtitle: 'Spending trends & category breakdown',
                      onTap: () => context.push('/analytics'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionHeader(label: 'Manage'),
                const SizedBox(height: AppSpacing.xs),
                _MenuCard(
                  items: [
                    _MenuItem(
                      icon: Icons.label_rounded,
                      iconColor: AppColors.primary,
                      label: 'Categories',
                      subtitle: 'Add or remove categories',
                      onTap: () => context.push('/categories'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionHeader(label: 'Accessibility'),
                const SizedBox(height: AppSpacing.xs),
                _MenuCard(
                  items: [
                    _ToggleMenuItem(
                      icon: Icons.palette_rounded,
                      iconColor: AppColors.primary,
                      label: 'Colorblind Mode',
                      subtitle: 'Switches income/expense to blue & orange',
                      value: ref.watch(colorblindProvider),
                      onToggle: (_) =>
                          ref.read(colorblindProvider.notifier).toggle(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionHeader(label: 'Account'),
                const SizedBox(height: AppSpacing.xs),
                _MenuCard(
                  items: [
                    _MenuItem(
                      icon: Icons.person_rounded,
                      iconColor: AppColors.primary,
                      label: 'Profile & Settings',
                      subtitle: 'Edit name and account details',
                      onTap: () => context.push('/profile'),
                    ),
                    _MenuItem(
                      icon: Icons.logout_rounded,
                      iconColor: const Color(0xFFE53935),
                      label: 'Sign Out',
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: const Text('Sign Out'),
                            content: const Text(
                              'Are you sure you want to sign out?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFE53935),
                                ),
                                child: const Text('Sign Out'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ref
                              .read(authNotifierProvider.notifier)
                              .logout();
                        }
                      },
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: 2),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─── Menu Card (groups items with dividers) ───────────────────────────────────

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.items});
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        boxShadow: AppColors.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              const Divider(height: 1, indent: 56, color: AppColors.surfaceContainer),
          ],
        ],
      ),
    );
  }
}

// ─── Menu Item ────────────────────────────────────────────────────────────────

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: [
            // Icon chip
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.md),
            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTypography.titleSmall
                          .copyWith(color: AppColors.onSurface)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            // Chevron
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.outlineVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Toggle Menu Item ─────────────────────────────────────────────────────────

class _ToggleMenuItem extends StatelessWidget {
  const _ToggleMenuItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onToggle,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          // Icon chip
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.md),
          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.titleSmall
                        .copyWith(color: AppColors.onSurface)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          // Switch
          Switch(
            value: value,
            onChanged: onToggle,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
