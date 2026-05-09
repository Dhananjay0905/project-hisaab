/**
 * Auth Controller — thin HTTP adapter layer.
 * Validates input, calls service, returns HTTP response.
 */

const { body, query } = require('express-validator');
const authService = require('../services/auth.service');
const { sendSuccess, sendError } = require('../utils/response');
const { validate } = require('../middleware/validate');

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
      '<html><body style="font-family:sans-serif;text-align:center;padding:60px;color:#28a745;"><h2>✅ Email Verified!</h2><p>Your email address has been successfully verified. You can now close this window and return to the Expensio app.</p></body></html>'
    );
  } catch (err) {
    const message = err.message || 'An error occurred during verification. The token might be invalid or expired.';
    return res.status(400).send(
      `<html><body style="font-family:sans-serif;text-align:center;padding:60px;color:#d9534f;"><h2>❌ Verification Failed</h2><p>${message}</p></body></html>`
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
    return sendSuccess(res, result);
  } catch (err) {
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
};
