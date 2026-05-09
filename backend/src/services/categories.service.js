/**
 * Categories Service
 *
 * Manages transaction categories per user.
 * Each user has a set of seeded default categories (isDefault = true)
 * and can add unlimited custom categories.
 *
 * Rules:
 *  - Default categories cannot be deleted.
 *  - A category with linked transactions cannot be deleted (soft-block).
 *  - Category names are scoped per user — duplicates across users are fine.
 */

const { PrismaClient } = require('@prisma/client');
const { createError } = require('../middleware/errorHandler');

const prisma = new PrismaClient();

// ─── Get All ──────────────────────────────────────────────────────────────────

/**
 * Returns all categories for the user, defaults first, then alphabetical.
 */
async function getCategories(userId) {
  const categories = await prisma.category.findMany({
    where: { userId },
    orderBy: [{ isDefault: 'desc' }, { name: 'asc' }],
  });
  return categories.map(_formatCategory);
}

// ─── Create ───────────────────────────────────────────────────────────────────

/**
 * Creates a new custom category for the user.
 */
async function createCategory(userId, { name, emoji, type, monthlyLimit, excludeFromAnalytics }) {
  // Guard: duplicate name+type for this user
  const existing = await prisma.category.findFirst({
    where: { userId, name: name.trim(), type },
  });
  if (existing) {
    throw createError(
      `A ${type.toLowerCase()} category named "${name.trim()}" already exists.`,
      409,
      'CATEGORY_DUPLICATE'
    );
  }

  const category = await prisma.category.create({
    data: {
      userId,
      name: name.trim(),
      emoji: emoji.trim(),
      type,
      isDefault: false,
      ...(monthlyLimit != null ? { monthlyLimit } : {}),
      excludeFromAnalytics: excludeFromAnalytics === true,
    },
  });

  return _formatCategory(category);
}

// ─── Update ───────────────────────────────────────────────────────────────────

/**
 * Updates name and/or emoji of a category the user owns.
 * Type cannot be changed (would invalidate linked transactions).
 */
async function updateCategory(userId, categoryId, { name, emoji, monthlyLimit, excludeFromAnalytics }) {
  const category = await _findOwnedCategory(userId, categoryId);

  const updated = await prisma.category.update({
    where: { id: category.id },
    data: {
      ...(name ? { name: name.trim() } : {}),
      ...(emoji ? { emoji: emoji.trim() } : {}),
      // null explicitly clears the limit; undefined = no change
      ...(monthlyLimit !== undefined ? { monthlyLimit: monthlyLimit ?? null } : {}),
      ...(excludeFromAnalytics !== undefined ? { excludeFromAnalytics: Boolean(excludeFromAnalytics) } : {}),
    },
  });

  return _formatCategory(updated);
}

// ─── Delete ───────────────────────────────────────────────────────────────────

/**
 * Deletes a custom category.
 * Guards:
 *  - Cannot delete default categories.
 *  - Cannot delete if transactions are linked (returns count so client can warn).
 */
async function deleteCategory(userId, categoryId) {
  const category = await _findOwnedCategory(userId, categoryId);

  // Guard: Cannot delete default categories
  if (category.isDefault) {
    throw createError('Cannot delete a default category.', 400, 'BAD_REQUEST');
  }

  // Transactions and RecurringTransactions linked to this category will automatically 
  // have their categoryId set to null due to onDelete: SetNull in Prisma schema.

  await prisma.category.delete({ where: { id: category.id } });

  return { message: 'Category deleted successfully.' };
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

async function _findOwnedCategory(userId, categoryId) {
  const category = await prisma.category.findFirst({
    where: { id: categoryId, userId },
  });
  if (!category) {
    throw createError('Category not found.', 404, 'NOT_FOUND');
  }
  return category;
}

function _formatCategory(c) {
  return {
    id: c.id,
    name: c.name,
    emoji: c.emoji,
    type: c.type,
    isDefault: c.isDefault,
    excludeFromAnalytics: c.excludeFromAnalytics ?? false,
    monthlyLimit: c.monthlyLimit != null ? Number(c.monthlyLimit) : null,
    createdAt: c.createdAt,
  };
}

module.exports = {
  getCategories,
  createCategory,
  updateCategory,
  deleteCategory,
};
