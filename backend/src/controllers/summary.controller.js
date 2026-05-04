/**
 * Summary Controller
 */

const { sendSuccess } = require('../utils/response');
const summaryService = require('../services/summary.service');

async function getSummary(req, res, next) {
  try {
    const summary = await summaryService.getSummary(req.user.id);
    sendSuccess(res, summary);
  } catch (err) {
    next(err);
  }
}

module.exports = { getSummary };
