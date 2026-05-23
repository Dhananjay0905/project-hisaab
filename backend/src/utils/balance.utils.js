/**
 * Balance utility — shared helper for balance-sufficiency checks.
 *
 * Used by any service that creates or modifies records affecting a user's
 * net balance (transactions, dues, recurring).
 *
 * Balance formula (mirrors summary.service.js):
 *   currentBalance = openingBalance + SUM(INCOME) - SUM(EXPENSE)
 */

const { createError } = require('../middleware/errorHandler');

/**
 * Computes the current balance for a user.
 *
 * @param {string} userId
 * @param {object} db - Prisma client OR interactive-transaction client (tx)
 * @returns {Promise<number>} current balance as a plain JS number
 */
async function getUserBalance(userId, db) {
  const [user, incomeAgg, expenseAgg] = await Promise.all([
    db.user.findUnique({
      where: { id: userId },
      select: { openingBalance: true },
    }),
    db.transaction.aggregate({
      where: { userId, type: 'INCOME', deletedAt: null },
      _sum: { amount: true },
    }),
    db.transaction.aggregate({
      where: { userId, type: 'EXPENSE', deletedAt: null },
      _sum: { amount: true },
    }),
  ]);

  const openingBalance = parseFloat(user?.openingBalance ?? 0);
  const totalIncome    = parseFloat(incomeAgg._sum.amount   ?? 0);
  const totalExpenses  = parseFloat(expenseAgg._sum.amount  ?? 0);
  return openingBalance + totalIncome - totalExpenses;
}

/**
 * Throws INSUFFICIENT_BALANCE (422) if the projected balance would be negative.
 *
 * @param {number} balanceAfter - projected balance after the operation
 * @param {string} message      - user-facing error message
 */
function assertSufficientBalance(balanceAfter, message) {
  if (balanceAfter < 0) {
    throw createError(message, 422, 'INSUFFICIENT_BALANCE');
  }
}

module.exports = { getUserBalance, assertSufficientBalance };
