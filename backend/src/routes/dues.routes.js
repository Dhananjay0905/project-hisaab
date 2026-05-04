/**
 * Dues Routes
 *
 * All routes require authentication.
 */

const { Router } = require('express');
const { body } = require('express-validator');
const { requireAuth } = require('../middleware/authMiddleware');
const duesController = require('../controllers/dues.controller');

const router = Router();
router.use(requireAuth);

// ─── Validators ───────────────────────────────────────────────────────────────

const createValidators = [
  body('title')
    .trim()
    .notEmpty().withMessage('Title is required.')
    .isLength({ max: 100 }).withMessage('Title cannot exceed 100 characters.'),
  body('personName')
    .trim()
    .notEmpty().withMessage('Person name is required.')
    .isLength({ max: 100 }).withMessage('Person name cannot exceed 100 characters.'),
  body('amount')
    .isFloat({ gt: 0 }).withMessage('Amount must be a positive number.'),
  body('type')
    .isIn(['I_OWE', 'THEY_OWE']).withMessage('Type must be I_OWE or THEY_OWE.'),
  body('dueDate')
    .optional({ nullable: true })
    .isISO8601().withMessage('Due date must be a valid ISO 8601 date.'),
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
  body('personName')
    .optional()
    .trim()
    .notEmpty().withMessage('Person name cannot be empty.')
    .isLength({ max: 100 }),
  body('amount')
    .optional()
    .isFloat({ gt: 0 }).withMessage('Amount must be a positive number.'),
  body('type')
    .optional()
    .isIn(['I_OWE', 'THEY_OWE']),
  body('dueDate')
    .optional({ nullable: true })
    .isISO8601(),
  body('note')
    .optional({ nullable: true })
    .isLength({ max: 500 }),
];

// ─── Routes ───────────────────────────────────────────────────────────────────

router.get('/summary', duesController.getDuesSummary);
router.get('/', duesController.getDues);
router.post('/', createValidators, duesController.createDue);
router.put('/:id', updateValidators, duesController.updateDue);
router.post('/:id/settle', duesController.settleDue);
router.delete('/:id', duesController.deleteDue);

module.exports = router;
