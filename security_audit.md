# Hisaab Backend — Security Audit Report

**Date:** May 17, 2025  
**Scope:** Express.js REST API (backend only)  
**Method:** Static code analysis + OWASP Top 10 review  

---

## Overall Risk Rating: 🟡 MEDIUM — Good baseline, 4 issues to fix

The backend has a solid security foundation (Helmet, rate limiting, bcrypt, JWT rotation, Prisma ORM). Four issues were found and fixes have been applied.

---

## ✅ What Is Already Strong

| Control | Detail |
|---|---|
| **Helmet** | Applied globally — sets 14 security headers |
| **express-validator** | Input validation on all auth endpoints |
| **bcrypt (cost 12)** | Strong password hashing |
| **JWT access tokens (15m TTL)** | Short-lived, HS256 with explicit algorithm pin |
| **Refresh tokens (opaque, random 32 bytes)** | Not JWTs — cannot be decoded; stored in DB |
| **Rate limiting** | Global (200/15min) + Auth endpoints (10/15min) |
| **Body size limit** | `express.json({ limit: '10kb' })` prevents large-body DoS |
| **Prisma ORM** | Parameterised queries — no raw SQL injection surface |
| **AES-256-GCM encryption** | Sensitive text fields encrypted at rest |
| **Algorithm pinning** | `algorithms: ['HS256']` prevents `alg:none` attack |
| **Token revocation** | Refresh tokens stored in DB; logout deletes them |
| **graceful SIGINT/SIGTERM** | Clean DB disconnect on shutdown |

---

## 🔴 Findings & Fixes Applied

### FINDING 1 — Reflected XSS in HTML error pages (HIGH)
**OWASP:** A03 Injection / A05 Security Misconfiguration  
**Location:** `auth.controller.js` line 132 — `verifyEmail` error handler  

**Vulnerable code:**
```js
// ❌ err.message is unsanitised and reflected into HTML
return res.status(400).send(
  `<html>...<p>${message}</p></html>`
);
```
If an attacker can trigger a controlled error message and tricks a user into visiting the verification URL, `message` is injected directly into the HTML response without escaping — a classic reflected XSS.

**Fix applied:** HTML-encode the reflected message with a safe helper before injecting into HTML.

---

### FINDING 2 — CORS fallback allows `*` (MEDIUM)
**OWASP:** A05 Security Misconfiguration  
**Location:** `app.js` line 42  

**Vulnerable code:**
```js
// ❌ Falls back to wildcard if FRONTEND_URL is unset
return callback(null, process.env.FRONTEND_URL || '*');
```
If `FRONTEND_URL` env var is not set in production, the API accepts requests from any origin with `credentials: true`. This effectively disables CORS protection.

**Fix applied:** Fail closed — if `FRONTEND_URL` is unset, deny the origin rather than allowing all.

---

### FINDING 3 — Helmet used with all defaults; missing explicit hardening (MEDIUM)
**OWASP:** A05 Security Misconfiguration  
**Location:** `app.js` line 31  

`helmet()` with no config still leaves gaps:
- `Content-Security-Policy` uses helmet's default, not a locked-down policy
- `Permissions-Policy` header is not set at all (controls camera, mic, geolocation, etc.)
- `Cache-Control` is not set — API responses may be cached by intermediaries
- `X-Content-Type-Options: nosniff` is set by helmet but only for HTML endpoints by default

**Fix applied:** Explicit helmet config + `Permissions-Policy` + `Cache-Control: no-store` on all API responses.

---

### FINDING 4 — `/api/auth/refresh` and `/api/auth/logout` have no rate limiting (LOW-MEDIUM)
**OWASP:** A07 Identification and Authentication Failures  
**Location:** `auth.routes.js` lines 28 and 31  

`/refresh` and `/logout` only have the global 200/15min limiter, not the stricter auth limiter (10/15min). A bot could hammer refresh to enumerate valid refresh tokens.

**Fix applied:** Apply `authLimiter` to both routes.

---

## 🟢 OWASP Top 10 Full Assessment

| # | Category | Status | Notes |
|---|---|---|---|
| A01 | Broken Access Control | ✅ Pass | All data queries scope to `userId`; no IDOR found |
| A02 | Cryptographic Failures | ✅ Pass | bcrypt(12), AES-256-GCM, HS256 JWT, opaque refresh tokens |
| A03 | Injection — SQL | ✅ Pass | Prisma ORM only; no raw SQL, no `$queryRaw` usage |
| A03 | Injection — XSS | ⚠️ Fixed | HTML error pages reflected `err.message` unsanitised |
| A04 | Insecure Design | ✅ Pass | JWT rotation, token revocation, rate limiting in place |
| A05 | Security Misconfiguration | ⚠️ Fixed | CORS wildcard fallback; Helmet hardened with explicit config |
| A06 | Vulnerable Components | ✅ Pass | All packages current; no known CVEs in dependency list |
| A07 | Auth & Session Failures | ⚠️ Fixed | Refresh/logout now rate-limited; tokens are short-lived and rotated |
| A08 | Software & Data Integrity | ✅ Pass | No deserialization; `algorithms: ['HS256']` pins JWT algo |
| A09 | Security Logging | ✅ Pass | Morgan + console.error on all errors; no sensitive data in logs |
| A10 | SSRF | ✅ N/A | No user-controlled URLs are fetched by the server |

---

## SQL Injection Test Results

Prisma uses parameterised queries for all operations. A search of the entire codebase confirms:
- **Zero** uses of `prisma.$queryRaw` or `prisma.$executeRaw`
- **Zero** string concatenation into database queries
- All filtering (userId, type, categoryId, date ranges) uses Prisma's typed query builder

**Result: No SQL injection surface found. ✅**

---

## XSS Test Results

Three HTML-returning endpoints were audited:
1. `GET /api/auth/verify-email` — ⚠️ **Fixed** (error message was reflected)
2. `GET /api/auth/confirm-email-change` — ✅ Static string, no user input reflected
3. `GET /api/auth/verify-new-email` — ✅ Static string, no user input reflected

All JSON API responses are `application/json` — XSS is not applicable to JSON responses since browsers do not execute them as HTML (and `X-Content-Type-Options: nosniff` is set by Helmet).

**Result: 1 reflected XSS fixed. All other endpoints clean. ✅**

---

## Additional Recommendations (Not Fixed — Future Work)

| Item | Priority |
|---|---|
| Add `hpp` (HTTP Parameter Pollution) middleware | Low |
| Add `express-mongo-sanitize` equivalent for NoSQL if you ever add a NoSQL layer | Low |
| Store refresh tokens hashed (SHA-256) in DB rather than plaintext | Medium |
| Add structured logging (e.g. `pino`) in production instead of `console.error` | Low |
| Set up Dependabot/Renovate for automated dependency updates | Low |
| Consider a stricter password policy (e.g. enforce special characters) | Low |
