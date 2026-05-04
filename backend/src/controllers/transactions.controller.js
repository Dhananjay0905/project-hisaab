/**
 * Transactions Controller
 * Thin HTTP adapter — all business logic in transactions.service.js
 */

const { validationResult } = require('express-validator');
const { sendSuccess, sendPaginated } = require('../utils/response');
const { createError } = require('../middleware/errorHandler');
const transactionsService = require('../services/transactions.service');

async function getTransactions(req, res, next) {
  try {
    const result = await transactionsService.getTransactions(req.user.id, req.query);
    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

async function getTransaction(req, res, next) {
  try {
    const tx = await transactionsService.getTransaction(req.user.id, req.params.id);
    sendSuccess(res, { transaction: tx });
  } catch (err) {
    next(err);
  }
}

async function createTransaction(req, res, next) {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return next(createError('Validation failed.', 422, 'VALIDATION_ERROR', { errors: errors.array() }));
    }
    const tx = await transactionsService.createTransaction(req.user.id, req.body);
    sendSuccess(res, { transaction: tx }, 201);
  } catch (err) {
    next(err);
  }
}

async function updateTransaction(req, res, next) {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return next(createError('Validation failed.', 422, 'VALIDATION_ERROR', { errors: errors.array() }));
    }
    const tx = await transactionsService.updateTransaction(req.user.id, req.params.id, req.body);
    sendSuccess(res, { transaction: tx });
  } catch (err) {
    next(err);
  }
}

async function deleteTransaction(req, res, next) {
  try {
    const result = await transactionsService.deleteTransaction(req.user.id, req.params.id);
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getTransactions,
  getTransaction,
  createTransaction,
  updateTransaction,
  deleteTransaction,
};
