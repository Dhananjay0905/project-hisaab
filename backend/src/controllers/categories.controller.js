/**
 * Categories Controller
 * Thin HTTP adapter — all business logic lives in categories.service.js
 */

const { validationResult } = require('express-validator');
const { sendSuccess } = require('../utils/response');
const { createError } = require('../middleware/errorHandler');
const categoriesService = require('../services/categories.service');

// ─── GET /api/categories ──────────────────────────────────────────────────────

async function getCategories(req, res, next) {
  try {
    const categories = await categoriesService.getCategories(req.user.id);
    sendSuccess(res, { categories });
  } catch (err) {
    next(err);
  }
}

// ─── POST /api/categories ─────────────────────────────────────────────────────

async function createCategory(req, res, next) {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return next(createError('Validation failed.', 422, 'VALIDATION_ERROR', { errors: errors.array() }));
    }

    const { name, emoji, type, monthlyLimit } = req.body;
    const category = await categoriesService.createCategory(req.user.id, { name, emoji, type, monthlyLimit });
    sendSuccess(res, { category }, 201);
  } catch (err) {
    next(err);
  }
}

// ─── PUT /api/categories/:id ──────────────────────────────────────────────────

async function updateCategory(req, res, next) {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return next(createError('Validation failed.', 422, 'VALIDATION_ERROR', { errors: errors.array() }));
    }

    const { name, emoji, monthlyLimit } = req.body;
    const category = await categoriesService.updateCategory(req.user.id, req.params.id, { name, emoji, monthlyLimit });
    sendSuccess(res, { category });
  } catch (err) {
    next(err);
  }
}

// ─── DELETE /api/categories/:id ───────────────────────────────────────────────

async function deleteCategory(req, res, next) {
  try {
    const result = await categoriesService.deleteCategory(req.user.id, req.params.id);
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getCategories,
  createCategory,
  updateCategory,
  deleteCategory,
};
