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
import '../../../../core/error/failures.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'More',
              style: AppTypography.titleLarge
                  .copyWith(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700),
            ),
          ),

          // ── Sections ─────────────────────────────────────────────────────
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              MediaQuery.of(context).padding.bottom + AppSpacing.lg,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionHeader(label: 'Finance'),
                const SizedBox(height: AppSpacing.xs),
                _MenuCard(
                  items: [
                    _MenuItem(
                      icon: Icons.savings_rounded,
                      iconColor: Theme.of(context).colorScheme.secondary,
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
                      iconColor: Theme.of(context).colorScheme.tertiary,
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
                      iconColor: Theme.of(context).colorScheme.primary,
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
                      iconColor: Theme.of(context).colorScheme.primary,
                      label: 'Colorblind Mode',
                      subtitle: 'Switches income/expense to blue & orange',
                      value: ref.watch(colorblindProvider),
                      onToggle: (_) =>
                          ref.read(colorblindProvider.notifier).toggle(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionHeader(label: 'Legal'),
                const SizedBox(height: AppSpacing.xs),
                _MenuCard(
                  items: [
                    _MenuItem(
                      icon: Icons.shield_outlined,
                      iconColor: Theme.of(context).colorScheme.primary,
                      label: 'Privacy Policy',
                      subtitle: 'How we protect your data',
                      onTap: () => context.push('/privacy-policy'),
                    ),
                    _MenuItem(
                      icon: Icons.gavel_rounded,
                      iconColor: Theme.of(context).colorScheme.primary,
                      label: 'Terms of Service',
                      subtitle: 'Rules and guidelines',
                      onTap: () => context.push('/terms-of-service'),
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
                      iconColor: Theme.of(context).colorScheme.primary,
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
                    _MenuItem(
                      icon: Icons.delete_forever_rounded,
                      iconColor: const Color(0xFFDC2626),
                      label: 'Delete Account',
                      subtitle: '5-day grace period before permanent deletion',
                      onTap: () => _showDeleteAccountSheet(context, ref),
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

// ─── Delete Account Bottom Sheet ─────────────────────────────────────────────

Future<void> _showDeleteAccountSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DeleteAccountSheet(ref: ref),
  );
}

class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pw = _passwordController.text.trim();
    if (pw.isEmpty) {
      setState(() => _errorText = 'Password is required.');
      return;
    }
    setState(() { _isLoading = true; _errorText = null; });
    try {
      await widget.ref
          .read(authNotifierProvider.notifier)
          .scheduleAccountDeletion(pw);
      if (mounted) Navigator.pop(context);
    } on ServerFailure catch (e) {
      setState(() { _isLoading = false; _errorText = e.message; });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorText = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Warning header ─────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.delete_forever_rounded, color: cs.error, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete Account',
                          style: AppTypography.titleMedium.copyWith(
                            color: cs.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '5-day grace period — log in to cancel',
                          style: AppTypography.bodySmall.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Info ───────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.error.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BulletPoint(
                      icon: Icons.schedule_rounded,
                      text: 'Your account will be deleted in 5 days',
                      color: cs.onSurface,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _BulletPoint(
                      icon: Icons.restore_rounded,
                      text: 'Log in before the deadline to cancel deletion',
                      color: const Color(0xFF16A34A),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _BulletPoint(
                      icon: Icons.warning_amber_rounded,
                      text: 'All data is permanently erased after the deadline',
                      color: cs.error,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Password field ─────────────────────────────────────────────
              Text(
                'Enter your password to confirm',
                style: AppTypography.labelMedium.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Password',
                  errorText: _errorText,
                  filled: true,
                  fillColor: cs.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Buttons ───────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.error,
                        foregroundColor: cs.onError,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: cs.onError,
                              ),
                            )
                          : const Text('Delete Account'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bullet Point ─────────────────────────────────────────────────────────────

class _BulletPoint extends StatelessWidget {
  const _BulletPoint({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(color: color),
          ),
        ),
      ],
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
          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? AppColorsDark.softShadow
            : AppColors.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              Divider(height: 1, indent: 56, color: Theme.of(context).colorScheme.surfaceContainer),
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
                          .copyWith(color: Theme.of(context).colorScheme.onSurface)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: AppTypography.bodySmall
                            .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            // Chevron
            Icon(Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.outlineVariant, size: 20),
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
                        .copyWith(color: Theme.of(context).colorScheme.onSurface)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: AppTypography.bodySmall
                          .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          // Switch
          Switch(
            value: value,
            onChanged: onToggle,
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
