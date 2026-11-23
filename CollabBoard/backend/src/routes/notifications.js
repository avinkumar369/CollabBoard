const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');
const {
  getNotificationsHandler,
  markNotificationReadHandler,
} = require('../controllers/notificationController');

router.get('/', authenticateToken, getNotificationsHandler);
router.put('/:id/read', authenticateToken, markNotificationReadHandler);

module.exports = router;
