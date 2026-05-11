/**
 * Summary Service
 *
 * Computes the financial dashboard data for a user in a single efficient
 * Prisma $transaction call. All amounts are plain Decimal — no decryption
 * needed for aggregation. Only recentTransactions need title decryption.
 *
 * Exclusion rule:
 *  "excludeFromAnalytics" affects ONLY charts/analytics (the Analytics page).
 *  The balance (currentBalance, totalIncome, totalExpenses) always counts
 *  every non-deleted transaction — excluded or not.
 *  The dashboard month stats and topCategories omit excluded transactions
 *  since those are "insight" numbers like the Analytics page.
 */

const { PrismaClient } = require('@prisma/client');
const { decrypt } = require('../utils/encrypt');

const prisma = new PrismaClient();

function _safeDecrypt(val) {
  try { return val ? decrypt(val) : null; } catch (_) { return '[encrypted]'; }
}

async function getSummary(userId) {
  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);

  // ── Get excluded category IDs (category-level exclusion) ──────────────────
  const excludedCats = await prisma.category.findMany({
    where: { userId, excludeFromAnalytics: true },
    select: { id: true },
  });
  const excludedCatIds = excludedCats.map((c) => c.id);

  // Analytics exclusion filter — applied only to "insight" numbers (month stats,
  // top categories). NOT applied to balance aggregates.
  const analyticsFilter = {
    excludeFromAnalytics: false,
    ...(excludedCatIds.length > 0
      ? { categoryId: { notIn: excludedCatIds } }
      : {}),
  };

  // ── Balance base filters (NO exclusion — excluded txns still affect balance) ──
  const balanceWhere = { userId, deletedAt: null };

  // ── Month analytics filters (WITH exclusion — insight numbers only) ────────
  const monthAnalyticsWhere = { userId, deletedAt: null, date: { gte: monthStart, lte: monthEnd }, ...analyticsFilter };

  // Recent transactions are shown regardless of exclusion
  const recentWhere = { userId, deletedAt: null };

  const [
    user,
    totalIncomeAgg,
    totalExpenseAgg,
    monthIncomeAgg,
    monthExpenseAgg,
    monthCount,
    recentTxns,
    topCatsRaw,
  ] = await prisma.$transaction([
    prisma.user.findUnique({ where: { id: userId }, select: { openingBalance: true, currency: true, currencySymbol: true } }),
    // ── Balance aggregates — ALL transactions (excluded ones still count) ──
    prisma.transaction.aggregate({ where: { ...balanceWhere, type: 'INCOME' }, _sum: { amount: true } }),
    prisma.transaction.aggregate({ where: { ...balanceWhere, type: 'EXPENSE' }, _sum: { amount: true } }),
    // ── Month insight aggregates — excluded transactions omitted ──
    prisma.transaction.aggregate({ where: { ...monthAnalyticsWhere, type: 'INCOME' }, _sum: { amount: true } }),
    prisma.transaction.aggregate({ where: { ...monthAnalyticsWhere, type: 'EXPENSE' }, _sum: { amount: true } }),
    prisma.transaction.count({ where: monthAnalyticsWhere }),
    // ── Recent transactions — always show all ──
    prisma.transaction.findMany({
      where: recentWhere,
      include: { category: { select: { id: true, name: true, emoji: true, type: true } } },
      orderBy: [{ date: 'desc' }, { createdAt: 'desc' }],
      take: 5,
    }),
    // ── Top EXPENSE categories this month — excluded omitted ──
    prisma.transaction.groupBy({
      by: ['categoryId'],
      where: { ...monthAnalyticsWhere, type: 'EXPENSE', categoryId: { not: null } },
      _sum: { amount: true },
      orderBy: { _sum: { amount: 'desc' } },
      take: 5,
    }),
  ]);

  const openingBalance = parseFloat(user?.openingBalance ?? 0);
  const totalIncome = parseFloat(totalIncomeAgg._sum.amount ?? 0);
  const totalExpenses = parseFloat(totalExpenseAgg._sum.amount ?? 0);
  const currentBalance = openingBalance + totalIncome - totalExpenses;

  const monthIncome = parseFloat(monthIncomeAgg._sum.amount ?? 0);
  const monthExpenses = parseFloat(monthExpenseAgg._sum.amount ?? 0);

  // Resolve category names for top categories
  const categoryIds = topCatsRaw.map((r) => r.categoryId).filter(Boolean);
  const categories = categoryIds.length
    ? await prisma.category.findMany({ where: { id: { in: categoryIds } } })
    : [];
  const catMap = Object.fromEntries(categories.map((c) => [c.id, c]));

  const topCategories = topCatsRaw.map((r) => {
    const cat = catMap[r.categoryId];
    const total = parseFloat(r._sum.amount ?? 0);
    const base = monthExpenses || 1;
    return {
      categoryId: r.categoryId,
      name: cat?.name ?? 'Unknown',
      emoji: cat?.emoji ?? '❓',
      type: cat?.type ?? 'EXPENSE',
      total,
      percentage: parseFloat(((total / base) * 100).toFixed(1)),
    };
  });

  const recentTransactions = recentTxns.map((tx) => ({
    id: tx.id,
    title: _safeDecrypt(tx.title),
    amount: parseFloat(tx.amount),
    type: tx.type,
    date: tx.date,
    excludeFromAnalytics: tx.excludeFromAnalytics ?? false,
    category: tx.category
      ? { id: tx.category.id, name: tx.category.name, emoji: tx.category.emoji }
      : null,
  }));

  return {
    currentBalance,
    openingBalance,
    totalIncome,
    totalExpenses,
    thisMonth: {
      income: monthIncome,
      expenses: monthExpenses,
      transactionCount: monthCount,
    },
    recentTransactions,
    topCategories,
  };
}

module.exports = { getSummary };
