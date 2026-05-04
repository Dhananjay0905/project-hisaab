/// Analytics Page — More → Analytics
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/colorblind_provider.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../domain/entities/analytics_entities.dart';
import '../providers/analytics_provider.dart';

// ─── Page ─────────────────────────────────────────────────────────────────────

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  late int _year;
  late int _month; // 1-based

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year  = now.year;
    _month = now.month;
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _year == now.year && _month == now.month;
  }

  void _shiftMonth(int delta) {
    setState(() {
      var m = _month + delta;
      var y = _year;
      if (m < 1)  { m += 12; y--; }
      if (m > 12) { m -= 12; y++; }
      // Don't go into the future
      final now = DateTime.now();
      if (y > now.year || (y == now.year && m > now.month)) return;
      _month = m;
      _year  = y;
    });
  }

  String get _monthLabel {
    const names = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final now = DateTime.now();
    if (_isCurrentMonth) return 'This Month';
    if (_year == now.year) return names[_month];
    return '${names[_month]} $_year';
  }

  Future<void> _handleRefresh() async {
    final ym = _isCurrentMonth ? (null, null) : (_year, _month) as YearMonth;
    ref.invalidate(categorySpendProvider(ym));
    // Wait for the new data to load
    await ref.read(categorySpendProvider(ym).future).catchError((_) => <CategorySpend>[]);
  }

  @override
  Widget build(BuildContext context) {
    // For the current month we use (null, null) so the budget-check provider
    // can share the same cached instance.
    final ym = _isCurrentMonth ? (null, null) : (_year, _month) as YearMonth;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              leading: const BackButton(),
              title: Text('Analytics',
                  style: AppTypography.titleLarge.copyWith(
                      color: AppColors.onSurface, fontWeight: FontWeight.w700)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl4 * 2),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Month selector ──────────────────────────────────────────
                  _MonthSelector(
                    label: _monthLabel,
                    onPrev: () => _shiftMonth(-1),
                    onNext: _isCurrentMonth ? null : () => _shiftMonth(1),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── Category donut + breakdown ──────────────────────────────
                  _CategoryDonutSection(ym: ym),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Monthly bar chart (always last 6 months) ────────────────
                  _SectionTitle(title: 'Income vs Expense (Last 6 Months)'),
                  const SizedBox(height: AppSpacing.md),
                  _MonthlyTrendSection(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Month selector widget ────────────────────────────────────────────────────

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.label, required this.onPrev, this.onNext});
  final String label;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        boxShadow: AppColors.softShadow,
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: onPrev,
            color: AppColors.onSurface,
          ),
          Expanded(
            child: Text(label,
                textAlign: TextAlign.center,
                style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: onNext,
            color: onNext != null ? AppColors.onSurface : AppColors.outlineVariant,
          ),
        ],
      ),
    );
  }
}

// ─── Section title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(title,
      style: AppTypography.titleMedium.copyWith(
          color: AppColors.onSurface, fontWeight: FontWeight.w700));
}

// ─── Donut + breakdown section ────────────────────────────────────────────────

class _CategoryDonutSection extends ConsumerWidget {
  const _CategoryDonutSection({required this.ym});
  final YearMonth ym;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spendAsync = ref.watch(categorySpendProvider(ym));
    return spendAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorBox(message: 'Could not load category data.'),
      data: (categories) {
        final relevant = categories.where((c) => c.spent > 0).toList()
          ..sort((a, b) => b.spent.compareTo(a.spent));
        if (relevant.isEmpty) {
          return _EmptyState(message: 'No expenses recorded for this month.');
        }
        return _DonutWithBreakdown(categories: relevant);
      },
    );
  }
}

// ─── Colors ───────────────────────────────────────────────────────────────────

const _kCategoryColors = [
  Color(0xFF6C63FF), Color(0xFF43B89C), Color(0xFFFF7043), Color(0xFF42A5F5),
  Color(0xFFFFB300), Color(0xFFEC407A), Color(0xFF26A69A), Color(0xFF7E57C2),
  Color(0xFF66BB6A), Color(0xFFEF5350), Color(0xFF29B6F6), Color(0xFFFF8F00),
  Color(0xFF9C27B0), Color(0xFF00897B), Color(0xFFD84315), Color(0xFF1565C0),
  Color(0xFF558B2F), Color(0xFFAD1457), Color(0xFF4527A0), Color(0xFF00695C),
];

// ─── Donut + full list ────────────────────────────────────────────────────────

class _DonutWithBreakdown extends ConsumerStatefulWidget {
  const _DonutWithBreakdown({required this.categories});
  final List<CategorySpend> categories;

  @override
  ConsumerState<_DonutWithBreakdown> createState() => _DonutWithBreakdownState();
}

class _DonutWithBreakdownState extends ConsumerState<_DonutWithBreakdown> {
  int _touchedIndex = -1;
  static const _donutMaxSlices = 7;

