/**
 * Savings Controller — thin HTTP adapter over savings.service
 */

const { sendSuccess } = require('../utils/response');
const savingsService = require('../services/savings.service');

// GET /api/savings
async function getSavings(req, res, next) {
  try {
    const data = await savingsService.getSavings(req.user.id);
    sendSuccess(res, data);
  } catch (err) {
    next(err);
  }
}

// PATCH /api/savings
async function updateSavings(req, res, next) {
  try {
    const { totalAmount, cashDeduction, deductFromBalance } = req.body;
    const data = await savingsService.updateSavings(req.user.id, {
      totalAmount: totalAmount !== undefined ? Number(totalAmount) : undefined,
      cashDeduction: cashDeduction !== undefined ? Number(cashDeduction) : undefined,
      deductFromBalance: deductFromBalance !== undefined ? deductFromBalance : undefined,
    });
    sendSuccess(res, data);
  } catch (err) {
    next(err);
  }
}

module.exports = { getSavings, updateSavings };
