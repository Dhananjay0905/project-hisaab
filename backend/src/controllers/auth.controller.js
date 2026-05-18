/**
 * Auth Controller — thin HTTP adapter layer.
 * Validates input, calls service, returns HTTP response.
 */

const { body, query } = require('express-validator');
const authService = require('../services/auth.service');
const { sendSuccess, sendError } = require('../utils/response');
const { validate } = require('../middleware/validate');
const { recordFailedAttempt, clearFailedAttempts } = require('../middleware/bruteForce');

// ── Security helper ───────────────────────────────────────────────────────────

/**
 * Escapes special HTML characters to prevent reflected XSS in HTML responses.
 * Used only for the browser-facing email verification pages.
 * @param {string} str
 * @returns {string}
 */
function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;');
}

// ─── Validation Chains ────────────────────────────────────────────────────────

const registerValidation = [
  body('name')
    .trim()
    .isLength({ min: 2, max: 60 })
    .withMessage('Name must be 2–60 characters.'),
  body('email')
    .trim()
    .isEmail()
    .normalizeEmail()
    .withMessage('Please provide a valid email address.'),
  body('password')
    .isLength({ min: 8 })
    .withMessage('Password must be at least 8 characters.')
    .matches(/[A-Za-z]/)
    .withMessage('Password must contain at least one letter.')
    .matches(/[0-9]/)
    .withMessage('Password must contain at least one number.'),
  body('currency').optional().isString().isLength({ min: 3, max: 3 }),
  body('currencySymbol').optional().isString().isLength({ min: 1, max: 5 }),
  body('openingBalance').optional().isFloat({ min: 0 }).withMessage('Opening balance must be a positive number.'),
  validate,
];

const loginValidation = [
  body('email').trim().isEmail().normalizeEmail().withMessage('Please provide a valid email address.'),
  body('password').notEmpty().withMessage('Password is required.'),
  validate,
];

const forgotPasswordValidation = [
  body('email').trim().isEmail().normalizeEmail().withMessage('Please provide a valid email address.'),
  validate,
];

const resetPasswordValidation = [
  body('token').notEmpty().withMessage('Reset token is required.'),
  body('newPassword')
    .isLength({ min: 8 })
    .withMessage('Password must be at least 8 characters.')
    .matches(/[A-Za-z]/)
    .withMessage('Password must contain at least one letter.')
    .matches(/[0-9]/)
    .withMessage('Password must contain at least one number.'),
  validate,
];

const resendVerificationValidation = [
  body('email').trim().isEmail().normalizeEmail().withMessage('Please provide a valid email address.'),
  validate,
];

const updateNameValidation = [
  body('name')
    .trim()
    .isLength({ min: 2, max: 60 })
    .withMessage('Name must be 2–60 characters.'),
  validate,
];

const requestEmailChangeValidation = [
  body('newEmail')
    .trim()
    .isEmail()
    .normalizeEmail()
    .withMessage('Please provide a valid email address.'),
  validate,
];

const changePasswordValidation = [
  body('currentPassword').notEmpty().withMessage('Current password is required.'),
  body('newPassword')
    .isLength({ min: 8 })
    .withMessage('Password must be at least 8 characters.')
    .matches(/[A-Za-z]/)
    .withMessage('Password must contain at least one letter.')
    .matches(/[0-9]/)
    .withMessage('Password must contain at least one number.'),
  validate,
];

const deleteAccountValidation = [
  body('password').notEmpty().withMessage('Password is required to delete your account.'),
  validate,
];

// ─── Handlers ─────────────────────────────────────────────────────────────────

/**
 * POST /api/auth/register
 */
async function register(req, res, next) {
  try {
    const result = await authService.register(req.body);
    return sendSuccess(res, result, 201);
  } catch (err) {
    return next(err);
  }
}

/**
 * GET /api/auth/verify-email?token=...
 */
