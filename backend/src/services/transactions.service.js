/**
 * Transactions Service
 *
 * Core financial logic for the app.
 *
 * Design decisions:
 *  - Amounts stored as plain Decimal (DB-level aggregation possible).
 *  - Title / note encrypted with AES-256-GCM (personal identifiers).
 *  - Soft-delete: sets deletedAt; records excluded from all public queries.
 *  - Pagination: cursor-based page/limit.
 *  - Filters: type, categoryId, dateRange, text search on decrypted title.
 */

const { PrismaClient, Prisma } = require('@prisma/client');
const { createError } = require('../middleware/errorHandler');
const { encrypt, decrypt, encryptOptional, decryptOptional } = require('../utils/encrypt');

const prisma = new PrismaClient();

// ─── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Decrypts a transaction row from Prisma and converts Decimal → number.
 * Safe: if decryption fails, returns '[encrypted]' rather than crashing.
 */
function _formatTransaction(tx) {
  let title = '[encrypted]';
  let note = null;

  try { title = decrypt(tx.title); } catch (_) {}
  try { if (tx.note) note = decrypt(tx.note); } catch (_) {}

  return {
    id: tx.id,
    title,
    note,
    amount: parseFloat(tx.amount),
    type: tx.type,
    date: tx.date,
    excludeFromAnalytics: tx.excludeFromAnalytics ?? false,
    createdAt: tx.createdAt,
    updatedAt: tx.updatedAt,
    category: tx.category
      ? {
          id: tx.category.id,
          name: tx.category.name,
          emoji: tx.category.emoji,
          type: tx.category.type,
          excludeFromAnalytics: tx.category.excludeFromAnalytics ?? false,
        }
      : null,
    categoryId: tx.categoryId ?? null,
  };
}

const CATEGORY_INCLUDE = {
  category: {
    select: { id: true, name: true, emoji: true, type: true, excludeFromAnalytics: true },
  },
};

// ─── Get Many (paginated + filtered) ──────────────────────────────────────────

async function getTransactions(userId, query = {}) {
  const page = Math.max(1, parseInt(query.page) || 1);
  const limit = Math.min(50, Math.max(1, parseInt(query.limit) || 20));
  const skip = (page - 1) * limit;

  // Build where clause
  // categoryIds = comma-separated list (multi-select filter)
  // categoryId  = legacy single-id filter (kept for backwards compat)
  const categoryIdsList =
    query.categoryIds
      ? query.categoryIds.split(',').map((s) => s.trim()).filter(Boolean)
      : query.categoryId
      ? [query.categoryId]
      : [];

  const where = {
    userId,
    deletedAt: null,
    ...(query.type ? { type: query.type } : {}),
    ...(categoryIdsList.length > 0
      ? { categoryId: { in: categoryIdsList } }
      : {}),
    ...(query.startDate || query.endDate
      ? {
          date: {
            ...(query.startDate ? { gte: new Date(query.startDate) } : {}),
            ...(query.endDate ? { lte: new Date(query.endDate) } : {}),
          },
        }
      : {}),
  };

  // Sorting
  const sortBy = ['date', 'amount', 'createdAt'].includes(query.sortBy)
    ? query.sortBy
    : 'date';
  const sortOrder = query.sortOrder === 'asc' ? 'asc' : 'desc';

  const [total, rows] = await prisma.$transaction([
    prisma.transaction.count({ where }),
    prisma.transaction.findMany({
      where,
      include: CATEGORY_INCLUDE,
      orderBy: [{ [sortBy]: sortOrder }, { createdAt: 'desc' }],
      skip,
      take: limit,
    }),
  ]);

  let items = rows.map(_formatTransaction);

  // Client-side text search on decrypted title (only if search param provided)
  // Note: for large datasets consider a dedicated search index.
  if (query.search && query.search.trim()) {
    const needle = query.search.trim().toLowerCase();
    items = items.filter(
      (t) =>
        t.title.toLowerCase().includes(needle) ||
        (t.note && t.note.toLowerCase().includes(needle)) ||
        (t.category?.name.toLowerCase().includes(needle))
    );
  }

  return {
    items,
    pagination: {
      total,
      page,
      limit,
      pages: Math.ceil(total / limit),
      hasNext: page * limit < total,
      hasPrev: page > 1,
    },
  };
}

