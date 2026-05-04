/**
 * Global error handler — last middleware in the Express chain.
 * Converts all unhandled errors to a consistent JSON response.
 */

const { sendError } = require('../utils/response');

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  const isDev = process.env.NODE_ENV !== 'production';

  // Log error details (always)
  console.error(`[ERROR] ${req.method} ${req.path}`, err.message);
  if (isDev) console.error(err.stack);

  // Prisma errors
  if (err.code === 'P2002') {
    const field = err.meta?.target?.[0] ?? 'field';
    return sendError(res, `${field} is already in use.`, 409, 'CONFLICT');
  }
  if (err.code === 'P2025') {
    return sendError(res, 'Resource not found.', 404, 'NOT_FOUND');
  }

  // Known app errors
  if (err.statusCode) {
    return sendError(res, err.message, err.statusCode, err.code || 'ERROR');
  }

  // JWT errors
  if (err.name === 'JsonWebTokenError' || err.name === 'TokenExpiredError') {
    return sendError(res, 'Invalid or expired token.', 401, 'INVALID_TOKEN');
  }

  // Default 500
  return sendError(
    res,
    isDev ? err.message : 'An unexpected error occurred.',
    500,
    'INTERNAL_ERROR'
  );
}

/**
 * Creates a structured app error with statusCode.
 * @param {string} message
 * @param {number} statusCode
 * @param {string} code
 * @returns {Error}
 */
function createError(message, statusCode = 400, code = 'ERROR') {
  const err = new Error(message);
  err.statusCode = statusCode;
  err.code = code;
  return err;
}

module.exports = { errorHandler, createError };
