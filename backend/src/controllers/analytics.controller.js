/**
 * Analytics Controller
 */

const { sendSuccess } = require('../utils/response');
const analyticsService = require('../services/analytics.service');

async function getMonthlyTrend(req, res, next) {
  try {
    const trend = await analyticsService.getMonthlyTrend(req.user.id);
    sendSuccess(res, { trend });
  } catch (err) {
    next(err);
  }
}

async function getCategorySpend(req, res, next) {
  try {
    const year  = req.query.year  ? parseInt(req.query.year,  10) : undefined;
    const month = req.query.month ? parseInt(req.query.month, 10) : undefined;
    const categories = await analyticsService.getCategorySpend(req.user.id, year, month);
    sendSuccess(res, { categories });
  } catch (err) {
    next(err);
  }
}

module.exports = { getMonthlyTrend, getCategorySpend };