// ─── Get One ──────────────────────────────────────────────────────────────────

async function getTransaction(userId, id) {
  const tx = await prisma.transaction.findFirst({
    where: { id, userId, deletedAt: null },
    include: CATEGORY_INCLUDE,
  });
  if (!tx) throw createError('Transaction not found.', 404, 'NOT_FOUND');
  return _formatTransaction(tx);
}

// ─── Create ───────────────────────────────────────────────────────────────────

async function createTransaction(userId, data) {
  const { title, note, amount, type, categoryId, date, excludeFromAnalytics } = data;

  // Validate category ownership if provided
  if (categoryId) {
    const cat = await prisma.category.findFirst({
      where: { id: categoryId, userId },
    });
    if (!cat) throw createError('Category not found.', 404, 'CATEGORY_NOT_FOUND');
    if (cat.type !== type) {
      throw createError(
        `Category type (${cat.type}) does not match transaction type (${type}).`,
        400,
        'TYPE_MISMATCH'
      );
    }
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

  const tx = await prisma.transaction.create({
    data: {
      userId,
      title: encrypt(title.trim()),
      note: encryptOptional(note),
      amount: new Prisma.Decimal(parseFloat(amount)),
      type,
      categoryId: finalCategoryId,
      date: date ? new Date(date) : new Date(),
      excludeFromAnalytics: excludeFromAnalytics === true,
    },
    include: CATEGORY_INCLUDE,
  });

  return _formatTransaction(tx);
}

// ─── Update ───────────────────────────────────────────────────────────────────

async function updateTransaction(userId, id, data) {
  const existing = await prisma.transaction.findFirst({
    where: { id, userId, deletedAt: null },
  });
  if (!existing) throw createError('Transaction not found.', 404, 'NOT_FOUND');

  const { title, note, amount, type, categoryId, date, excludeFromAnalytics } = data;
  const newType = type || existing.type;

  // Validate category if changing
  const newCategoryId = categoryId !== undefined ? categoryId : existing.categoryId;
  if (newCategoryId) {
    const cat = await prisma.category.findFirst({
      where: { id: newCategoryId, userId },
    });
    if (!cat) throw createError('Category not found.', 404, 'CATEGORY_NOT_FOUND');
    if (cat.type !== newType) {
      throw createError(
        `Category type (${cat.type}) does not match transaction type (${newType}).`,
        400,
        'TYPE_MISMATCH'
      );
    }
  }

  let finalCategoryId = categoryId !== undefined ? categoryId : existing.categoryId;
  if (!finalCategoryId) {
    const fallbackName = newType === 'EXPENSE' ? 'Other Expenses' : 'Other Income';
    const fallbackCategory = await prisma.category.findFirst({
      where: { userId, name: fallbackName, type: newType, isDefault: true },
    });
    if (fallbackCategory) {
      finalCategoryId = fallbackCategory.id;
    }
  }

  const updated = await prisma.transaction.update({
    where: { id },
    data: {
      ...(title ? { title: encrypt(title.trim()) } : {}),
      ...(note !== undefined ? { note: encryptOptional(note) } : {}),
      ...(amount !== undefined
        ? { amount: new Prisma.Decimal(parseFloat(amount)) }
        : {}),
      ...(type ? { type } : {}),
      categoryId: finalCategoryId,
      ...(date ? { date: new Date(date) } : {}),
      ...(excludeFromAnalytics !== undefined ? { excludeFromAnalytics: Boolean(excludeFromAnalytics) } : {}),
    },
    include: CATEGORY_INCLUDE,
  });

  return _formatTransaction(updated);
}

// ─── Delete (soft) ────────────────────────────────────────────────────────────

async function deleteTransaction(userId, id) {
  const existing = await prisma.transaction.findFirst({
    where: { id, userId, deletedAt: null },
  });
  if (!existing) throw createError('Transaction not found.', 404, 'NOT_FOUND');

  await prisma.transaction.update({
    where: { id },
    data: { deletedAt: new Date() },
  });

  return { message: 'Transaction deleted.' };
}

module.exports = {
  getTransactions,
  getTransaction,
  createTransaction,
  updateTransaction,
  deleteTransaction,
};
