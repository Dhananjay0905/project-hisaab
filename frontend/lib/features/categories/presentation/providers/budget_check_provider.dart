/// Budget check provider.
///
/// Given a categoryId and an amount, returns whether the transaction
/// would hit or exceed the category's monthly budget.
///
/// This is a **synchronous** Provider — it reads the already-cached
/// [categorySpendProvider] value so the warning appears instantly
/// as the user types, with zero network latency.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../analytics/presentation/providers/analytics_provider.dart';
import '../../presentation/providers/categories_provider.dart';

enum BudgetStatus { ok, warning, exceeded }

class BudgetCheckResult {
  const BudgetCheckResult({
    required this.status,
    required this.currentSpent,
    required this.limit,
    required this.categoryName,
  });

  final BudgetStatus status;
  final double currentSpent;
  final double limit;
  final String categoryName;

  /// True if a banner should be shown.
  bool get shouldWarn => status != BudgetStatus.ok;

  String get message {
    switch (status) {
      case BudgetStatus.exceeded:
        return '⚠️ $categoryName: You\'ve already exceeded your ₹${limit.toStringAsFixed(0)} limit this month!';
      case BudgetStatus.warning:
        return '⚠️ $categoryName: This transaction will put you over your ₹${limit.toStringAsFixed(0)} monthly limit.';
      case BudgetStatus.ok:
        return '';
    }
  }
}

/// Synchronous family provider: args = (categoryId, amount).
///
/// Returns [null] when:
///   - No category / amount supplied.
///   - Category has no limit.
///   - Spend data hasn't finished loading yet (will recompute when it does).
///
/// Returns a [BudgetCheckResult] immediately using cached data — no API call.
final budgetCheckProvider = Provider.autoDispose
    .family<BudgetCheckResult?, (String?, double)>((ref, args) {
  final (categoryId, amount) = args;
  if (categoryId == null || amount <= 0) return null;

  // ── 1. Check if the selected category has a limit ────────────────────────
  final categoriesAsync = ref.watch(categoriesProvider);
  final categories = categoriesAsync.valueOrNull;
  if (categories == null) return null;

  final category = categories.where((c) => c.id == categoryId).firstOrNull;
  if (category == null || !category.hasLimit) return null;
  if (category.isIncome) return null; // limits only apply to EXPENSE

  final limit = category.monthlyLimit!;

  // ── 2. Read cached spend data (synchronous — no await) ───────────────────
  // categorySpendProvider((null,null)) is the current-month family member.
  // It is NOT autoDispose so it stays alive all session, meaning budget checks
  // read the cached value instantly once the first call resolves.
  final spendAsync = ref.watch(categorySpendProvider((null, null)));
  final spendList = spendAsync.valueOrNull;
  // If the data hasn't arrived yet just hide the banner (no delay for the user
  // on first open — the data loads in < 500 ms and the banner redraws).
  if (spendList == null) return null;

  final spend = spendList.where((c) => c.categoryId == categoryId).firstOrNull;
  final currentSpent = spend?.spent ?? 0.0;

  final wouldBe = currentSpent + amount;

  final BudgetStatus status;
  if (currentSpent >= limit) {
    status = BudgetStatus.exceeded;
  } else if (wouldBe > limit) {
    status = BudgetStatus.warning;
  } else {
    status = BudgetStatus.ok;
  }

  return BudgetCheckResult(
    status: status,
    currentSpent: currentSpent,
    limit: limit,
    categoryName: category.name,
  );
});
