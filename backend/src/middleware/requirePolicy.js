/**
 * requirePolicy — middleware that enforces Privacy Policy acceptance.
 *
 * Must be applied AFTER requireAuth (so req.user.id is populated).
 *
 * Behaviour:
 *  - Fetches policyAcceptedAt from DB (single PK lookup — fast).
 *  - Non-null → pass through (attaches policyAcceptedAt to req.user for convenience).
 *  - Null → respond 403 POLICY_NOT_ACCEPTED.
 *
 * This intentionally causes old APK clients (which have no handler for this
 * error code) to stop working, prompting users to upgrade to the new APK.
 */

const { PrismaClient } = require('@prisma/client');
const { createError } = require('./errorHandler');

const prisma = new PrismaClient();

/**
 * @type {import('express').RequestHandler}
 */
async function requirePolicy(req, res, next) {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: { policyAcceptedAt: true },
    });

    if (user?.policyAcceptedAt) {
      req.user.policyAcceptedAt = user.policyAcceptedAt;
      return next();
    }

    return next(
      createError(
        'You must accept the Privacy Policy and Terms of Service before using Hisaab. Please update your app.',
        403,
        'POLICY_NOT_ACCEPTED',
      ),
    );
  } catch (err) {
    return next(err);
  }
}

module.exports = { requirePolicy };
