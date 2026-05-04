/**
 * Transactions Routes
 *
 * All routes require authentication.
 */

const { Router } = require('express');
const { body, query } = require('express-validator');
const { requireAuth } = require('../middleware/authMiddleware');
const transactionsController = require('../controllers/transactions.controller');

const router = Router();
router.use(requireAuth);

// ─── Validators ───────────────────────────────────────────────────────────────

const createValidators = [
  body('title')
    .trim()
    .notEmpty().withMessage('Title is required.')
    .isLength({ max: 100 }).withMessage('Title cannot exceed 100 characters.'),
  body('amount')
    .isFloat({ gt: 0 }).withMessage('Amount must be a positive number.'),
  body('type')
    .isIn(['INCOME', 'EXPENSE']).withMessage('Type must be INCOME or EXPENSE.'),
  body('date')
    .optional()
    .isISO8601().withMessage('Date must be a valid ISO 8601 date string.'),
  body('categoryId')
    .optional({ nullable: true })
    .isString(),
  body('note')
    .optional({ nullable: true })
    .isLength({ max: 500 }).withMessage('Note cannot exceed 500 characters.'),
];

const updateValidators = [
  body('title')
    .optional()
    .trim()
    .notEmpty().withMessage('Title cannot be empty.')
    .isLength({ max: 100 }),
  body('amount')
    .optional()
    .isFloat({ gt: 0 }).withMessage('Amount must be a positive number.'),
  body('type')
    .optional()
    .isIn(['INCOME', 'EXPENSE']),
  body('date')
    .optional()
    .isISO8601(),
  body('categoryId')
    .optional({ nullable: true }),
  body('note')
    .optional({ nullable: true })
    .isLength({ max: 500 }),
];

// ─── Routes ───────────────────────────────────────────────────────────────────

router.get('/', transactionsController.getTransactions);
router.get('/:id', transactionsController.getTransaction);
router.post('/', createValidators, transactionsController.createTransaction);
router.put('/:id', updateValidators, transactionsController.updateTransaction);
router.delete('/:id', transactionsController.deleteTransaction);

module.exports = router;
