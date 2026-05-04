/**
 * Analytics Routes
 * GET /api/analytics/monthly  — last 6 months income vs expense
 * GET /api/analytics/categories — current month spending by category
 */

const { Router } = require('express');
const { requireAuth } = require('../middleware/authMiddleware');
const analyticsController = require('../controllers/analytics.controller');

const router = Router();
router.use(requireAuth);

router.get('/monthly',    analyticsController.getMonthlyTrend);
router.get('/categories', analyticsController.getCategorySpend);

module.exports = router;
