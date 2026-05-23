const express = require('express');
const { getConfig } = require('../controllers/app.controller');

const router = express.Router();

// GET /api/app/config — public, no auth
router.get('/config', getConfig);

module.exports = router;
