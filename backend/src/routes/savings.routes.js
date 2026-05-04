/**
 * Savings Routes
 *
 * GET  /api/savings       — get (or auto-create) savings record with computed totals
 * PATCH /api/savings      — update totalAmount and/or cashDeduction
 *
 * All routes require authentication.
 */

const { Router } = require('express');
const { body } = require('express-validator');
const { requireAuth } = require('../middleware/authMiddleware');
const { validate } = require('../middleware/validate');
const savingsController = require('../controllers/savings.controller');

const router = Router();
router.use(requireAuth);

const updateValidators = [
  body('totalAmount')
    .optional()
    .isFloat({ min: 0 }).withMessage('Total amount must be 0 or greater.'),
  body('cashDeduction')
    .optional()
    .isFloat({ min: 0 }).withMessage('Cash deduction must be 0 or greater.'),
  body('deductFromBalance')
    .optional()
    .isBoolean().withMessage('deductFromBalance must be a boolean.'),
];

router.get('/', savingsController.getSavings);
router.patch('/', updateValidators, validate, savingsController.updateSavings);

module.exports = router;