async function verifyEmail(req, res, next) {
  try {
    const { token } = req.query;
    if (!token) {
      return res.status(400).send(
        '<html><body style="font-family:sans-serif;text-align:center;padding:60px;color:#d9534f;"><h2>❌ Verification Failed</h2><p>Verification token is missing.</p></body></html>'
      );
    }
    
    await authService.verifyEmail(token);
    
    return res.send(
      '<html><body style="font-family:sans-serif;text-align:center;padding:60px;color:#28a745;"><h2>✅ Email Verified!</h2><p>Your email address has been successfully verified. You can now close this window and return to the Hisaab app.</p></body></html>'
    );
  } catch (err) {
    // escapeHtml prevents reflected XSS from any error message content
    const safeMessage = escapeHtml(
      err.message || 'An error occurred during verification. The token might be invalid or expired.'
    );
    return res.status(400).send(
      `<html><body style="font-family:sans-serif;text-align:center;padding:60px;color:#d9534f;"><h2>❌ Verification Failed</h2><p>${safeMessage}</p></body></html>`
    );
  }
}

/**
 * POST /api/auth/resend-verification
 */
async function resendVerification(req, res, next) {
  try {
    const result = await authService.resendVerificationEmail(req.body.email);
    return sendSuccess(res, result);
  } catch (err) {
    return next(err);
  }
}

/**
 * POST /api/auth/login
 */
async function login(req, res, next) {
  try {
    const result = await authService.login(req.body);
    // Successful login — clear any brute-force lockout for this IP
    clearFailedAttempts(req.ip);
    return sendSuccess(res, result);
  } catch (err) {
    // Increment brute-force counter only for credential/auth errors.
    // Validation errors (422) and server errors (5xx) are not counted
    // so legitimate typo-correction attempts aren't penalised unfairly.
    const isCredentialError = !err.statusCode || err.statusCode === 401 || err.statusCode === 403;
    if (isCredentialError) {
      const { count, lockedUntil, lockoutMs } = recordFailedAttempt(req.ip);
      if (lockoutMs > 0) {
        const retryAfterSecs = Math.ceil(lockoutMs / 1000);
        res.setHeader('Retry-After', retryAfterSecs);
        // Augment the error with backoff info before passing to the error handler
        err._backoff = { count, retryAfter: retryAfterSecs };
      }
    }
    return next(err);
  }
}

/**
 * POST /api/auth/refresh
 * Body: { refreshToken: string }
 */
async function refresh(req, res, next) {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) return sendError(res, 'Refresh token is required.', 400, 'MISSING_TOKEN');
    const result = await authService.refreshToken(refreshToken);
    return sendSuccess(res, result);
  } catch (err) {
    return next(err);
  }
}

/**
 * POST /api/auth/logout
 * Body: { refreshToken: string }
 */
async function logout(req, res, next) {
  try {
    await authService.logout(req.body.refreshToken);
    return sendSuccess(res, { message: 'Logged out successfully.' });
  } catch (err) {
    return next(err);
  }
}

/**
 * POST /api/auth/forgot-password
 */
async function forgotPassword(req, res, next) {
  try {
    const result = await authService.forgotPassword(req.body.email);
    return sendSuccess(res, result);
  } catch (err) {
    return next(err);
  }
}

/**
 * POST /api/auth/reset-password
 */
async function resetPassword(req, res, next) {
  try {
    const result = await authService.resetPassword(req.body);
    return sendSuccess(res, result);
  } catch (err) {
    return next(err);
  }
}

/**
 * GET /api/auth/me   [protected]
 */
async function getMe(req, res, next) {
  try {
    const user = await authService.getMe(req.user.id);
    return sendSuccess(res, user);
  } catch (err) {
    return next(err);
  }
}

/**
 * PATCH /api/auth/profile   [protected]
 */
async function updateName(req, res, next) {
  try {
    const user = await authService.updateName(req.user.id, req.body.name);
    return sendSuccess(res, user);
  } catch (err) {
    return next(err);
  }
}

/**
 * POST /api/auth/request-email-change   [protected]
 */
async function requestEmailChange(req, res, next) {
  try {
    const result = await authService.requestEmailChange(req.user.id, req.body.newEmail);
    return sendSuccess(res, result);
  } catch (err) {
    return next(err);
  }
}

/**
 * GET /api/auth/confirm-email-change?token=...   [public — email link]
 */
