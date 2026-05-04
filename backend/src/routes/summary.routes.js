/**
 * Summary Routes
 */

const { Router } = require('express');
const { requireAuth } = require('../middleware/authMiddleware');
const summaryController = require('../controllers/summary.controller');

const router = Router();
router.use(requireAuth);

router.get('/', summaryController.getSummary);

module.exports = router;
