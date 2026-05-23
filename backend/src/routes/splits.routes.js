/**
 * splits.routes.js — Express router for /api/splits
 */

const { Router } = require('express');
const { body } = require('express-validator');
const ctrl = require('../controllers/splits.controller');

const router = Router();

// All routes require auth

// ── Validation chains ─────────────────────────────────────────────────────────

const createValidation = [
  body('title').trim().notEmpty().withMessage('Title is required.'),
  body('totalAmount')
    .isFloat({ gt: 0 })
    .withMessage('Total amount must be a positive number.'),
  body('participantNames')
    .isArray({ min: 1 })
    .withMessage('At least one participant name is required.'),
  body('participantNames.*')
    .trim()
    .notEmpty()
    .withMessage('Participant names must be non-empty strings.'),
  body('note').optional().trim(),
  body('date').optional().isISO8601().withMessage('date must be a valid ISO date.'),
  body('logAsExpense').optional().isBoolean().withMessage('logAsExpense must be a boolean.'),
];

const updateValidation = [
  body('title').optional().trim().notEmpty().withMessage('Title must not be empty.'),
  body('note').optional({ nullable: true }).trim(),
];

// ── Routes ────────────────────────────────────────────────────────────────────

router.get('/', ctrl.listSplits);
router.get('/:id', ctrl.getSplit);
router.post('/', createValidation, ctrl.createSplit);
router.put('/:id', updateValidation, ctrl.updateSplit);
router.delete('/:id', ctrl.deleteSplit);

// Participant pay/unpay
router.patch('/:id/participants/:pid/pay', ctrl.markParticipantPaid);
router.patch('/:id/participants/:pid/unpay', ctrl.unmarkParticipantPaid);

module.exports = router;
