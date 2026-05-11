/**
 * Recurring Transactions Service
 *
 * Manages recurring transaction templates for a user.
 * On confirmation, a real Transaction record is created and
 * nextDueDate is advanced by the frequency interval.
 */

const { PrismaClient } = require('@prisma/client');
const { createError } = require('../middleware/errorHandler');
const { encrypt, decrypt } = require('../utils/encrypt');

const prisma = new PrismaClient();

// ─── Frequency helpers ─────────────────────────────────────────────────────────

/**
 * Advance a date by one frequency period.
 */
function advanceDate(date, frequency) {
  const d = new Date(date);
  switch (frequency) {
    case 'DAILY':
      d.setDate(d.getDate() + 1);
      break;
    case 'WEEKLY':
      d.setDate(d.getDate() + 7);
      break;
    case 'MONTHLY':
      d.setMonth(d.getMonth() + 1);
      break;
    case 'YEARLY':
      d.setFullYear(d.getFullYear() + 1);
      break;
    default:
      throw new Error(`Unknown frequency: ${frequency}`);
  }
  return d;
}

// ─── List all ─────────────────────────────────────────────────────────────────

async function listRecurring(userId) {
  const items = await prisma.recurringTransaction.findMany({
    where: { userId },
    include: { category: true },
    orderBy: [{ isActive: 'desc' }, { nextDueDate: 'asc' }],
  });
  return items.map(_format);
}

// ─── List due today ────────────────────────────────────────────────────────────

async function listDue(userId) {
  const today = new Date();
  today.setHours(23, 59, 59, 999); // end of today

  const items = await prisma.recurringTransaction.findMany({
    where: {
      userId,
      isActive: true,
      nextDueDate: { lte: today },
    },
    include: { category: true },
    orderBy: { nextDueDate: 'asc' },
  });
  return items.map(_format);
}

// ─── Create ───────────────────────────────────────────────────────────────────

async function createRecurring(userId, { title, amount, type, categoryId, frequency, startDate }) {
  // Validate category ownership if provided
  if (categoryId) {
    const category = await prisma.category.findFirst({
      where: { id: categoryId, userId },
    });
    if (!category) throw createError('Category not found.', 404, 'NOT_FOUND');
  }

  let finalCategoryId = categoryId || null;
  if (!finalCategoryId) {
    const fallbackName = type === 'EXPENSE' ? 'Other Expenses' : 'Other Income';
    const fallbackCategory = await prisma.category.findFirst({
      where: { userId, name: fallbackName, type, isDefault: true },
    });
    if (fallbackCategory) {
      finalCategoryId = fallbackCategory.id;
    }
  }

  const start = new Date(startDate);

  const item = await prisma.recurringTransaction.create({
    data: {
      userId,
      title: encrypt(title.trim()),
      amount: parseFloat(amount),
      type,
      categoryId: finalCategoryId,
      frequency,
      startDate: start,
      nextDueDate: start,
      isActive: true,
    },
    include: { category: true },
  });

  return _format(item);
}

// ─── Update ───────────────────────────────────────────────────────────────────

async function updateRecurring(userId, id, { title, amount, type, categoryId, frequency, startDate }) {
  const item = await _findOwned(userId, id);

  // Validate category if changing
  if (categoryId && categoryId !== item.categoryId) {
    const cat = await prisma.category.findFirst({ where: { id: categoryId, userId } });
    if (!cat) throw createError('Category not found.', 404, 'NOT_FOUND');
  }

  let finalCategoryId = categoryId !== undefined ? categoryId : item.categoryId;
  if (!finalCategoryId) {
    const newType = type || item.type;
    const fallbackName = newType === 'EXPENSE' ? 'Other Expenses' : 'Other Income';
    const fallbackCategory = await prisma.category.findFirst({
      where: { userId, name: fallbackName, type: newType, isDefault: true },
    });
    if (fallbackCategory) {
      finalCategoryId = fallbackCategory.id;
    }
  }

  const updated = await prisma.recurringTransaction.update({
    where: { id: item.id },
    data: {
      ...(title ? { title: encrypt(title.trim()) } : {}),
      ...(amount != null ? { amount: parseFloat(amount) } : {}),
      ...(type ? { type } : {}),
      categoryId: finalCategoryId,
      ...(frequency ? { frequency } : {}),
      ...(startDate ? { startDate: new Date(startDate) } : {}),
    },
    include: { category: true },
  });

  return _format(updated);
}

// ─── Toggle active (pause / resume) ──────────────────────────────────────────

async function toggleActive(userId, id) {
  const item = await _findOwned(userId, id);

  const updated = await prisma.recurringTransaction.update({
    where: { id: item.id },
    data: { isActive: !item.isActive },
    include: { category: true },
  });

  return _format(updated);
}

// ─── Confirm due — creates transaction + advances date ────────────────────────

async function confirmDue(userId, id) {
  const item = await _findOwned(userId, id);

  if (!item.isActive) {
    throw createError('Recurring transaction is paused.', 400, 'RECURRING_PAUSED');
  }

  const nextDueDate = advanceDate(item.nextDueDate, item.frequency);

  // Run in a transaction to ensure atomicity
  const [transaction] = await prisma.$transaction([
    prisma.transaction.create({
      data: {
        userId,
        title: item.title, // already encrypted in recurring table!
        amount: item.amount,
        type: item.type,
        categoryId: item.categoryId,
        date: new Date(),
        note: encrypt(`Auto-added from recurring: ${decrypt(item.title)}`),
      },
    }),
    prisma.recurringTransaction.update({
      where: { id: item.id },
      data: { nextDueDate },
    }),
  ]);

  return {
    message: 'Transaction added and next due date advanced.',
    transaction: {
      id: transaction.id,
      title: decrypt(transaction.title),
      amount: parseFloat(transaction.amount),
      type: transaction.type,
      date: transaction.date,
    },
    nextDueDate,
  };
}

// ─── Delete ───────────────────────────────────────────────────────────────────

async function deleteRecurring(userId, id) {
  await _findOwned(userId, id);
  await prisma.recurringTransaction.delete({ where: { id } });
  return { message: 'Recurring transaction cancelled.' };
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

async function _findOwned(userId, id) {
  const item = await prisma.recurringTransaction.findFirst({
    where: { id, userId },
  });
  if (!item) throw createError('Recurring transaction not found.', 404, 'NOT_FOUND');
  return item;
}

function _format(item) {
  let decryptedTitle = '[encrypted]';
  try { decryptedTitle = decrypt(item.title); } catch (_) {}

  return {
    id: item.id,
    title: decryptedTitle,
    amount: parseFloat(item.amount),
    type: item.type,
    frequency: item.frequency,
    startDate: item.startDate,
    nextDueDate: item.nextDueDate,
    isActive: item.isActive,
    createdAt: item.createdAt,
    category: item.category
      ? { id: item.category.id, name: item.category.name, emoji: item.category.emoji, type: item.category.type }
      : null,
  };
}

module.exports = {
  listRecurring,
  listDue,
  createRecurring,
  updateRecurring,
  toggleActive,
  confirmDue,
  deleteRecurring,
};
