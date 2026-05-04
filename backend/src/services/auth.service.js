/**
 * Auth Service — all authentication business logic.
 *
 * Responsibilities:
 *  - register: hash password, save user, send verification email
 *  - verifyEmail: validate token, mark user verified
 *  - login: verify credentials + email status, issue tokens
 *  - refreshToken: rotate refresh token in DB
 *  - logout: revoke refresh token
 *  - forgotPassword: generate reset token, send email
 *  - resetPassword: validate token, update hash
 *  - getMe: fetch and format user profile
 *
 * Encryption note: openingBalance and monthlyBudget are stored as plain
 * Decimal values. Only personally-identifying text fields (title, note, etc.)
 * on child models (Transaction, Due, etc.) are encrypted.
 */

const bcrypt = require('bcryptjs');
const { PrismaClient } = require('@prisma/client');
const { createError } = require('../middleware/errorHandler');
const {
  signAccessToken,
  generateRefreshToken,
  refreshTokenExpiresAt,
  generateOneTimeToken,
} = require('../utils/jwt');
// encrypt/decrypt only needed for child-model text fields — not used in auth
const {
  sendVerificationEmail,
  sendPasswordResetEmail,
  sendEmailChangeConfirmation,
  sendNewEmailVerification,
} = require('../utils/email');

const prisma = new PrismaClient();

// ─── Default categories seeded for every new user ─────────────────────────────
const DEFAULT_CATEGORIES = [
  { name: 'Food', emoji: '🍔', type: 'EXPENSE' },
  { name: 'Entertainment', emoji: '🎬', type: 'EXPENSE' },
  { name: 'Other Expenses', emoji: '💸', type: 'EXPENSE' },
  { name: 'Salary', emoji: '💼', type: 'INCOME' },
  { name: 'Other Income', emoji: '💰', type: 'INCOME' },
];

const BCRYPT_ROUNDS = 12;
const VERIFICATION_EXPIRY_HOURS = 24;
const RESET_EXPIRY_HOURS = 1;

// ─── Register ─────────────────────────────────────────────────────────────────

async function register({ name, email, password, currency, currencySymbol, openingBalance }) {
  // 1. Check duplicate email
  const existing = await prisma.user.findUnique({ where: { email: email.toLowerCase() } });
  if (existing) {
    throw createError('An account with this email already exists.', 409, 'EMAIL_TAKEN');
  }

  // 2. Hash password
  const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);

  // 3. Generate verification token
  const verificationToken = generateOneTimeToken();
  const verificationExpiry = new Date(Date.now() + VERIFICATION_EXPIRY_HOURS * 3600_000);

  // 4. Create user + default categories in a transaction
  const user = await prisma.$transaction(async (tx) => {
    const created = await tx.user.create({
      data: {
        name: name.trim(),
        email: email.toLowerCase().trim(),
        passwordHash,
        isVerified: false,
        verificationToken,
        verificationExpiry,
        currency: currency || 'USD',
        currencySymbol: currencySymbol || '$',
        // Stored as plain Decimal — no encryption needed
        openingBalance: parseFloat(openingBalance ?? 0),
      },
    });

    // Seed default categories
    await tx.category.createMany({
      data: DEFAULT_CATEGORIES.map((c) => ({
        userId: created.id,
        name: c.name,
        emoji: c.emoji,
        type: c.type,
        isDefault: true,
      })),
    });

    return created;
  });

  // 6. Send verification email (non-blocking on failure)
  try {
    await sendVerificationEmail({ name: user.name, email: user.email, token: verificationToken });
  } catch (emailErr) {
    console.error('[AUTH] Failed to send verification email:', emailErr.message);
    // Don't fail registration — the user can request resend
  }

  return { message: 'Registration successful. Please check your email to verify your account.' };
}

// ─── Verify Email ─────────────────────────────────────────────────────────────