async function confirmEmailChange(req, res, next) {
  try {
    const { token } = req.query;
    if (!token) return sendError(res, 'Verification token is missing.', 400, 'MISSING_TOKEN');
    await authService.confirmEmailChange(token);
    // Redirect to a simple success page or just return JSON
    return res.send(
      '<html><body style="font-family:sans-serif;text-align:center;padding:60px;"><h2>✅ Confirmed!</h2><p>A verification link has been sent to your new email address.</p></body></html>',
    );
  } catch (err) {
    return next(err);
  }
}

/**
 * GET /api/auth/verify-new-email?token=...   [public — email link]
 */
async function verifyNewEmail(req, res, next) {
  try {
    const { token } = req.query;
    if (!token) return sendError(res, 'Verification token is missing.', 400, 'MISSING_TOKEN');
    await authService.verifyNewEmail(token);
    return res.send(
      '<html><body style="font-family:sans-serif;text-align:center;padding:60px;"><h2>✅ Email updated!</h2><p>Your email address has been changed successfully. Please log in again with your new email.</p></body></html>',
    );
  } catch (err) {
    return next(err);
  }
}

/**
 * POST /api/auth/change-password   [protected]
 */
async function changePassword(req, res, next) {
  try {
    const result = await authService.changePassword(req.user.id, req.body);
    return sendSuccess(res, result);
  } catch (err) {
    return next(err);
  }
}

/**
 * DELETE /api/auth/delete-account   [protected]
 */
async function deleteAccount(req, res, next) {
  try {
    const result = await authService.scheduleAccountDeletion(req.user.id, req.body.password);
    return sendSuccess(res, result);
  } catch (err) {
    return next(err);
  }
}

/**
 * POST /api/auth/accept-policy
 * Requires: requireAuth (user must be logged in)
 * Does NOT require requirePolicy (that would create a catch-22).
 */
async function acceptPolicy(req, res, next) {
  try {
    const result = await authService.acceptPolicy(req.user.id);
    return sendSuccess(res, result);
  } catch (err) {
    return next(err);
  }
}

/**
 * GET /api/auth/reset-redirect?token=...
 * Serves an HTML page that instantly redirects to the Hisaab app via deep link.
 * Used to support password resets in standalone APK distributions.
 */
function resetRedirect(req, res) {
  const { token } = req.query;
  if (!token) {
    return res.status(400).send(
      '<html><body style="font-family:sans-serif;text-align:center;padding:60px;color:#d9534f;"><h2>❌ Error</h2><p>Reset token is missing.</p></body></html>'
    );
  }

  const deepLink = `${process.env.CLIENT_DEEP_LINK || 'hisaab://'}reset-password?token=${token}`;

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Reset Hisaab Password</title>
      <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; text-align: center; padding: 60px 20px; background: #F5F6FB; color: #2C2F33; }
        .btn { display: inline-block; padding: 14px 32px; background: #3861FB; color: white; text-decoration: none; border-radius: 12px; font-weight: bold; margin-top: 24px; box-shadow: 0 4px 12px rgba(56,97,251,0.2); }
      </style>
    </head>
    <body>
      <h2>Opening Hisaab App...</h2>
      <p style="color: #595C60; margin-top: 8px;">If the app doesn't open automatically within a few seconds, click the button below:</p>
      <a class="btn" href="${deepLink}">Open Hisaab</a>
      <script>
        setTimeout(function() {
          window.location.href = "${deepLink}";
        }, 300);
      </script>
    </body>
    </html>
  `;
  return res.send(html);
}

module.exports = {
  register,
  registerValidation,
  verifyEmail,
  resendVerification,
  resendVerificationValidation,
  login,
  loginValidation,
  refresh,
  logout,
  forgotPassword,
  forgotPasswordValidation,
  resetPassword,
  resetPasswordValidation,
  getMe,
  updateName,
  updateNameValidation,
  requestEmailChange,
  requestEmailChangeValidation,
  confirmEmailChange,
  verifyNewEmail,
  changePassword,
  changePasswordValidation,
  deleteAccount,
  deleteAccountValidation,
  acceptPolicy,
  resetRedirect,
};
