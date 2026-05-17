/**
 * Categories Routes
 *
 * All routes require authentication (JWT access token).
 * Validation is handled inline with express-validator.
 */

const { Router } = require('express');
const { body } = require('express-validator');
const categoriesController = require('../controllers/categories.controller');

const router = Router();

// Apply auth to all category routes

// ─── Validators ───────────────────────────────────────────────────────────────

const createValidators = [
  body('name')
    .trim()
    .notEmpty().withMessage('Category name is required.')
    .isLength({ max: 50 }).withMessage('Name cannot exceed 50 characters.'),
  body('emoji')
    .trim()
    .notEmpty().withMessage('Emoji is required.'),
  body('type')
    .isIn(['INCOME', 'EXPENSE']).withMessage('Type must be INCOME or EXPENSE.'),
  body('monthlyLimit')
    .optional({ nullable: true })
    .isFloat({ min: 0 }).withMessage('Monthly limit must be a positive number.'),
];

const updateValidators = [
  body('name')
    .optional()
    .trim()
    .notEmpty().withMessage('Name cannot be empty.')
    .isLength({ max: 50 }).withMessage('Name cannot exceed 50 characters.'),
  body('emoji')
    .optional()
    .trim()
    .notEmpty().withMessage('Emoji cannot be empty.'),
  body('monthlyLimit')
    .optional({ nullable: true })
    .isFloat({ min: 0 }).withMessage('Monthly limit must be a positive number.'),
];

// ─── Routes ───────────────────────────────────────────────────────────────────

router.get('/', categoriesController.getCategories);
router.post('/', createValidators, categoriesController.createCategory);
router.put('/:id', updateValidators, categoriesController.updateCategory);
router.delete('/:id', categoriesController.deleteCategory);

module.exports = router;
