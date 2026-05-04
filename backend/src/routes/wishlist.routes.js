/**
 * Wishlist Routes
 *
 * GET    /api/wishlist              — list all items (unpurchased first)
 * POST   /api/wishlist              — create item
 * PUT    /api/wishlist/:id          — update item
 * PATCH  /api/wishlist/:id/deduct   — toggle deductFromSavings
 * PATCH  /api/wishlist/:id/purchase — mark as purchased
 * DELETE /api/wishlist/:id          — soft delete
 *
 * All routes require authentication.
 */

const { Router } = require('express');
const { body } = require('express-validator');
const { requireAuth } = require('../middleware/authMiddleware');
const { validate } = require('../middleware/validate');
const wishlistController = require('../controllers/wishlist.controller');

const router = Router();
router.use(requireAuth);

// ─── Validators ───────────────────────────────────────────────────────────────

const createValidators = [
  body('title')
    .trim()
    .notEmpty().withMessage('Title is required.')
    .isLength({ max: 100 }).withMessage('Title cannot exceed 100 characters.'),
  body('emoji')
    .optional()
    .trim()
    .notEmpty().withMessage('Emoji cannot be empty.'),
  body('targetPrice')
    .optional({ nullable: true })
    .isFloat({ min: 0 }).withMessage('Target price must be 0 or greater.'),
  body('amountSaved')
    .optional()
    .isFloat({ min: 0 }).withMessage('Amount saved must be 0 or greater.'),
  body('deductFromSavings')
    .optional()
    .isBoolean().withMessage('deductFromSavings must be a boolean.'),
  body('link')
    .optional({ nullable: true })
    .isURL().withMessage('Link must be a valid URL.'),
];

const updateValidators = [
  body('title')
    .optional()
    .trim()
    .notEmpty().withMessage('Title cannot be empty.')
    .isLength({ max: 100 }),
  body('emoji')
    .optional()
    .trim()
    .notEmpty(),
  body('targetPrice')
    .optional({ nullable: true })
    .isFloat({ min: 0 }),
  body('amountSaved')
    .optional()
    .isFloat({ min: 0 }),
  body('deductFromSavings')
    .optional()
    .isBoolean(),
  body('link')
    .optional({ nullable: true })
    .isURL(),
];

// ─── Routes ───────────────────────────────────────────────────────────────────

router.get('/', wishlistController.listWishlist);
router.post('/', createValidators, validate, wishlistController.createWishlistItem);
router.put('/:id', updateValidators, validate, wishlistController.updateWishlistItem);
router.patch('/:id/deduct', wishlistController.toggleDeduct);
router.patch('/:id/purchase', wishlistController.markPurchased);
router.delete('/:id', wishlistController.deleteWishlistItem);

module.exports = router;
