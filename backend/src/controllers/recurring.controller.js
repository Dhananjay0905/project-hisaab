/**
 * Recurring Transactions Controller
 */

const { validationResult } = require('express-validator');
const { createError } = require('../middleware/errorHandler');
const recurringService = require('../services/recurring.service');

function _validate(req) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw createError('Validation failed.', 422, 'VALIDATION_ERROR', {
      errors: Object.fromEntries(errors.array().map((e) => [e.path, e.msg])),
    });
  }
}

async function list(req, res, next) {
  try {
    const items = await recurringService.listRecurring(req.user.id);
    res.json({ success: true, data: items });
  } catch (err) {
    next(err);
  }
}

async function listDue(req, res, next) {
  try {
    const items = await recurringService.listDue(req.user.id);
    res.json({ success: true, data: items });
  } catch (err) {
    next(err);
  }
}

async function create(req, res, next) {
  try {
    _validate(req);
    const item = await recurringService.createRecurring(req.user.id, req.body);
    res.status(201).json({ success: true, data: item });
  } catch (err) {
    next(err);
  }
}

async function update(req, res, next) {
  try {
    _validate(req);
    const item = await recurringService.updateRecurring(req.user.id, req.params.id, req.body);
    res.json({ success: true, data: item });
  } catch (err) {
    next(err);
  }
}

async function toggle(req, res, next) {
  try {
    const item = await recurringService.toggleActive(req.user.id, req.params.id);
    res.json({ success: true, data: item });
  } catch (err) {
    next(err);
  }
}

async function confirm(req, res, next) {
  try {
    const result = await recurringService.confirmDue(req.user.id, req.params.id);
    res.json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

async function remove(req, res, next) {
  try {
    const result = await recurringService.deleteRecurring(req.user.id, req.params.id);
    res.json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

module.exports = { list, listDue, create, update, toggle, confirm, remove };
