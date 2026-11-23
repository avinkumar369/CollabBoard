const express = require('express');
const { authenticateToken } = require('../middleware/auth');
const router = express.Router();
const { register, login, getMe } = require('../controllers/authController');

router.post('/register', register);
router.post('/login', login);
router.get('/me', authenticateToken, getMe);

module.exports = router;
