// src/routes/boardMembers.js
const express = require('express');
const router = express.Router({ mergeParams: true }); // keep :boardId from parent path
const { authenticateToken } = require('../middleware/auth');
const {
  listMembersHandler,
  inviteMemberHandler,
  updateMemberRoleHandler,
  removeMemberHandler,
} = require('../controllers/boardMemberController');

// All member routes require authentication
router.get('/:boardId/members', authenticateToken, listMembersHandler);
router.post('/:boardId/members', authenticateToken, inviteMemberHandler);
router.put('/:boardId/members/:userId', authenticateToken, updateMemberRoleHandler);
router.delete('/:boardId/members/:userId', authenticateToken, removeMemberHandler);

module.exports = router;