async function verifyEmail(token) {
  const user = await prisma.user.findFirst({
    where: {
      verificationToken: token,
      isVerified: false,
    },
  });

  if (!user) {
    throw createError('This verification link is invalid or has already been used.', 400, 'INVALID_TOKEN');
  }

  if (user.verificationExpiry && user.verificationExpiry < new Date()) {
    throw createError('This verification link has expired. Please request a new one.', 400, 'TOKEN_EXPIRED');
  }

  await prisma.user.update({
    where: { id: user.id },
    data: {
      isVerified: true,
      verificationToken: null,
      verificationExpiry: null,
    },
  });

  return { message: 'Email verified successfully. You can now sign in.' };
}

// ─── Resend Verification ──────────────────────────────────────────────────────

async function resendVerificationEmail(email) {
  const user = await prisma.user.findUnique({ where: { email: email.toLowerCase() } });

  // Always return success to avoid email enumeration
  if (!user || user.isVerified) {
    return { message: 'If this email is unverified, a new link has been sent.' };
  }

  const verificationToken = generateOneTimeToken();
  const verificationExpiry = new Date(Date.now() + VERIFICATION_EXPIRY_HOURS * 3600_000);

  await prisma.user.update({
    where: { id: user.id },
    data: { verificationToken, verificationExpiry },
  });

  await sendVerificationEmail({ name: user.name, email: user.email, token: verificationToken });

  return { message: 'Verification email sent. Please check your inbox.' };
}

// ─── Login ────────────────────────────────────────────────────────────────────

async function login({ email, password }) {
  const user = await prisma.user.findUnique({
    where: { email: email.toLowerCase() },
  });

  // Use consistent timing to mitigate timing attacks
  const dummyHash = '$2b$12$invalidhashfortimingprotection.padding.12345';
  const passwordMatches = await bcrypt.compare(password, user?.passwordHash || dummyHash);

  if (!user || !passwordMatches) {
    throw createError('Invalid email or password.', 401, 'INVALID_CREDENTIALS');
  }

  if (!user.isVerified) {
    throw createError(
      'Please verify your email before logging in.',
      403,
      'EMAIL_UNVERIFIED'
    );
  }

  // Issue tokens
  const accessToken = signAccessToken({ id: user.id, email: user.email });
  const refreshTokenValue = generateRefreshToken();
  const expiresAt = refreshTokenExpiresAt();

  await prisma.refreshToken.create({
    data: { userId: user.id, token: refreshTokenValue, expiresAt },
  });

  // Clean up old expired/revoked refresh tokens for this user (background cleanup)
  prisma.refreshToken
    .deleteMany({
      where: {
        userId: user.id,
        OR: [{ expiresAt: { lt: new Date() } }, { revokedAt: { not: null } }],
      },
    })
    .catch(() => { });

  return {
    accessToken,
    refreshToken: refreshTokenValue,
    user: _formatUser(user),
  };
}

// ─── Refresh Token ────────────────────────────────────────────────────────────

async function refreshToken(tokenValue) {
  const stored = await prisma.refreshToken.findUnique({
    where: { token: tokenValue },
    include: { user: true },
  });

  if (!stored) {
    throw createError('Refresh token not found.', 401, 'INVALID_TOKEN');
  }

  if (stored.revokedAt) {
    // Token reuse — potential theft. Revoke all tokens for this user.
    await prisma.refreshToken.updateMany({
      where: { userId: stored.userId },
      data: { revokedAt: new Date() },
    });
    throw createError('Refresh token reuse detected. Please log in again.', 401, 'TOKEN_REUSE');
  }

  if (stored.expiresAt < new Date()) {
    throw createError('Refresh token has expired. Please log in again.', 401, 'TOKEN_EXPIRED');
  }

  // Rotate: revoke old, issue new
  const newRefreshToken = generateRefreshToken();
  const expiresAt = refreshTokenExpiresAt();

  await prisma.$transaction([
    prisma.refreshToken.update({
      where: { id: stored.id },
      data: { revokedAt: new Date(), replacedBy: newRefreshToken },
    }),
    prisma.refreshToken.create({
      data: { userId: stored.userId, token: newRefreshToken, expiresAt },
    }),
  ]);

  const accessToken = signAccessToken({ id: stored.user.id, email: stored.user.email });

  return { accessToken, refreshToken: newRefreshToken };
}

