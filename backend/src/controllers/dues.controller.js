/**
 * Dues Controller
 * Thin HTTP adapter — all business logic in dues.service.js
 */

const { validationResult } = require('express-validator');
const { sendSuccess } = require('../utils/response');
const { createError } = require('../middleware/errorHandler');
const duesService = require('../services/dues.service');

async function getDues(req, res, next) {
  try {
    const dues = await duesService.getDues(req.user.id, req.query);
    sendSuccess(res, { dues });
  } catch (err) {
    next(err);
  }
}

async function getDuesSummary(req, res, next) {
  try {
    const summary = await duesService.getDuesSummary(req.user.id);
    sendSuccess(res, { summary });
  } catch (err) {
    next(err);
  }
}

async function createDue(req, res, next) {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return next(createError('Validation failed.', 422, 'VALIDATION_ERROR', { errors: errors.array() }));
    }
    const due = await duesService.createDue(req.user.id, req.body);
    sendSuccess(res, { due }, 201);
  } catch (err) {
    next(err);
  }
}

async function updateDue(req, res, next) {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return next(createError('Validation failed.', 422, 'VALIDATION_ERROR', { errors: errors.array() }));
    }
    const due = await duesService.updateDue(req.user.id, req.params.id, req.body);
    sendSuccess(res, { due });
  } catch (err) {
    next(err);
  }
}

async function settleDue(req, res, next) {
  try {
    const logAsTransaction = req.body.logAsTransaction === true;
    const due = await duesService.settleDue(req.user.id, req.params.id, { logAsTransaction });
    sendSuccess(res, { due });
  } catch (err) {
    next(err);
  }
}

async function deleteDue(req, res, next) {
  try {
    const result = await duesService.deleteDue(req.user.id, req.params.id);
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getDues,
  getDuesSummary,
  createDue,
  updateDue,
  settleDue,
  deleteDue,
};
