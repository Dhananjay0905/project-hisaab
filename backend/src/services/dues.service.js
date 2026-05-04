/**
 * Dues Service
 *
 * Handles money owed to/from people.
 *  - I_OWE   — the user owes money to someone
 *  - THEY_OWE — someone owes money to the user
 *
 * Security:
 *  - title, personName, note are encrypted (AES-256-GCM) at rest.
 *  - amount is stored as plain Decimal for DB-level aggregation.
 *
 * Settle behaviour:
 *  - Sets isPaid=true, paidAt=now
 *  - Optionally creates a mirrored Transaction (I_OWE → EXPENSE, THEY_OWE → INCOME)
 */

const { PrismaClient } = require('@prisma/client');
const { createError } = require('../middleware/errorHandler');
const { encrypt, decrypt, encryptOptional, decryptOptional } = require('../utils/encrypt');

const prisma = new PrismaClient();

// ─── Helpers ──────────────────────────────────────────────────────────────────

function _format(due) {
  let title = '[encrypted]';
  let personName = '[encrypted]';
  let note = null;

  try { title = decrypt(due.title); } catch (_) {}
  try { personName = decrypt(due.personName); } catch (_) {}
  try { if (due.note) note = decrypt(due.note); } catch (_) {}

  return {
    id: due.id,
    title,
    personName,
    note,
    amount: parseFloat(due.amount),
    type: due.type,
    dueDate: due.dueDate,
    isPaid: due.isPaid,
    paidAt: due.paidAt,
    createdAt: due.createdAt,
    updatedAt: due.updatedAt,
  };
}

// ─── Get List ─────────────────────────────────────────────────────────────────

async function getDues(userId, query = {}) {
  const where = {
    userId,
    deletedAt: null,
  };

  if (query.type === 'I_OWE' || query.type === 'THEY_OWE') {
    where.type = query.type;
  }

  if (query.isPaid === 'true') {
    where.isPaid = true;
  } else if (query.isPaid === 'false') {
    where.isPaid = false;
  }

  const dues = await prisma.due.findMany({
    where,
    orderBy: [
      { isPaid: 'asc' },      // pending first
      { dueDate: 'asc' },     // earliest deadline first
      { createdAt: 'desc' },  // newest within same deadline
    ],
  });

  return dues.map(_format);
}

// ─── Create ───────────────────────────────────────────────────────────────────

async function createDue(userId, data) {
  const due = await prisma.due.create({
    data: {
      userId,
      title: encrypt(data.title),
      personName: encrypt(data.personName),
      note: encryptOptional(data.note),
      amount: data.amount,
      type: data.type,            // 'I_OWE' | 'THEY_OWE'
      dueDate: data.dueDate ? new Date(data.dueDate) : null,
    },
  });

  return _format(due);
}

// ─── Update ───────────────────────────────────────────────────────────────────

async function updateDue(userId, id, data) {
  const existing = await prisma.due.findFirst({
    where: { id, userId, deletedAt: null },
  });
  if (!existing) throw createError('Due not found.', 404, 'NOT_FOUND');
  if (existing.isPaid) throw createError('Cannot edit a settled due.', 400, 'ALREADY_SETTLED');

  const updated = await prisma.due.update({
    where: { id },
    data: {
      ...(data.title !== undefined && { title: encrypt(data.title) }),
      ...(data.personName !== undefined && { personName: encrypt(data.personName) }),
      ...(data.note !== undefined && { note: encryptOptional(data.note) }),
      ...(data.amount !== undefined && { amount: data.amount }),
      ...(data.type !== undefined && { type: data.type }),
      ...(data.dueDate !== undefined && { dueDate: data.dueDate ? new Date(data.dueDate) : null }),
    },
  });

  return _format(updated);
}

// ─── Settle ───────────────────────────────────────────────────────────────────

async function settleDue(userId, id, { logAsTransaction = false } = {}) {
  const existing = await prisma.due.findFirst({
    where: { id, userId, deletedAt: null },
  });
  if (!existing) throw createError('Due not found.', 404, 'NOT_FOUND');
  if (existing.isPaid) throw createError('Due is already settled.', 400, 'ALREADY_SETTLED');

  const now = new Date();

  // Mark as paid in a transaction if also logging
  const settled = await prisma.$transaction(async (tx) => {
    const due = await tx.due.update({
      where: { id },
      data: { isPaid: true, paidAt: now },
    });

    if (logAsTransaction) {
      // I_OWE → EXPENSE (you paid someone), THEY_OWE → INCOME (you received money)
      const txType = existing.type === 'I_OWE' ? 'EXPENSE' : 'INCOME';
      const title = decrypt(existing.title);
      const personName = decrypt(existing.personName);
      await tx.transaction.create({
        data: {
          userId,
          title: encrypt(`${title} (${personName})`),
          amount: existing.amount,
          type: txType,
          date: now,
        },
      });
    }

    return due;
  });

  return _format(settled);
}

// ─── Delete (soft) ────────────────────────────────────────────────────────────

async function deleteDue(userId, id) {
  const existing = await prisma.due.findFirst({
    where: { id, userId, deletedAt: null },
  });
  if (!existing) throw createError('Due not found.', 404, 'NOT_FOUND');

  await prisma.due.update({
    where: { id },
    data: { deletedAt: new Date() },
  });

  return { message: 'Due deleted.' };
}

// ─── Summary (totals per type) ────────────────────────────────────────────────

async function getDuesSummary(userId) {
  const pending = await prisma.due.findMany({
    where: { userId, deletedAt: null, isPaid: false },
    select: { amount: true, type: true },
  });

  let iOweTotal = 0;
  let theyOweTotal = 0;

  for (const d of pending) {
    const amt = parseFloat(d.amount);
    if (d.type === 'I_OWE') iOweTotal += amt;
    else theyOweTotal += amt;
  }

  return {
    iOweTotal,
    theyOweTotal,
    effectiveBalance: theyOweTotal - iOweTotal,
  };
}

module.exports = {
  getDues,
  createDue,
  updateDue,
  settleDue,
  deleteDue,
  getDuesSummary,
};