  @override
  Widget build(BuildContext context) {
    final cats  = widget.categories;
    final total = cats.fold(0.0, (s, c) => s + c.spent);
    final fmt   = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final fmtC  = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final topCats   = cats.length <= _donutMaxSlices ? cats : cats.take(_donutMaxSlices).toList();
    final otherCats = cats.length > _donutMaxSlices  ? cats.skip(_donutMaxSlices).toList() : <CategorySpend>[];
    final othersSpent = otherCats.fold(0.0, (s, c) => s + c.spent);

    final sections = <PieChartSectionData>[
      for (int i = 0; i < topCats.length; i++)
        PieChartSectionData(
          value: topCats[i].spent,
          color: _kCategoryColors[i % _kCategoryColors.length],
          radius: _touchedIndex == i ? 50 : 38,
          showTitle: false,
        ),
      if (othersSpent > 0)
        PieChartSectionData(
          value: othersSpent,
          color: const Color(0xFFBDBDBD),
          radius: _touchedIndex == topCats.length ? 50 : 38,
          showTitle: false,
        ),
    ];

    String centerTop    = fmt.format(total);
    String centerBottom = 'total spent';
    if (_touchedIndex >= 0 && _touchedIndex < topCats.length) {
      centerTop    = fmt.format(topCats[_touchedIndex].spent);
      centerBottom = '${topCats[_touchedIndex].emoji} ${topCats[_touchedIndex].name}';
    } else if (_touchedIndex == topCats.length && othersSpent > 0) {
      centerTop    = fmt.format(othersSpent);
      centerBottom = '🗂️ Others';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Donut card ─────────────────────────────────────────────────────────
      Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          boxShadow: AppColors.softShadow,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(children: [
          SizedBox(
            height: 210,
            child: Stack(alignment: Alignment.center, children: [
              PieChart(PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 62,
                sections: sections,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response?.touchedSection == null) {
                        _touchedIndex = -1;
                      } else {
                        _touchedIndex =
                            response!.touchedSection!.touchedSectionIndex;
                      }
                    });
                  },
                ),
              )),
              GestureDetector(
                onTap: () => setState(() => _touchedIndex = -1),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(centerTop,
                      style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w800, color: AppColors.onSurface)),
                  Text(centerBottom,
                      style: AppTypography.labelSmall
                          .copyWith(color: AppColors.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Pill legend
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (int i = 0; i < topCats.length; i++)
              _PillLegend(
                color: _kCategoryColors[i % _kCategoryColors.length],
                label: '${topCats[i].emoji} ${topCats[i].name}',
                isActive: _touchedIndex == i,
                onTap: () => setState(
                    () => _touchedIndex = _touchedIndex == i ? -1 : i),
              ),
            if (othersSpent > 0)
              _PillLegend(
                color: const Color(0xFFBDBDBD),
                label: '🗂️ Others (${otherCats.length})',
                isActive: _touchedIndex == topCats.length,
                onTap: () => setState(() => _touchedIndex =
                    _touchedIndex == topCats.length ? -1 : topCats.length),
              ),
          ]),
        ]),
      ),

      const SizedBox(height: AppSpacing.md),

      // ── Category breakdown list ─────────────────────────────────────────────
      Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          boxShadow: AppColors.softShadow,
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(children: [
              Text('Category Breakdown',
                  style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700, color: AppColors.onSurface)),
              const Spacer(),
              Text('${cats.length} categories',
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ]),
          ),
          const Divider(height: 1, color: AppColors.surfaceContainer),
          const SizedBox(height: AppSpacing.xs),
          for (int i = 0; i < cats.length; i++) ...[
            _CategoryBreakdownRow(
              category: cats[i],
              color: i < _donutMaxSlices
                  ? _kCategoryColors[i % _kCategoryColors.length]
                  : const Color(0xFFBDBDBD),
              total: total,
              fmt: fmt,
              fmtCompact: fmtC,
            ),
            if (i < cats.length - 1)
              const Divider(height: 1, indent: 52,
                  color: AppColors.surfaceContainer),
          ],
          const SizedBox(height: AppSpacing.xs),
        ]),
      ),
    ]);
  }
}

// ─── Pill legend ──────────────────────────────────────────────────────────────

class _PillLegend extends StatelessWidget {
  const _PillLegend(
      {required this.color, required this.label,
       required this.isActive, required this.onTap});
  final Color color;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? color
                  : AppColors.outlineVariant.withValues(alpha: 0.4),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(label,
                style: AppTypography.labelSmall.copyWith(
                    color: isActive ? color : AppColors.onSurfaceVariant,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.w400)),
          ]),
        ),
      );
}

// ─── Category breakdown row ───────────────────────────────────────────────────

class _CategoryBreakdownRow extends ConsumerWidget {
  const _CategoryBreakdownRow({
    required this.category, required this.color, required this.total,
    required this.fmt, required this.fmtCompact,
  });
  final CategorySpend category;
  final Color color;
  final double total;
  final NumberFormat fmt;
  final NumberFormat fmtCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isColorblind = ref.watch(colorblindProvider);
    final sem = SemanticColors.of(context);
    final pct = total > 0 ? category.spent / total : 0.0;

