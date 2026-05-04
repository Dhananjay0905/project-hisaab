/**
 * Recurring Transactions Routes
 *
 * All routes require authentication (JWT access token).
 */

const { Router } = require('express');
const { body } = require('express-validator');
const { requireAuth } = require('../middleware/authMiddleware');
const recurringController = require('../controllers/recurring.controller');

const router = Router();
router.use(requireAuth);

// ─── Validators ───────────────────────────────────────────────────────────────

const createValidators = [
  body('title').trim().notEmpty().withMessage('Title is required.').isLength({ max: 100 }),
  body('amount').isFloat({ gt: 0 }).withMessage('Amount must be a positive number.'),
  body('type').isIn(['INCOME', 'EXPENSE']).withMessage('Type must be INCOME or EXPENSE.'),
  body('categoryId').notEmpty().withMessage('Category is required.'),
  body('frequency')
    .isIn(['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'])
    .withMessage('Frequency must be DAILY, WEEKLY, MONTHLY, or YEARLY.'),
  body('startDate').isISO8601().withMessage('startDate must be a valid ISO 8601 date.'),
];

const updateValidators = [
  body('title').optional().trim().notEmpty().isLength({ max: 100 }),
  body('amount').optional().isFloat({ gt: 0 }),
  body('type').optional().isIn(['INCOME', 'EXPENSE']),
  body('categoryId').optional().notEmpty(),
  body('frequency').optional().isIn(['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY']),
  body('startDate').optional().isISO8601(),
];

// ─── Routes ───────────────────────────────────────────────────────────────────

router.get('/', recurringController.list);
router.get('/due', recurringController.listDue);
router.post('/', createValidators, recurringController.create);
router.put('/:id', updateValidators, recurringController.update);
router.patch('/:id/toggle', recurringController.toggle);
router.post('/:id/confirm', recurringController.confirm);
router.delete('/:id', recurringController.remove);

module.exports = router;