// ─── Logout ───────────────────────────────────────────────────────────────────

async function logout(refreshTokenValue) {
  if (!refreshTokenValue) return;
  await prisma.refreshToken
    .update({
      where: { token: refreshTokenValue },
      data: { revokedAt: new Date() },
    })
    .catch(() => { }); // Silently ignore if token doesn't exist
}

// ─── Forgot Password ──────────────────────────────────────────────────────────

async function forgotPassword(email) {
  const user = await prisma.user.findUnique({ where: { email: email.toLowerCase() } });

  // Always return success (prevent email enumeration)
  if (!user) {
    return { message: 'If that email is registered, a reset link has been sent.' };
  }

  const resetToken = generateOneTimeToken();
  const resetTokenExpiry = new Date(Date.now() + RESET_EXPIRY_HOURS * 3600_000);

  await prisma.user.update({
    where: { id: user.id },
    data: { resetToken, resetTokenExpiry },
  });

  try {
    await sendPasswordResetEmail({ name: user.name, email: user.email, token: resetToken });
  } catch (emailErr) {
    console.error('[AUTH] Failed to send reset email:', emailErr.message);
  }

  return { message: 'If that email is registered, a reset link has been sent.' };
}

// ─── Reset Password ───────────────────────────────────────────────────────────

async function resetPassword({ token, newPassword }) {
  const user = await prisma.user.findFirst({
    where: { resetToken: token },
  });

  if (!user) {
    throw createError('This reset link is invalid or has already been used.', 400, 'INVALID_TOKEN');
  }

  if (user.resetTokenExpiry && user.resetTokenExpiry < new Date()) {
    throw createError('This reset link has expired. Please request a new one.', 400, 'TOKEN_EXPIRED');
  }

  const passwordHash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);

  await prisma.$transaction([
    // Update password and clear reset token
    prisma.user.update({
      where: { id: user.id },
      data: { passwordHash, resetToken: null, resetTokenExpiry: null },
    }),
    // Revoke ALL refresh tokens (force re-login on all devices)
    prisma.refreshToken.updateMany({
      where: { userId: user.id },
      data: { revokedAt: new Date() },
    }),
  ]);

  return { message: 'Password reset successfully. You can now sign in with your new password.' };
}

// ─── Get Me ───────────────────────────────────────────────────────────────────

async function getMe(userId) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw createError('User not found.', 404, 'NOT_FOUND');
  return _formatUser(user);
}

// ─── Update Name ─────────────────────────────────────────────────────────────────────────────────

async function updateName(userId, name) {
  const user = await prisma.user.update({
    where: { id: userId },
    data: { name: name.trim() },
  });
  return _formatUser(user);
}

// ─── Request Email Change ────────────────────────────────────────────────────────────

/**
 * Step 1: User requests email change. Sends confirmation link to current email.
 */
async function requestEmailChange(userId, newEmail) {
  const normalised = newEmail.toLowerCase().trim();

  // Guard: new email already taken
  const taken = await prisma.user.findUnique({ where: { email: normalised } });
  if (taken) {
    throw createError('This email address is already in use.', 409, 'EMAIL_TAKEN');
  }

  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw createError('User not found.', 404, 'NOT_FOUND');

  // Guard: can't request change to same email
  if (user.email === normalised) {
    throw createError('New email must be different from your current email.', 400, 'SAME_EMAIL');
  }

  const emailChangeToken = generateOneTimeToken();
  const emailChangeExpiry = new Date(Date.now() + 3600_000); // 1 hour

  await prisma.user.update({
    where: { id: userId },
    data: { pendingEmail: normalised, emailChangeToken, emailChangeExpiry },
  });

  try {
    await sendEmailChangeConfirmation({ name: user.name, email: user.email, token: emailChangeToken });
  } catch (emailErr) {
    console.error('[AUTH] Failed to send email change confirmation:', emailErr.message);
  }

  return { message: 'A confirmation link has been sent to your current email address.' };
}

