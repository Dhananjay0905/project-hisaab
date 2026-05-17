/// Frosted-glass bottom navigation bar with 4 tabs + centre Add FAB.
/// The Add button navigates to /add-transaction (full screen, outside shell).
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onAddPressed,
  });

  /// 0 = Home, 1 = History, 2 = Dues, 3 = More
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAddPressed;

  static const _tabs = [
    _NavItem(icon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.receipt_long_rounded, label: 'History'),
    _NavItem(icon: Icons.handshake_rounded, label: 'Dues'),
    _NavItem(icon: Icons.grid_view_rounded, label: 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: AppSpacing.bottomNavHeight + bottom,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest.withValues(alpha: 0.90),
            border: Border(
              top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Tab 0: Home
                _buildTab(context, 0),
                // Tab 1: History
                _buildTab(context, 1),
                // Centre: Add FAB
                _AddButton(onPressed: onAddPressed),
                // Tab 2: Stats
                _buildTab(context, 2),
                // Tab 3: Me
                _buildTab(context, 3),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildTab(BuildContext context, int index) {
    // Map visual position to logical index (skipping centre FAB slot)
    // positions: 0→0, 1→1, [FAB], 2→2, 3→3
    final selected = currentIndex == index;
    final item = _tabs[index];
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTabSelected(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? cs.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.xl4),
              ),
              child: Icon(
                item.icon,
                size: 24,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: AppTypography.navLabel.copyWith(
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: isDark ? AppColorsDark.primaryGradient : AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppSpacing.lg),
            boxShadow: [
              BoxShadow(
                color: (isDark
                        ? const Color(0xFF3A5CC5)
                        : const Color(0xFF3861FB))
                    .withValues(alpha: isDark ? 0.25 : 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
