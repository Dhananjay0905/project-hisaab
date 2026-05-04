/**
 * splits.controller.js — HTTP adapter for splits routes.
 * Thin layer: validate → call service → send response.
 */

const { validationResult } = require('express-validator');
const { sendSuccess, sendError } = require('../utils/response');
const splitsService = require('../services/splits.service');

// ── List ──────────────────────────────────────────────────────────────────────

async function listSplits(req, res, next) {
  try {
    const splits = await splitsService.listSplits(req.user.id);
    return sendSuccess(res, splits);
  } catch (err) {
    next(err);
  }
}

// ── Get one ───────────────────────────────────────────────────────────────────

async function getSplit(req, res, next) {
  try {
    const split = await splitsService.getSplit(req.user.id, req.params.id);
    return sendSuccess(res, split);
  } catch (err) {
    if (err.message === 'Split not found.') return sendError(res, 404, 'SPLIT_NOT_FOUND', err.message);
    next(err);
  }
}

// ── Create ────────────────────────────────────────────────────────────────────

async function createSplit(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return sendError(res, 422, 'VALIDATION_ERROR', errors.array()[0].msg);
  }

  try {
    const { title, totalAmount, participantNames, note, date } = req.body;
    const split = await splitsService.createSplit(req.user.id, {
      title,
      totalAmount: Number(totalAmount),
      participantNames,
      note,
      date,
    });
    return sendSuccess(res, split, 201);
  } catch (err) {
    next(err);
  }
}

// ── Update ────────────────────────────────────────────────────────────────────

async function updateSplit(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return sendError(res, 422, 'VALIDATION_ERROR', errors.array()[0].msg);
  }

  try {
    const { title, note } = req.body;
    const split = await splitsService.updateSplit(req.user.id, req.params.id, { title, note });
    return sendSuccess(res, split);
  } catch (err) {
    if (err.message === 'Split not found.') return sendError(res, 404, 'SPLIT_NOT_FOUND', err.message);
    next(err);
  }
}

// ── Delete ────────────────────────────────────────────────────────────────────

async function deleteSplit(req, res, next) {
  try {
    await splitsService.deleteSplit(req.user.id, req.params.id);
    return sendSuccess(res, { message: 'Split deleted.' });
  } catch (err) {
    if (err.message === 'Split not found.') return sendError(res, 404, 'SPLIT_NOT_FOUND', err.message);
    next(err);
  }
}

// ── Mark participant paid ─────────────────────────────────────────────────────

async function markParticipantPaid(req, res, next) {
  try {
    const { createTransaction = false, paidAmount } = req.body;
    const result = await splitsService.markParticipantPaid(
      req.user.id,
      req.params.id,
      req.params.pid,
      Boolean(createTransaction),
      paidAmount != null ? Number(paidAmount) : undefined,
    );
    return sendSuccess(res, result);
  } catch (err) {
    const notFound = ['Split not found.', 'Participant not found.', 'Participant has already paid.'];
    if (notFound.includes(err.message)) {
      return sendError(res, 400, 'BAD_REQUEST', err.message);
    }
    next(err);
  }
}

// ── Unmark participant paid ───────────────────────────────────────────────────

async function unmarkParticipantPaid(req, res, next) {
  try {
    const participant = await splitsService.unmarkParticipantPaid(
      req.user.id,
      req.params.id,
      req.params.pid,
    );
    return sendSuccess(res, participant);
  } catch (err) {
    const notFound = ['Split not found.', 'Participant not found.'];
    if (notFound.includes(err.message)) {
      return sendError(res, 404, 'NOT_FOUND', err.message);
    }
    next(err);
  }
}

module.exports = {
  listSplits,
  getSplit,
  createSplit,
  updateSplit,
  deleteSplit,
  markParticipantPaid,
  unmarkParticipantPaid,
};
