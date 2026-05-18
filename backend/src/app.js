/**
 * Express application — configured middleware, routes.
 * The server.js file is responsible for listening.
 */

require('dotenv').config();

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');

const { globalLimiter, authLimiter, userLimiter } = require('./middleware/rateLimiter');
const { errorHandler } = require('./middleware/errorHandler');
const { requireAuth } = require('./middleware/authMiddleware');
const { requirePolicy } = require('./middleware/requirePolicy');
const authRoutes = require('./routes/auth.routes');
const categoriesRoutes = require('./routes/categories.routes');
const transactionsRoutes = require('./routes/transactions.routes');
const summaryRoutes = require('./routes/summary.routes');
const duesRoutes = require('./routes/dues.routes');
const splitsRoutes = require('./routes/splits.routes');
const savingsRoutes = require('./routes/savings.routes');
const wishlistRoutes = require('./routes/wishlist.routes');
const recurringRoutes = require('./routes/recurring.routes');
const analyticsRoutes = require('./routes/analytics.routes');

const app = express();

// ── Trust proxy (Render sits behind a reverse proxy) ─────────────────────────
app.set('trust proxy', 1);

// ── Helmet — hardened security headers ───────────────────────────────────────
app.use(
  helmet({
    // Content Security Policy: lock down the two HTML verification pages.
    // All JSON API routes are unaffected (browsers don't execute JSON as HTML).
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'none'"],
        styleSrc:   ["'unsafe-inline'"],   // inline styles in verification HTML only
        imgSrc:     ["'none'"],
        scriptSrc:  ["'none'"],
        frameAncestors: ["'none'"],
      },
    },
    // Prevent MIME-type sniffing
    noSniff: true,
    // Force HTTPS in production (1 year, include subdomains)
    hsts: {
      maxAge: 31536000,
      includeSubDomains: true,
      preload: true,
    },
    // Don't send the Referer header to cross-origin destinations
    referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
    // No embedding in iframes anywhere
    frameguard: { action: 'deny' },
    // Hide Express
    hidePoweredBy: true,
    // Disable browser DNS prefetching
    dnsPrefetchControl: { allow: false },
    // Disable IE-specific XSS filter (modern browsers ignore it; it can backfire)
    xssFilter: false,
  })
);

// Permissions-Policy — disable all browser APIs the app never needs
app.use((_req, res, next) => {
  res.setHeader(
    'Permissions-Policy',
    'camera=(), microphone=(), geolocation=(), payment=(), usb=(), interest-cohort=()'
  );
  next();
});

// Cache-Control — prevent proxies/browsers from caching API responses
app.use((_req, res, next) => {
  res.setHeader('Cache-Control', 'no-store');
  next();
});

// ── CORS — fail closed if FRONTEND_URL is not configured ─────────────────────
const ALLOWED_ORIGINS = new Set(
  (process.env.FRONTEND_URL || '').split(',').map((s) => s.trim()).filter(Boolean)
);

app.use(cors({
  origin: function (origin, callback) {
    // Mobile apps and server-to-server (Postman, curl) send no Origin — allow
    if (!origin) return callback(null, true);
    // Localhost is always allowed for local development
    if (origin.startsWith('http://localhost:') || origin.startsWith('http://127.0.0.1:')) {
      return callback(null, origin);
    }
    // Known production origins
    if (ALLOWED_ORIGINS.has(origin)) return callback(null, origin);
    // Fail closed — reject unknown origins
    return callback(new Error(`CORS: origin '${origin}' is not allowed.`));
  },
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
}));

// ── Logging ───────────────────────────────────────────────────────────────────
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));
}

// ── Body parsing ──────────────────────────────────────────────────────────────
app.use(express.json({ limit: '10kb' }));
app.use(express.urlencoded({ extended: true, limit: '10kb' }));

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/health', (_req, res) =>
  res.json({ status: 'ok', version: '1.0.0', timestamp: new Date().toISOString() })
);

// Public Legal routes (loaded dynamically by mobile apps)
app.get('/api/legal', (_req, res) => {
  const legalData = require('./data/legal.json');
  return res.json(legalData);
});

// ── Global rate limiter ───────────────────────────────────────────────────────
app.use(globalLimiter);

// ── API routes ────────────────────────────────────────────────────────────────
// Auth routes — no requirePolicy (login & accept-policy must be accessible)
app.use('/api/auth', authRoutes);

// All other API routes are protected.
// Order: requireAuth (JWT check) → userLimiter (uses req.user.id) → requirePolicy (DB check)
const protectedApi = express.Router();
protectedApi.use(requireAuth);
protectedApi.use(userLimiter);
protectedApi.use(requirePolicy);

protectedApi.use('/categories', categoriesRoutes);
protectedApi.use('/transactions', transactionsRoutes);
protectedApi.use('/summary', summaryRoutes);
protectedApi.use('/dues', duesRoutes);
protectedApi.use('/splits', splitsRoutes);
protectedApi.use('/savings', savingsRoutes);
protectedApi.use('/wishlist', wishlistRoutes);
protectedApi.use('/recurring', recurringRoutes);
protectedApi.use('/analytics', analyticsRoutes);

app.use('/api', protectedApi);

// ── 404 handler ───────────────────────────────────────────────────────────────
app.use((_req, res) =>
  res.status(404).json({
    success: false,
    error: { code: 'NOT_FOUND', message: 'The requested endpoint does not exist.' },
  })
);

// ── Global error handler ──────────────────────────────────────────────────────
app.use(errorHandler);

module.exports = app;
