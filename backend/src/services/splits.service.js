/**
 * splits.service.js — Business logic for bill splits.
 *
 * Encryption strategy (matches transactions.service.js):
 *  - title, note, participant.name → AES-256-GCM (encrypt/decrypt helpers)
 *  - amounts → plain Decimal (stored as-is for easy aggregation)
 */

const { PrismaClient } = require('@prisma/client');
const { encrypt, decrypt } = require('../utils/encrypt');

const prisma = new PrismaClient();

// ─── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Decrypt a single Split row + its participants from the DB.
 */
function decryptSplit(split) {
  return {
    ...split,
    title: decrypt(split.title),
    note: split.note ? decrypt(split.note) : null,
    totalAmount: Number(split.totalAmount),
    participants: (split.participants || []).map(decryptParticipant),
    categoryId: split.categoryId ?? null,
    category: split.category
      ? { id: split.category.id, name: split.category.name, emoji: split.category.emoji }
      : null,
  };
}

function decryptParticipant(p) {
  return {
    ...p,
    name: decrypt(p.name),
    amount: Number(p.amount),
  };
}

// ─── Service methods ──────────────────────────────────────────────────────────

/**
 * List all active (non-deleted) splits for a user, newest first.
 * Each split includes its participants.
 */
async function listSplits(userId) {
  const splits = await prisma.split.findMany({
    where: { userId, deletedAt: null },
    include: { participants: { orderBy: { createdAt: 'asc' } }, category: true },
    orderBy: { date: 'desc' },
  });
  return splits.map(decryptSplit);
}

/**
 * Create a new split with equal per-person shares.
 * @param {string} userId
 * @param {object} data
 * @param {string}   data.title
 * @param {number}   data.totalAmount
 * @param {string[]} data.participantNames  — list of names (you excluded)
 * @param {string}   [data.note]
 * @param {string}   [data.date]            — ISO date string
 */
async function createSplit(userId, { title, totalAmount, participantNames, note, date, categoryId, logAsExpense }) {
  const count = participantNames.length;
  if (count < 1) throw new Error('At least one participant required.');

  const perPerson = Number((totalAmount / (count + 1)).toFixed(2)); // +1 = you

  const splitDate = date ? new Date(date) : new Date();

  const split = await prisma.split.create({
    data: {
      userId,
      title: encrypt(title),
      note: note ? encrypt(note) : null,
      totalAmount,
      categoryId: categoryId || null,
      date: splitDate,
      participants: {
        create: participantNames.map((name) => ({
          name: encrypt(name.trim()),
          amount: perPerson,
        })),
      },
    },
    include: { participants: { orderBy: { createdAt: 'asc' } }, category: true },
  });

  // Optionally create an EXPENSE transaction for the full bill amount.
  if (logAsExpense) {
    let expenseCategoryId = categoryId || null;
    if (!expenseCategoryId) {
      const otherExpenses = await prisma.category.findFirst({
        where: { userId, name: 'Other Expenses', isDefault: true },
      });
      expenseCategoryId = otherExpenses?.id ?? null;
    }
    const txNote = `${count + 1} people · ₹${perPerson}/person`;
    await prisma.transaction.create({
      data: {
        userId,
        categoryId: expenseCategoryId,
        title: encrypt(title),
        amount: totalAmount,
        type: 'EXPENSE',
        note: encrypt(txNote),
        date: splitDate,
      },
    });
  }

  return decryptSplit(split);
}

/**
 * Update the title/note of a split (not amounts — those are fixed at creation).
 */
async function updateSplit(userId, splitId, { title, note, categoryId }) {
  const split = await prisma.split.findFirst({ where: { id: splitId, userId, deletedAt: null } });
  if (!split) throw new Error('Split not found.');

  const updated = await prisma.split.update({
    where: { id: splitId },
    data: {
      title: title !== undefined ? encrypt(title) : split.title,
      note: note !== undefined ? (note ? encrypt(note) : null) : split.note,
      ...(categoryId !== undefined && { categoryId: categoryId || null }),
    },
    include: { participants: { orderBy: { createdAt: 'asc' } }, category: true },
  });

  return decryptSplit(updated);
}

