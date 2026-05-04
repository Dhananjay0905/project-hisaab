/**
 * JWT utilities — access token (15m) + refresh token (30d).
 * Refresh tokens are stored in the database for rotation and revocation.
 */

const jwt = require('jsonwebtoken');
const crypto = require('crypto');

const ACCESS_SECRET = () => {
  if (!process.env.JWT_ACCESS_SECRET) throw new Error('JWT_ACCESS_SECRET not set');
  return process.env.JWT_ACCESS_SECRET;
};

const REFRESH_SECRET = () => {
  if (!process.env.JWT_REFRESH_SECRET) throw new Error('JWT_REFRESH_SECRET not set');
  return process.env.JWT_REFRESH_SECRET;
};

const ACCESS_EXPIRES = process.env.JWT_ACCESS_EXPIRES_IN || '15m';
const REFRESH_EXPIRES = process.env.JWT_REFRESH_EXPIRES_IN || '30d';

/**
 * Signs and returns a short-lived access token.
 * @param {{ id: string, email: string }} payload
 * @returns {string}
 */
function signAccessToken(payload) {
  return jwt.sign(
    { sub: payload.id, email: payload.email },
    ACCESS_SECRET(),
    { expiresIn: ACCESS_EXPIRES, algorithm: 'HS256' }
  );
}

/**
 * Verifies an access token and returns the decoded payload.
 * Throws JsonWebTokenError / TokenExpiredError on failure.
 * @param {string} token
 * @returns {{ sub: string, email: string, iat: number, exp: number }}
 */
function verifyAccessToken(token) {
  return jwt.verify(token, ACCESS_SECRET(), { algorithms: ['HS256'] });
}

/**
 * Generates a cryptographically random opaque refresh token string.
 * The actual JWT-like structure is NOT used for refresh tokens —
 * we use random bytes stored in the DB instead.
 * @returns {string} 64-char hex string
 */
function generateRefreshToken() {
  return crypto.randomBytes(32).toString('hex');
}

/**
 * Computes the expiry date of a new refresh token.
 * @returns {Date}
 */
function refreshTokenExpiresAt() {
  const ms = parseDurationToMs(REFRESH_EXPIRES);
  return new Date(Date.now() + ms);
}

/**
 * Parses a duration string like "30d", "15m", "1h" to milliseconds.
 * @param {string} duration
 * @returns {number}
 */
function parseDurationToMs(duration) {
  const match = duration.match(/^(\d+)(s|m|h|d)$/);
  if (!match) throw new Error(`Invalid duration: ${duration}`);
  const [, amount, unit] = match;
  const n = parseInt(amount, 10);
  const multipliers = { s: 1000, m: 60000, h: 3600000, d: 86400000 };
  return n * multipliers[unit];
}

/**
 * Generates a secure one-time token for email verification / password reset.
 * @returns {string}
 */
function generateOneTimeToken() {
  return crypto.randomBytes(32).toString('hex');
}

module.exports = {
  signAccessToken,
  verifyAccessToken,
  generateRefreshToken,
  refreshTokenExpiresAt,
  generateOneTimeToken,
};
