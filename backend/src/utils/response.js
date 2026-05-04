/**
 * Standardised API response helpers.
 * All successful responses: { success: true, data: {...} }
 * All error responses:      { success: false, error: { code, message, details? } }
 */

/**
 * @param {import('express').Response} res
 * @param {any} data
 * @param {number} [statusCode=200]
 */
function sendSuccess(res, data, statusCode = 200) {
  return res.status(statusCode).json({ success: true, data });
}

/**
 * @param {import('express').Response} res
 * @param {string} message
 * @param {number} [statusCode=400]
 * @param {string} [code='ERROR']
 * @param {any} [details]
 */
function sendError(res, message, statusCode = 400, code = 'ERROR', details = undefined) {
  const payload = { success: false, error: { code, message } };
  if (details !== undefined) payload.error.details = details;
  return res.status(statusCode).json(payload);
}

/**
 * Paginated list response.
 */
function sendPaginated(res, items, total, page, limit) {
  return res.status(200).json({
    success: true,
    data: {
      items,
      pagination: {
        total,
        page,
        limit,
        pages: Math.ceil(total / limit),
        hasNext: page * limit < total,
        hasPrev: page > 1,
      },
    },
  });
}

module.exports = { sendSuccess, sendError, sendPaginated };
