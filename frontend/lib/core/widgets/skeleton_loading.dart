import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_spacing.dart';

// ─── Core Shimmer Wrapper ───────────────────────────────────────────────────

class SkeletonLoader extends StatelessWidget {
  final Widget child;

  const SkeletonLoader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Premium theme-aware background/foreground shimmer colors
    final baseColor = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFE5E7EB);
    final highlightColor = isDark
        ? const Color(0xFF3A3A3C)
        : const Color(0xFFF3F4F6);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: child,
    );
  }
}

// ─── Primitive Skeleton Shapes ──────────────────────────────────────────────

class SkeletonBlock extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBlock({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─── Page-Specific Skeleton Layouts ─────────────────────────────────────────

// 1. HOME SKELETON
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.sm),
            // Balance Card Placeholder
            const SkeletonBlock(height: 160, borderRadius: 24),
            const SizedBox(height: AppSpacing.lg),
            // Month Stats Row Placeholder
            Row(
              children: [
                Expanded(child: const SkeletonBlock(height: 72, borderRadius: 16)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: const SkeletonBlock(height: 72, borderRadius: 16)),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            // Recent Transactions Header
            const SkeletonBlock(height: 20, width: 140, borderRadius: 4),
            const SizedBox(height: AppSpacing.sm),
            // 3 Transaction Tiles Skeletons
            for (int i = 0; i < 3; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    const SkeletonCircle(size: 44),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SkeletonBlock(height: 14, width: 120, borderRadius: 4),
                          const SizedBox(height: 6),
                          const SkeletonBlock(height: 10, width: 80, borderRadius: 4),
                        ],
                      ),
                    ),
                    const SkeletonBlock(height: 16, width: 60, borderRadius: 4),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            const SizedBox(height: AppSpacing.xl),
            // Top Spending Header
            const SkeletonBlock(height: 20, width: 100, borderRadius: 4),
            const SizedBox(height: AppSpacing.sm),
            // Top Spending Category Rows Skeletons
            for (int i = 0; i < 2; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    const SkeletonBlock(height: 14, width: 80, borderRadius: 4),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: const SkeletonBlock(height: 8, borderRadius: 4),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const SkeletonBlock(height: 14, width: 30, borderRadius: 4),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

// 2. TRANSACTIONS SKELETON
class TransactionsSkeleton extends StatelessWidget {
  const TransactionsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // Section Header 1
          const SizedBox(height: AppSpacing.sm),
          const SkeletonBlock(height: 18, width: 80, borderRadius: 4),
          const SizedBox(height: AppSpacing.md),
          // 2 Transaction items
          for (int i = 0; i < 2; i++) ...[
            Row(
              children: [
                const SkeletonCircle(size: 44),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SkeletonBlock(height: 14, width: 120, borderRadius: 4),
                      const SizedBox(height: 6),
                      const SkeletonBlock(height: 10, width: 80, borderRadius: 4),
                    ],
                  ),
                ),
                const SkeletonBlock(height: 16, width: 60, borderRadius: 4),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Section Header 2
          const SizedBox(height: AppSpacing.sm),
          const SkeletonBlock(height: 18, width: 90, borderRadius: 4),
          const SizedBox(height: AppSpacing.md),
          // 3 Transaction items
          for (int i = 0; i < 3; i++) ...[
            Row(
              children: [
                const SkeletonCircle(size: 44),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SkeletonBlock(height: 14, width: 140, borderRadius: 4),
                      const SizedBox(height: 6),
                      const SkeletonBlock(height: 10, width: 70, borderRadius: 4),
                    ],
                  ),
                ),
                const SkeletonBlock(height: 16, width: 50, borderRadius: 4),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

// 2b. COMPACT TRANSACTIONS SKELETON (for calendar view details)
class CompactTransactionListSkeleton extends StatelessWidget {
  const CompactTransactionListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: 3,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              const SkeletonCircle(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBlock(height: 14, width: 120, borderRadius: 4),
                    const SizedBox(height: 6),
                    const SkeletonBlock(height: 10, width: 80, borderRadius: 4),
                  ],
                ),
              ),
              const SkeletonBlock(height: 16, width: 50, borderRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// 3. SAVINGS SKELETON
class SavingsSkeleton extends StatelessWidget {
  const SavingsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverFillRemaining(
      hasScrollBody: false,
      child: SkeletonLoader(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Card
            SkeletonBlock(height: 160, borderRadius: 24),
            SizedBox(height: AppSpacing.md),
            // Spendable Toggle
            SkeletonBlock(height: 56, borderRadius: 16),
            SizedBox(height: AppSpacing.md),
            // Cash Deduction Card
            SkeletonBlock(height: 56, borderRadius: 16),
            SizedBox(height: AppSpacing.lg),
            // Contribution Header
            SkeletonBlock(height: 20, width: 150, borderRadius: 4),
            SizedBox(height: AppSpacing.sm),
            // Goal list skeletons
            SkeletonBlock(height: 96, borderRadius: 16),
            SizedBox(height: AppSpacing.sm),
            SkeletonBlock(height: 96, borderRadius: 16),
          ],
        ),
      ),
    );
  }
}

