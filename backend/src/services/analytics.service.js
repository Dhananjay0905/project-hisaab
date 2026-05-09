/**
 * Analytics Service
 *
 * Two endpoints:
 *  1. Monthly trend  — last 6 calendar months of income vs expense totals.
 *  2. Category spend — current month's spending per EXPENSE category
 *     including the category's optional monthly limit.
 *
 * Exclusion rule:
 *  A transaction is excluded from analytics if:
 *   - The transaction itself has excludeFromAnalytics = true, OR
 *   - The transaction's category has excludeFromAnalytics = true
 */

const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

// ─── Helper: get excluded category IDs for a user ─────────────────────────────

async function _getExcludedCategoryIds(userId) {
  const excluded = await prisma.category.findMany({
    where: { userId, excludeFromAnalytics: true },
    select: { id: true },
  });
  return excluded.map((c) => c.id);
}

// ─── Monthly Trend (last 6 months) ────────────────────────────────────────────

/**
 * Returns an array of up to 6 month objects, oldest first:
 *   { month: 'Jan 25', income: 12000, expense: 8400 }
 */
async function getMonthlyTrend(userId) {
  const now = new Date();
  const months = [];

  // Get excluded category IDs once for all months
  const excludedCatIds = await _getExcludedCategoryIds(userId);

  // Base filter that excludes both transaction-level and category-level exclusions
  const exclusionFilter = {
    excludeFromAnalytics: false,
    ...(excludedCatIds.length > 0
      ? { categoryId: { notIn: excludedCatIds } }
      : {}),
  };

  for (let i = 5; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const start = new Date(d.getFullYear(), d.getMonth(), 1);
    const end   = new Date(d.getFullYear(), d.getMonth() + 1, 0, 23, 59, 59, 999);

    const [incomeAgg, expenseAgg] = await Promise.all([
      prisma.transaction.aggregate({
        where: {
          userId, type: 'INCOME', deletedAt: null,
          date: { gte: start, lte: end },
          ...exclusionFilter,
        },
        _sum: { amount: true },
      }),
      prisma.transaction.aggregate({
        where: {
          userId, type: 'EXPENSE', deletedAt: null,
          date: { gte: start, lte: end },
          ...exclusionFilter,
        },
        _sum: { amount: true },
      }),
    ]);

    const label = d.toLocaleString('en-IN', { month: 'short' }) + ' ' + String(d.getFullYear()).slice(2);
    months.push({
      month:   label,
      income:  Number(incomeAgg._sum.amount ?? 0),
      expense: Number(expenseAgg._sum.amount ?? 0),
    });
  }

  return months;
}

// ─── Category Spend (any month) ───────────────────────────────────────────────

/**
 * Returns spending per EXPENSE category for a given calendar month.
 * @param {string} userId
 * @param {number} [year]  - defaults to current year
 * @param {number} [month] - 1-based (Jan=1), defaults to current month
 *
 * Includes categories with zero spending IF they have a limit set.
 *   { categoryId, name, emoji, spent, limit, excludeFromAnalytics }
 *
 * Categories marked excludeFromAnalytics are omitted from the result.
 */
async function getCategorySpend(userId, year, month) {
  const now = new Date();
  const y   = year  ?? now.getFullYear();
  const m   = month ?? (now.getMonth() + 1); // convert to 0-based for Date
  const start = new Date(y, m - 1, 1);
  const end   = new Date(y, m, 0, 23, 59, 59, 999);

  // All expense categories for this user that are NOT excluded
  const categories = await prisma.category.findMany({
    where: { userId, type: 'EXPENSE', excludeFromAnalytics: false },
    orderBy: { name: 'asc' },
  });

  const categoryIds = categories.map((c) => c.id);

  // Aggregate spend per category for the selected month
  // Only count transactions not individually excluded
  const spendRows = await prisma.transaction.groupBy({
    by: ['categoryId'],
    where: {
      userId,
      type: 'EXPENSE',
      deletedAt: null,
      excludeFromAnalytics: false,
      date: { gte: start, lte: end },
      categoryId: { in: categoryIds },
    },
    _sum: { amount: true },
  });

  const spendMap = {};
  for (const row of spendRows) {
    if (row.categoryId) spendMap[row.categoryId] = Number(row._sum.amount ?? 0);
  }

  // Also include uncategorised total (categoryId === null), if not excluded at txn level
  const uncatRow = await prisma.transaction.aggregate({
    where: {
      userId, type: 'EXPENSE', deletedAt: null,
      excludeFromAnalytics: false,
      date: { gte: start, lte: end },
      categoryId: null,
    },
    _sum: { amount: true },
  });
  const uncatSpent = Number(uncatRow._sum.amount ?? 0);

  const result = categories.map(c => ({
    categoryId:  c.id,
    name:        c.name,
    emoji:       c.emoji,
    spent:       spendMap[c.id] ?? 0,
    // Limits only apply to the current month — past months are read-only history
    limit:       (y === now.getFullYear() && m === now.getMonth() + 1)
                   ? (c.monthlyLimit != null ? Number(c.monthlyLimit) : null)
                   : null,
  }));

  // Prepend an "Other" bucket only if there's uncategorised spend
  if (uncatSpent > 0) {
    result.unshift({ categoryId: null, name: 'Other', emoji: '📦', spent: uncatSpent, limit: null });
  }

  return result;
}

module.exports = { getMonthlyTrend, getCategorySpend };
