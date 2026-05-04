/**
 * Validation middleware using express-validator.
 * Checks for validation errors and sends a 422 response.
 */

const { validationResult } = require('express-validator');
const { sendError } = require('../utils/response');

/**
 * Run after a chain of express-validator checks.
 * Collects errors and responds with 422 + field details if any found.
 */
function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    const fieldErrors = {};
    errors.array().forEach(({ path, msg }) => {
      if (!fieldErrors[path]) fieldErrors[path] = msg;
    });
    return sendError(
      res,
      'Validation failed. Please check the highlighted fields.',
      422,
      'VALIDATION_ERROR',
      fieldErrors
    );
  }
  return next();
}

module.exports = { validate };
