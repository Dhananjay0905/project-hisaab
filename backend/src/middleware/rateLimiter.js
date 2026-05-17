/**
 * Rate limiter configurations.
 *
 * Three layers:
 *  1. globalLimiter  — 100 req/15min per IP.  Applied to ALL routes globally.
 *                      Catches unauthenticated abuse and unrecognised bots.
 *  2. authLimiter    — 10 req/15min per IP.   Applied to all auth endpoints
 *                      (login, register, refresh, logout, forgot-password etc.)
 *  3. userLimiter    — 300 req/15min per USER. Applied to protected API routes.
 *                      Uses req.user.id as key so shared IPs (offices, VPNs)
 *                      don't consume each other's quota.
 *
 * All limiters use the standard RateLimit-* headers (RFC 6585).
 */

const rateLimit = require('express-rate-limit');

const windowMs = parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000', 10); // 15 min

// ── 1. Global (IP-based) — unauthenticated / catch-all ───────────────────────
const globalLimiter = rateLimit({
  windowMs,
  max: parseInt(process.env.RATE_LIMIT_MAX || '100', 10),
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    error: { code: 'RATE_LIMITED', message: 'Too many requests. Please try again later.' },
  },
});

// ── 2. Auth (IP-based) — strict limit for authentication endpoints ────────────
const authLimiter = rateLimit({
  windowMs,
  max: parseInt(process.env.AUTH_RATE_LIMIT_MAX || '10', 10),
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    error: { code: 'RATE_LIMITED', message: 'Too many attempts. Please try again in 15 minutes.' },
  },
});

// ── 3. User (userId-based) — per-authenticated-user quota ────────────────────
const userLimiter = rateLimit({
  windowMs,
  max: parseInt(process.env.USER_RATE_LIMIT_MAX || '300', 10),
  standardHeaders: true,
  legacyHeaders: false,
  // Key by authenticated user ID so NAT/VPN users don't share quota
  keyGenerator: (req) => req.user?.id || req.ip,
  skip: (req) => !req.user, // only applies after requireAuth has set req.user
  message: {
    success: false,
    error: {
      code: 'RATE_LIMITED',
      message: 'You are making too many requests. Please slow down.',
    },
  },
});

module.exports = { globalLimiter, authLimiter, userLimiter };

