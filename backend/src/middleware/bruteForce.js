/**
 * Brute-force protection with exponential backoff for auth endpoints.
 *
 * Strategy:
 *  - Track consecutive failed login attempts per IP in memory.
 *  - First 3 failures → no lockout (honest mistakes).
 *  - Each failure after that → lockout doubles: 2s, 4s, 8s … capped at 1 hour.
 *  - Successful login clears the record immediately.
 *  - Stale records (unlocked for > 2 hours) are garbage-collected every 15 min.
 *
 * Lockout schedule per attempt count:
 *   ≤3  →  0s
 *    4  →  2s
 *    5  →  4s
 *    6  →  8s
 *    7  →  16s
 *    8  →  32s
 *    9  →  64s   (~1 min)
 *   10  →  128s  (~2 min)
 *   12  →  512s  (~8.5 min)
 *   15  →  4096s → capped at 3600s (1 hour)
 *
 * NOTE: This is an in-memory store, which resets on server restart.
 * For multi-instance production, replace with a Redis-backed store.
 */

// ─── In-memory attempt store ───────────────────────────────────────────────────

/** @type {Map<string, { count: number, lockedUntil: number }>} */
const attempts = new Map();

// Garbage-collect stale entries every 15 minutes
setInterval(() => {
  const twoHoursAgo = Date.now() - 2 * 60 * 60 * 1000;
  for (const [key, record] of attempts.entries()) {
    if (record.lockedUntil < twoHoursAgo) {
      attempts.delete(key);
    }
  }
}, 15 * 60 * 1000).unref(); // .unref() so GC timer doesn't block process shutdown

// ─── Core logic ───────────────────────────────────────────────────────────────

/**
 * Returns the lockout duration in milliseconds for a given attempt count.
 * @param {number} count
 * @returns {number} ms
 */
function getLockoutMs(count) {
  if (count <= 3) return 0;
  // 2^(count-3) seconds, capped at 1 hour (3600s)
  return Math.min(Math.pow(2, count - 3), 3600) * 1000;
}

/**
 * Formats a duration in seconds into a human-readable string.
 * @param {number} seconds
 * @returns {string}
 */
function formatDuration(seconds) {
  if (seconds < 60) return `${seconds} second${seconds !== 1 ? 's' : ''}`;
  if (seconds < 3600) {
    const m = Math.ceil(seconds / 60);
    return `${m} minute${m !== 1 ? 's' : ''}`;
  }
  const h = Math.ceil(seconds / 3600);
  return `${h} hour${h !== 1 ? 's' : ''}`;
}

// ─── Exported middleware & helpers ────────────────────────────────────────────

/**
 * Express middleware — blocks requests from IPs that are currently locked out.
 * Apply BEFORE validation and the route handler.
 *
 * @type {import('express').RequestHandler}
 */
function checkBruteForce(req, res, next) {
  const key = req.ip;
  const record = attempts.get(key);

  if (record && record.lockedUntil > Date.now()) {
    const retryAfterMs = record.lockedUntil - Date.now();
    const retryAfterSecs = Math.ceil(retryAfterMs / 1000);

    res.setHeader('Retry-After', retryAfterSecs);
    return res.status(429).json({
      success: false,
      error: {
        code: 'BRUTE_FORCE_LOCKED',
        message: `Too many failed attempts. Please try again in ${formatDuration(retryAfterSecs)}.`,
        retryAfter: retryAfterSecs,
      },
    });
  }

  next();
}

/**
 * Records a failed login attempt for an IP and applies the appropriate lockout.
 * Call this from the login controller when authentication fails.
 *
 * @param {string} ip - req.ip
 * @returns {{ count: number, lockedUntil: number, lockoutMs: number }}
 */
function recordFailedAttempt(ip) {
  const record = attempts.get(ip) || { count: 0, lockedUntil: 0 };
  record.count += 1;

  const lockoutMs = getLockoutMs(record.count);
  record.lockedUntil = lockoutMs > 0 ? Date.now() + lockoutMs : 0;

  attempts.set(ip, record);

  return { count: record.count, lockedUntil: record.lockedUntil, lockoutMs };
}

/**
 * Clears the failed-attempt record for an IP after a successful login.
 * Call this from the login controller on success.
 *
 * @param {string} ip - req.ip
 */
function clearFailedAttempts(ip) {
  attempts.delete(ip);
}

module.exports = { checkBruteForce, recordFailedAttempt, clearFailedAttempts };