// 4. WISHLIST SKELETON
class WishlistSkeleton extends StatelessWidget {
  const WishlistSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverFillRemaining(
      hasScrollBody: false,
      child: SkeletonLoader(
        child: Padding(
          padding: EdgeInsets.only(top: AppSpacing.sm),
          child: Column(
            children: [
              SkeletonBlock(height: 120, borderRadius: 16),
              SizedBox(height: AppSpacing.sm),
              SkeletonBlock(height: 120, borderRadius: 16),
              SizedBox(height: AppSpacing.sm),
              SkeletonBlock(height: 120, borderRadius: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// 5. DUES SKELETON
class DuesSkeleton extends StatelessWidget {
  const DuesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverFillRemaining(
      hasScrollBody: false,
      child: SkeletonLoader(
        child: Padding(
          padding: EdgeInsets.only(top: AppSpacing.md),
          child: Column(
            children: [
              SkeletonBlock(height: 88, borderRadius: 16),
              SizedBox(height: AppSpacing.sm),
              SkeletonBlock(height: 88, borderRadius: 16),
              SizedBox(height: AppSpacing.sm),
              SkeletonBlock(height: 88, borderRadius: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// 6. RECURRING SKELETON
class RecurringSkeleton extends StatelessWidget {
  const RecurringSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverFillRemaining(
      hasScrollBody: false,
      child: SkeletonLoader(
        child: Padding(
          padding: EdgeInsets.only(top: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBlock(height: 16, width: 80, borderRadius: 4),
              SizedBox(height: AppSpacing.sm),
              SkeletonBlock(height: 80, borderRadius: 16),
              SizedBox(height: AppSpacing.sm),
              SkeletonBlock(height: 80, borderRadius: 16),
              SizedBox(height: AppSpacing.sm),
              SkeletonBlock(height: 80, borderRadius: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// 7. CATEGORIES SKELETON
class CategoriesSkeleton extends StatelessWidget {
  const CategoriesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: SkeletonLoader(
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBlock(height: 16, width: 70, borderRadius: 4),
              const SizedBox(height: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const SkeletonCircle(size: 32),
                            const SizedBox(width: 12),
                            const SkeletonBlock(height: 14, width: 100, borderRadius: 4),
                            const Spacer(),
                            const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                          ],
                        ),
                      ),
                      if (i < 2) const Divider(height: 1, indent: 60),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SkeletonBlock(height: 16, width: 70, borderRadius: 4),
              const SizedBox(height: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const SkeletonCircle(size: 32),
                            const SizedBox(width: 12),
                            const SkeletonBlock(height: 14, width: 100, borderRadius: 4),
                            const Spacer(),
                            const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                          ],
                        ),
                      ),
                      if (i < 2) const Divider(height: 1, indent: 60),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 8. DONUT SKELETON (for Analytics)
class DonutSkeleton extends StatelessWidget {
  const DonutSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Donut circle placeholder
            const Center(child: SkeletonCircle(size: 140)),
            const SizedBox(height: 24),
            // Breakdown list placeholders
            for (int i = 0; i < 3; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    const SkeletonCircle(size: 24),
                    const SizedBox(width: 12),
                    const SkeletonBlock(height: 14, width: 80, borderRadius: 4),
                    const Spacer(),
                    const SkeletonBlock(height: 14, width: 60, borderRadius: 4),
                  ],
                ),
              ),
              if (i < 2) const Divider(height: 1, indent: 36),
            ],
          ],
        ),
      ),
    );
  }
}

// 9. TREND SKELETON (for Analytics)
class TrendSkeleton extends StatelessWidget {
  const TrendSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: Container(
        height: 280,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SkeletonBlock(height: 16, width: 100, borderRadius: 4),
                Row(
                  children: [
                    const SkeletonBlock(height: 12, width: 40, borderRadius: 4),
                    const SizedBox(width: 8),
                    const SkeletonBlock(height: 12, width: 40, borderRadius: 4),
                  ],
                ),
              ],
            ),
            const Spacer(),
            // 6 Bars placeholders of varying heights
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _bar(60),
                _bar(120),
                _bar(80),
                _bar(150),
                _bar(100),
                _bar(130),
              ],
            ),
            const SizedBox(height: 8),
            // X axis labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                6,
                (_) => const SkeletonBlock(height: 10, width: 24, borderRadius: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(double height) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SkeletonBlock(height: height, width: 10, borderRadius: 4),
        const SizedBox(width: 4),
        SkeletonBlock(height: height * 0.7, width: 10, borderRadius: 4),
      ],
    );
  }
}
