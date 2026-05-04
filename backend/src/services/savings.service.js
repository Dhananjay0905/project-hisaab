/**
 * Savings Service
 *
 * Manages a single savings "pot" per user, completely separate from
 * the transaction balance. The user manually enters/adjusts the total.
 *
 * Computed fields returned on every read:
 *  - rawTotal           : the number the user entered
 *  - cashDeduction      : amount kept physically in cash (display context only)
 *  - wishlistDeduction  : sum of amountSaved for wishlist items where deductFromSavings=true
 *  - effectiveTotal     : rawTotal − cashDeduction − wishlistDeduction
 *  - deductFromBalance  : whether to show balance−savings on the home page
 */

const { PrismaClient } = require('@prisma/client');
const { createError } = require('../middleware/errorHandler');

const prisma = new PrismaClient();

// ─── Helper: compute wishlist deduction for a user ───────────────────────────

async function _wishlistDeduction(userId) {
  const items = await prisma.wishlistItem.findMany({
    where: { userId, deletedAt: null, deductFromSavings: true, isPurchased: false },
    select: { amountSaved: true },
  });
  return items.reduce((sum, i) => sum + parseFloat(i.amountSaved), 0);
}

// ─── Format response ──────────────────────────────────────────────────────────

function _format(savings, wishlistDeduction) {
  const raw = parseFloat(savings.totalAmount);
  const cash = parseFloat(savings.cashDeduction);
  const wishlist = wishlistDeduction;

  return {
    id: savings.id,
    rawTotal: raw,
    cashDeduction: cash,
    wishlistDeduction: wishlist,
    effectiveTotal: Math.max(0, raw - cash - wishlist),
    deductFromBalance: savings.deductFromBalance,
    updatedAt: savings.updatedAt,
  };
}

// ─── Get (or create) savings record ──────────────────────────────────────────

async function getSavings(userId) {
  let savings = await prisma.savings.findUnique({ where: { userId } });

  // Auto-create a zero record for new users
  if (!savings) {
    savings = await prisma.savings.create({
      data: { userId, totalAmount: 0, cashDeduction: 0, deductFromBalance: false },
    });
  }

  const wishlistDeduction = await _wishlistDeduction(userId);
  return _format(savings, wishlistDeduction);
}

// ─── Update savings ───────────────────────────────────────────────────────────

async function updateSavings(userId, { totalAmount, cashDeduction, deductFromBalance }) {
  // Ensure record exists
  await prisma.savings.upsert({
    where: { userId },
    create: { userId, totalAmount: 0, cashDeduction: 0, deductFromBalance: false },
    update: {},
  });

  const data = {};
  if (totalAmount !== undefined) {
    if (totalAmount < 0) throw createError('Total amount cannot be negative.', 400, 'INVALID_AMOUNT');
    data.totalAmount = totalAmount;
  }
  if (cashDeduction !== undefined) {
    if (cashDeduction < 0) throw createError('Cash deduction cannot be negative.', 400, 'INVALID_AMOUNT');
    data.cashDeduction = cashDeduction;
  }
  if (deductFromBalance !== undefined) {
    data.deductFromBalance = Boolean(deductFromBalance);
  }

  const updated = await prisma.savings.update({
    where: { userId },
    data,
  });

  const wishlistDeduction = await _wishlistDeduction(userId);
  return _format(updated, wishlistDeduction);
}

module.exports = { getSavings, updateSavings };
