/**
 * App Controller — public app configuration endpoint.
 * Returns version info and update messages so the frontend can decide
 * whether to show a hard-block or soft-update dialog.
 */

const path = require('path');
const fs = require('fs');
const { sendSuccess } = require('../utils/response');

// Cache the config in memory after first read.
let _cachedConfig = null;

function _getAppConfig() {
  if (!_cachedConfig) {
    try {
      const configPath = path.join(__dirname, '../data/app_config.json');
      _cachedConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    } catch (err) {
      console.error('[APP] Failed to read app_config.json:', err.message);
      // Fail open — return a safe default so the app is never wrongly blocked.
      _cachedConfig = {
        minVersion: '0.0.0',
        latestVersion: '0.0.0',
        criticalUpdateMessage: '',
        softUpdateMessage: '',
      };
    }
  }
  return _cachedConfig;
}

/**
 * GET /api/app/config
 * Public — no authentication required.
 */
function getConfig(req, res) {
  return sendSuccess(res, _getAppConfig());
}

module.exports = { getConfig };