// ─── Confirm Email Change (step 2 — link in current email) ───────────────────────

/**
 * Step 2: User clicked the link in their current email.
 * Sends verification link to the NEW email.
 */
async function confirmEmailChange(token) {
  const user = await prisma.user.findFirst({
    where: { emailChangeToken: token },
  });

  if (!user || !user.pendingEmail) {
    throw createError('This link is invalid or has already been used.', 400, 'INVALID_TOKEN');
  }

  if (user.emailChangeExpiry && user.emailChangeExpiry < new Date()) {
    throw createError('This link has expired. Please request a new email change.', 400, 'TOKEN_EXPIRED');
  }

  const newEmailToken = generateOneTimeToken();
  const newEmailExpiry = new Date(Date.now() + 3600_000);

  await prisma.user.update({
    where: { id: user.id },
    data: { emailChangeToken: null, emailChangeExpiry: null, newEmailToken, newEmailExpiry },
  });

  try {
    await sendNewEmailVerification({ name: user.name, email: user.pendingEmail, token: newEmailToken });
  } catch (emailErr) {
    console.error('[AUTH] Failed to send new email verification:', emailErr.message);
  }

  return { message: 'Confirmation received. A verification link has been sent to your new email address.' };
}

// ─── Verify New Email (step 3 — link in new email) ──────────────────────────────

/**
 * Step 3: User clicked the link in their new email. Email is now updated.
 */
async function verifyNewEmail(token) {
  const user = await prisma.user.findFirst({
    where: { newEmailToken: token },
  });

  if (!user || !user.pendingEmail) {
    throw createError('This link is invalid or has already been used.', 400, 'INVALID_TOKEN');
  }

  if (user.newEmailExpiry && user.newEmailExpiry < new Date()) {
    throw createError('This link has expired. Please request a new email change.', 400, 'TOKEN_EXPIRED');
  }

  // Guard: race condition — new email got taken by another user in the meantime
  const taken = await prisma.user.findUnique({ where: { email: user.pendingEmail } });
  if (taken && taken.id !== user.id) {
    throw createError('This email address has just been taken. Please start the email change again.', 409, 'EMAIL_TAKEN');
  }

  await prisma.user.update({
    where: { id: user.id },
    data: {
      email: user.pendingEmail,
      pendingEmail: null,
      newEmailToken: null,
      newEmailExpiry: null,
    },
  });

  return { message: 'Your email address has been updated successfully.' };
}

// ─── Change Password ────────────────────────────────────────────────────────────────────────

/**
 * Changes password. Verifies current password first.
 * Current session (refresh token) stays alive — only other tokens are revoked.
 */
async function changePassword(userId, { currentPassword, newPassword }) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw createError('User not found.', 404, 'NOT_FOUND');

  const passwordMatches = await bcrypt.compare(currentPassword, user.passwordHash);
  if (!passwordMatches) {
    throw createError('Your current password is incorrect.', 400, 'INVALID_CREDENTIALS');
  }

  const passwordHash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);

  await prisma.user.update({
    where: { id: userId },
    data: { passwordHash },
  });

  return { message: 'Password changed successfully.' };
}

// ─── Format User ──────────────────────────────────────────────────────────────

function _formatUser(user) {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    isVerified: user.isVerified,
    currency: user.currency,
    currencySymbol: user.currencySymbol,
    // Prisma returns Decimal objects — convert to plain JS number
    openingBalance: parseFloat(user.openingBalance ?? 0),
    monthlyBudget: user.monthlyBudget != null ? parseFloat(user.monthlyBudget) : null,
    createdAt: user.createdAt,
  };
}

module.exports = {
  register,
  verifyEmail,
  resendVerificationEmail,
  login,
  refreshToken,
  logout,
  forgotPassword,
  resetPassword,
  getMe,
  updateName,
  requestEmailChange,
  confirmEmailChange,
  verifyNewEmail,
  changePassword,
};
