/**
 * Auth routes
 * Base path: /api/auth
 */

const { Router } = require('express');
const ctrl = require('../controllers/auth.controller');
const { requireAuth } = require('../middleware/authMiddleware');
const { authLimiter } = require('../middleware/rateLimiter');
const { checkBruteForce } = require('../middleware/bruteForce');

const router = Router();

// ── Public routes (rate-limited) ──────────────────────────────────────────────

// POST /api/auth/register
router.post('/register', authLimiter, ctrl.registerValidation, ctrl.register);

// GET  /api/auth/verify-email?token=xxx
router.get('/verify-email', ctrl.verifyEmail);

// POST /api/auth/resend-verification
router.post('/resend-verification', authLimiter, ctrl.resendVerificationValidation, ctrl.resendVerification);

// POST /api/auth/login
// Order: IP rate-limit → exponential backoff check → input validation → handler
router.post('/login', authLimiter, checkBruteForce, ctrl.loginValidation, ctrl.login);

// POST /api/auth/refresh   { refreshToken }
router.post('/refresh', authLimiter, ctrl.refresh);

// POST /api/auth/logout    { refreshToken }
router.post('/logout', authLimiter, ctrl.logout);

// POST /api/auth/forgot-password   { email }
router.post('/forgot-password', authLimiter, ctrl.forgotPasswordValidation, ctrl.forgotPassword);

// POST /api/auth/reset-password    { token, newPassword }
router.post('/reset-password', authLimiter, ctrl.resetPasswordValidation, ctrl.resetPassword);

// ── Public email-change links (accessed via browser from email) ───────────────

// GET /api/auth/confirm-email-change?token=xxx   (link in current email)
router.get('/confirm-email-change', ctrl.confirmEmailChange);

// GET /api/auth/verify-new-email?token=xxx        (link in new email)
router.get('/verify-new-email', ctrl.verifyNewEmail);

// GET /api/auth/reset-redirect?token=xxx         (redirects to Hisaab app via deep link)
router.get('/reset-redirect', ctrl.resetRedirect);

// ── Protected routes ──────────────────────────────────────────────────────────

// GET  /api/auth/me
router.get('/me', requireAuth, ctrl.getMe);

// PATCH /api/auth/profile   { name }
router.patch('/profile', requireAuth, ctrl.updateNameValidation, ctrl.updateName);

// POST /api/auth/request-email-change   { newEmail }
router.post('/request-email-change', requireAuth, ctrl.requestEmailChangeValidation, ctrl.requestEmailChange);

// POST /api/auth/change-password   { currentPassword, newPassword }
router.post('/change-password', requireAuth, ctrl.changePasswordValidation, ctrl.changePassword);

// DELETE /api/auth/delete-account   { password }
router.delete('/delete-account', requireAuth, ctrl.deleteAccountValidation, ctrl.deleteAccount);

// POST /api/auth/accept-policy
// requireAuth only — no requirePolicy (that would be a catch-22 for users who haven't accepted yet)
router.post('/accept-policy', requireAuth, ctrl.acceptPolicy);

module.exports = router;
