/**
 * AES-256-GCM encryption utility.
 *
 * All sensitive user data (transaction titles, amounts, person names, etc.)
 * is encrypted before being stored in PostgreSQL. The encryption key lives
 * entirely on the server — the database alone is unreadable without it.
 *
 * Format of encrypted strings: `<iv_hex>:<tag_hex>:<ciphertext_hex>`
 */

const crypto = require('crypto');

const ALGORITHM = 'aes-256-gcm';
const KEY_LENGTH = 32; // 256 bits

function _getKey() {
  const secret = process.env.APP_ENCRYPTION_SECRET;
  if (!secret) {
    throw new Error('APP_ENCRYPTION_SECRET environment variable is not set.');
  }
  if (secret.length !== 64) {
    throw new Error(
      `APP_ENCRYPTION_SECRET must be exactly 64 hex characters (32 bytes). Got: ${secret.length}`
    );
  }
  return Buffer.from(secret, 'hex');
}

/**
 * Encrypts a plaintext string.
 * @param {string} plaintext
 * @returns {string} `iv:tag:ciphertext` as hex
 */
function encrypt(plaintext) {
  if (plaintext === null || plaintext === undefined) return null;
  const text = String(plaintext);

  const key = _getKey();
  const iv = crypto.randomBytes(12); // 96-bit IV for GCM
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);

  const encrypted = Buffer.concat([
    cipher.update(text, 'utf8'),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();

  return `${iv.toString('hex')}:${tag.toString('hex')}:${encrypted.toString('hex')}`;
}

/**
 * Decrypts a ciphertext string produced by `encrypt()`.
 * @param {string} ciphertext `iv:tag:ciphertext` hex string
 * @returns {string} plaintext
 */
function decrypt(ciphertext) {
  if (ciphertext === null || ciphertext === undefined) return null;

  const parts = ciphertext.split(':');
  if (parts.length !== 3) {
    throw new Error('Invalid encrypted format. Expected iv:tag:ciphertext');
  }

  const [ivHex, tagHex, encryptedHex] = parts;
  const key = _getKey();
  const iv = Buffer.from(ivHex, 'hex');
  const tag = Buffer.from(tagHex, 'hex');
  const encrypted = Buffer.from(encryptedHex, 'hex');

  const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
  decipher.setAuthTag(tag);

  const decrypted = Buffer.concat([
    decipher.update(encrypted),
    decipher.final(),
  ]);

  return decrypted.toString('utf8');
}

/**
 * Encrypts a numeric amount (stored as string in DB).
 * @param {number|string} amount
 * @returns {string} encrypted string
 */
function encryptAmount(amount) {
  return encrypt(String(amount));
}

/**
 * Decrypts an amount and returns it as a float.
 * @param {string} encrypted
 * @returns {number}
 */
function decryptAmount(encrypted) {
  const decrypted = decrypt(encrypted);
  return parseFloat(decrypted) || 0;
}

/**
 * Encrypt only if value is not null/undefined.
 * @param {string|null} value
 * @returns {string|null}
 */
function encryptOptional(value) {
  if (value === null || value === undefined || value === '') return null;
  return encrypt(value);
}

/**
 * Decrypt only if value is not null.
 * @param {string|null} value
 * @returns {string|null}
 */
function decryptOptional(value) {
  if (value === null || value === undefined) return null;
  return decrypt(value);
}

module.exports = {
  encrypt,
  decrypt,
  encryptAmount,
  decryptAmount,
  encryptOptional,
  decryptOptional,
};
