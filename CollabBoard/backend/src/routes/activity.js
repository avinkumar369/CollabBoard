// src/routes/activity.js
const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');
const db = require('../config/db');
const { getMemberRole } = require('../models/boardMemberModel');

// GET /api/activity/:boardId - retrieve activity logs for a board
router.get('/:boardId', authenticateToken, async (req, res) => {
  try {
    const boardId = req.params.boardId;
    const userId = req.user.id;
    // Verify user is a member of the board
    const role = await getMemberRole(boardId, userId);
    if (!role) {
      return res.status(403).json({ message: 'Access denied' });
    }
    // Fetch recent activity logs, newest first, limit to 100
    const [rows] = await db.execute(
      `SELECT al.id, al.board_id, al.user_id, al.activity_type, al.description, al.created_at,
              u.name as user_name, u.email as user_email
       FROM activity_logs al
       LEFT JOIN users u ON al.user_id = u.id
       WHERE al.board_id = ?
       ORDER BY al.created_at DESC
       LIMIT 100`,
      [boardId]
    );
    res.json(rows);
  } catch (err) {
    console.error('Activity fetch error:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