    final barProgress = category.hasLimit
        ? (category.spent / category.limit!).clamp(0.0, 1.0)
        : pct.clamp(0.0, 1.0);
    final barColor = category.hasLimit && category.isAtLimit
        ? (isColorblind ? sem.cashOut : const Color(0xFFE53935))
        : color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
              child: Text(category.emoji,
                  style: const TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(category.name,
                    style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 4),
              if (category.hasLimit) ...[
                _LimitChip(spent: category.spent, limit: category.limit!),
                const SizedBox(width: 4),
              ],
              Text('${(pct * 100).toStringAsFixed(1)}%',
                  style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 5),
            LayoutBuilder(builder: (context, constraints) => Stack(children: [
              Container(height: 6, width: constraints.maxWidth,
                  decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(4))),
              AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  height: 6,
                  width: constraints.maxWidth * barProgress,
                  decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(4))),
            ])),
            const SizedBox(height: 3),
            if (category.hasLimit)
              Text(
                '${fmtCompact.format(category.spent)} / ${fmtCompact.format(category.limit!)} limit',
                style: AppTypography.labelSmall.copyWith(
                    color: AppColors.onSurfaceVariant, fontSize: 10),
              )
            else
              Text('of ${fmt.format(total)} total',
                  style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onSurfaceVariant, fontSize: 10)),
          ]),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(fmtCompact.format(category.spent),
            style: AppTypography.labelMedium.copyWith(
                color: AppColors.onSurface, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _LimitChip extends ConsumerWidget {
  const _LimitChip({required this.spent, required this.limit});
  final double spent;
  final double limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isColorblind = ref.watch(colorblindProvider);
    final sem  = SemanticColors.of(context);
    final isOver = spent >= limit;
    final color = isOver
        ? (isColorblind ? sem.cashOut : const Color(0xFFE53935))
        : (isColorblind ? sem.cashIn  : const Color(0xFF2E7D32));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5)),
      child: Text('${(spent / limit * 100).round()}%',
          style: AppTypography.labelSmall.copyWith(
              color: color, fontWeight: FontWeight.w700, fontSize: 10)),
    );
  }
}

// ─── Monthly bar chart ────────────────────────────────────────────────────────

class _MonthlyTrendSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(monthlyTrendProvider);
    return trendAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorBox(message: 'Could not load trend data.'),
      data: (months) {
        if (!months.any((m) => m.income > 0 || m.expense > 0)) {
          return _EmptyState(message: 'No transaction data available yet.');
        }
        return _BarChartCard(months: months);
      },
    );
  }
}

class _BarChartCard extends ConsumerWidget {
  const _BarChartCard({required this.months});
  final List<MonthlySummary> months;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isColorblind = ref.watch(colorblindProvider);
    final sem = SemanticColors.of(context);
    final incomeColor  = isColorblind ? sem.cashIn  : const Color(0xFF2E7D32);
    final expenseColor = isColorblind ? sem.cashOut : const Color(0xFFE53935);

    double maxY = months.fold(0.0,
        (p, m) => [p, m.income, m.expense].reduce((a, b) => a > b ? a : b));
    maxY = (maxY * 1.25).ceilToDouble();
    if (maxY <= 0) maxY = 10000;

    final fmt = NumberFormat.compactCurrency(
        locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final groups = months.asMap().entries.map((entry) {
      final i = entry.key;
      final m = entry.value;
      return BarChartGroupData(x: i, barsSpace: 4, barRods: [
        BarChartRodData(toY: m.income,  color: incomeColor,  width: 10,
            borderRadius: BorderRadius.circular(4)),
        BarChartRodData(toY: m.expense, color: expenseColor, width: 10,
            borderRadius: BorderRadius.circular(4)),
      ]);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        boxShadow: AppColors.softShadow,
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _LegendDot(color: incomeColor,  label: 'Income'),
          const SizedBox(width: AppSpacing.md),
          _LegendDot(color: expenseColor, label: 'Expense'),
        ]),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 220,
          child: BarChart(BarChartData(
            maxY: maxY,
            gridData: FlGridData(
              show: true, drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: AppColors.surfaceContainer, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 52,
                getTitlesWidget: (val, _) => Text(fmt.format(val),
                    style: AppTypography.labelSmall.copyWith(
                        color: AppColors.onSurfaceVariant, fontSize: 9)),
              )),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, _) {
                  final idx = val.toInt();
                  if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(months[idx].month,
                        style: AppTypography.labelSmall.copyWith(
                            color: AppColors.onSurfaceVariant, fontSize: 9)),
                  );
                },
              )),
            ),
            barGroups: groups,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, rodIdx) {
                  final m     = months[group.x];
                  final label = rodIdx == 0 ? 'Income' : 'Expense';
                  final value = rodIdx == 0 ? m.income  : m.expense;
                  return BarTooltipItem('$label\n${fmt.format(value)}',
                      AppTypography.labelSmall.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700));
                },
              ),
            ),
          )),
        ),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.labelSmall
            .copyWith(color: AppColors.onSurfaceVariant)),
      ]);
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Text(message,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center),
        ),
      );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        child: Text(message,
            style: AppTypography.bodySmall
                .copyWith(color: const Color(0xFFE53935))),
      );
}
