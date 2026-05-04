/**
 * auth middleware — verifies the Bearer access token on every protected route.
 * Attaches `req.user = { id, email }` on success.
 */

const { verifyAccessToken } = require('../utils/jwt');
const { sendError } = require('../utils/response');

function requireAuth(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return sendError(res, 'Authentication required.', 401, 'UNAUTHENTICATED');
  }

  const token = authHeader.slice(7);
  try {
    const payload = verifyAccessToken(token);
    req.user = { id: payload.sub, email: payload.email };
    return next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return sendError(res, 'Session expired. Please refresh your token.', 401, 'TOKEN_EXPIRED');
    }
    return sendError(res, 'Invalid or malformed token.', 401, 'INVALID_TOKEN');
  }
}

module.exports = { requireAuth };
