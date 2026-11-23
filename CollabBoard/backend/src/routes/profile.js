const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');
const {
  getProfileHandler,
  updateProfileHandler,
  changePasswordHandler,
} = require('../controllers/profileController');

router.get('/', authenticateToken, getProfileHandler);
router.put('/', authenticateToken, updateProfileHandler);
router.post('/change-password', authenticateToken, changePasswordHandler);

module.exports = router;