/**
 * Soft-delete a split.
 */
async function deleteSplit(userId, splitId) {
  const split = await prisma.split.findFirst({ where: { id: splitId, userId, deletedAt: null } });
  if (!split) throw new Error('Split not found.');

  await prisma.split.update({
    where: { id: splitId },
    data: { deletedAt: new Date() },
  });
}

/**
 * Mark a participant as paid.
 * Optionally auto-creates an INCOME transaction.
 *
 * @param {string}  userId
 * @param {string}  splitId
 * @param {string}  participantId
 * @param {boolean} createTransaction — if true, create an INCOME transaction
 * @param {number}  [paidAmount]      — actual amount received (may differ from split share)
 * @returns {{ participant, transaction? }}
 */
async function markParticipantPaid(userId, splitId, participantId, createTransaction, paidAmount, incomeCategoryId) {
  // Verify ownership
  const split = await prisma.split.findFirst({
    where: { id: splitId, userId, deletedAt: null },
    include: { participants: true },
  });
  if (!split) throw new Error('Split not found.');

  const participant = split.participants.find((p) => p.id === participantId);
  if (!participant) throw new Error('Participant not found.');
  if (participant.hasPaid) throw new Error('Participant has already paid.');

  let transactionId = null;
  let transaction = null;

  if (createTransaction) {
    // Use the explicitly provided income category; fall back to "Other Income".
    // NOTE: We intentionally do NOT use split.categoryId here — that is the
    // expense category for the original bill, not an income category.
    let resolvedCategoryId = incomeCategoryId || null;
    if (!resolvedCategoryId) {
      const otherIncome = await prisma.category.findFirst({
        where: { userId, name: 'Other Income', isDefault: true },
      });
      resolvedCategoryId = otherIncome?.id ?? null;
    }

    const decryptedSplitTitle = decrypt(split.title);
    const decryptedName = decrypt(participant.name);

    transaction = await prisma.transaction.create({
      data: {
        userId,
        categoryId: resolvedCategoryId,
        title: encrypt(`Split: ${decryptedSplitTitle} — from ${decryptedName}`),
        amount: paidAmount != null ? paidAmount : participant.amount,
        type: 'INCOME',
        date: new Date(),
      },
    });
    transactionId = transaction.id;
  }

  const updatedParticipant = await prisma.splitParticipant.update({
    where: { id: participantId },
    data: {
      hasPaid: true,
      paidAt: new Date(),
      transactionId,
    },
  });

  return {
    participant: decryptParticipant(updatedParticipant),
    transaction: transaction
      ? { ...transaction, title: `Split: ... — from ...`, amount: Number(transaction.amount) }
      : null,
  };
}

/**
 * Unmark a participant as paid (undo).
 * Does NOT delete the linked transaction — user can delete it manually.
 */
async function unmarkParticipantPaid(userId, splitId, participantId) {
  const split = await prisma.split.findFirst({
    where: { id: splitId, userId, deletedAt: null },
    include: { participants: true },
  });
  if (!split) throw new Error('Split not found.');

  const participant = split.participants.find((p) => p.id === participantId);
  if (!participant) throw new Error('Participant not found.');

  const updatedParticipant = await prisma.splitParticipant.update({
    where: { id: participantId },
    data: { hasPaid: false, paidAt: null, transactionId: null },
  });

  return decryptParticipant(updatedParticipant);
}

/**
 * Get a single split by id (for deep-link / detail view).
 */
async function getSplit(userId, splitId) {
  const split = await prisma.split.findFirst({
    where: { id: splitId, userId, deletedAt: null },
    include: { participants: { orderBy: { createdAt: 'asc' } } },
  });
  if (!split) throw new Error('Split not found.');
  return decryptSplit(split);
}

module.exports = {
  listSplits,
  createSplit,
  updateSplit,
  deleteSplit,
  markParticipantPaid,
  unmarkParticipantPaid,
  getSplit,
};
