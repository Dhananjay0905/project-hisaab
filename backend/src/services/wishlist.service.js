/**
 * Wishlist Service
 *
 * Items the user is saving up for.
 * Each item has:
 *  - title, emoji           : display fields (title encrypted at rest)
 *  - targetPrice            : what the item costs
 *  - amountSaved            : how much the user has set aside for it
 *  - deductFromSavings      : whether amountSaved counts against the savings display
 *  - link                   : optional product URL (not PII, not encrypted)
 *  - isPurchased            : marks item as bought
 */

const { PrismaClient } = require('@prisma/client');
const { createError } = require('../middleware/errorHandler');
const { encrypt, decrypt } = require('../utils/encrypt');

const prisma = new PrismaClient();

// ─── Format ───────────────────────────────────────────────────────────────────

function _format(item) {
  let title = '[encrypted]';
  try { title = decrypt(item.title); } catch (_) {}

  return {
    id: item.id,
    title,
    emoji: item.emoji,
    link: item.link ?? null,
    targetPrice: item.targetPrice !== null ? parseFloat(item.targetPrice) : null,
    amountSaved: parseFloat(item.amountSaved),
    deductFromSavings: item.deductFromSavings,
    isPurchased: item.isPurchased,
    purchasedAt: item.purchasedAt,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
  };
}

// ─── List ─────────────────────────────────────────────────────────────────────

async function listWishlist(userId) {
  const items = await prisma.wishlistItem.findMany({
    where: { userId, deletedAt: null },
    orderBy: [
      { isPurchased: 'asc' },  // unpurchased first
      { createdAt: 'desc' },
    ],
  });
  return items.map(_format);
}

// ─── Create ───────────────────────────────────────────────────────────────────

async function createWishlistItem(userId, data) {
  const item = await prisma.wishlistItem.create({
    data: {
      userId,
      title: encrypt(data.title),
      emoji: data.emoji || '🛍️',
      link: data.link || null,
      targetPrice: data.targetPrice ?? null,
      amountSaved: data.amountSaved ?? 0,
      deductFromSavings: data.deductFromSavings !== false, // default true
    },
  });
  return _format(item);
}

// ─── Update ───────────────────────────────────────────────────────────────────

async function updateWishlistItem(userId, id, data) {
  const existing = await prisma.wishlistItem.findFirst({
    where: { id, userId, deletedAt: null },
  });
  if (!existing) throw createError('Wishlist item not found.', 404, 'NOT_FOUND');

  const updated = await prisma.wishlistItem.update({
    where: { id },
    data: {
      ...(data.title !== undefined && { title: encrypt(data.title) }),
      ...(data.emoji !== undefined && { emoji: data.emoji }),
      ...(data.link !== undefined && { link: data.link || null }),
      ...(data.targetPrice !== undefined && { targetPrice: data.targetPrice }),
      ...(data.amountSaved !== undefined && { amountSaved: data.amountSaved }),
      ...(data.deductFromSavings !== undefined && { deductFromSavings: data.deductFromSavings }),
    },
  });
  return _format(updated);
}

// ─── Toggle deduct ────────────────────────────────────────────────────────────

async function toggleDeduct(userId, id) {
  const existing = await prisma.wishlistItem.findFirst({
    where: { id, userId, deletedAt: null },
  });
  if (!existing) throw createError('Wishlist item not found.', 404, 'NOT_FOUND');

  const updated = await prisma.wishlistItem.update({
    where: { id },
    data: { deductFromSavings: !existing.deductFromSavings },
  });
  return _format(updated);
}

// ─── Mark purchased ───────────────────────────────────────────────────────────

async function markPurchased(userId, id) {
  const existing = await prisma.wishlistItem.findFirst({
    where: { id, userId, deletedAt: null },
  });
  if (!existing) throw createError('Wishlist item not found.', 404, 'NOT_FOUND');
  if (existing.isPurchased) throw createError('Item already marked as purchased.', 400, 'ALREADY_PURCHASED');

  const updated = await prisma.wishlistItem.update({
    where: { id },
    data: { isPurchased: true, purchasedAt: new Date() },
  });
  return _format(updated);
}

// ─── Soft delete ──────────────────────────────────────────────────────────────

async function deleteWishlistItem(userId, id) {
  const existing = await prisma.wishlistItem.findFirst({
    where: { id, userId, deletedAt: null },
  });
  if (!existing) throw createError('Wishlist item not found.', 404, 'NOT_FOUND');

  await prisma.wishlistItem.update({
    where: { id },
    data: { deletedAt: new Date() },
  });
  return { message: 'Item deleted.' };
}

module.exports = {
  listWishlist,
  createWishlistItem,
  updateWishlistItem,
  toggleDeduct,
  markPurchased,
  deleteWishlistItem,
};
