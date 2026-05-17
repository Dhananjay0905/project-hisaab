/**
 * Analytics Routes
 * GET /api/analytics/monthly  — last 6 months income vs expense
 * GET /api/analytics/categories — current month spending by category
 */

const { Router } = require('express');
const analyticsController = require('../controllers/analytics.controller');

const router = Router();

router.get('/monthly',    analyticsController.getMonthlyTrend);
router.get('/categories', analyticsController.getCategorySpend);

module.exports = router;
