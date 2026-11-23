// src/routes/publicInvitations.js
const express = require('express');
const router = express.Router();
const { getByToken, incrementUsage } = require('../models/invitationModel');
const boardMemberModel = require('../models/boardMemberModel');
const boardModel = require('../models/boardModel');
const { authenticateToken } = require('../middleware/auth');

// Public preview of an invitation (no auth needed)
router.get('/info/:token', async (req, res) => {
  try {
    const invitation = await getByToken(req.params.token);
    if (!invitation) return res.status(404).json({ message: 'Invitation not found' });
    const board = await boardModel.getBoardById(invitation.board_id);
    res.json({
      boardId: board.id,
      boardTitle: board.title,
      boardDescription: board.description,
      inviterId: invitation.inviter_id,
      role: invitation.role,
      expiresAt: invitation.expires_at,
      uses: invitation.uses,
      maxUses: invitation.max_uses,
      revoked: invitation.revoked,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// Join a board using an invitation – requires authentication
router.post('/join/:token', authenticateToken, async (req, res) => {
  try {
    const token = req.params.token;
    const userId = req.user.id;
    const invitation = await getByToken(token);
    if (!invitation) return res.status(404).json({ message: 'Invalid invitation' });
    if (invitation.revoked) return res.status(410).json({ message: 'Invitation revoked' });
    if (new Date(invitation.expires_at) < new Date()) return res.status(410).json({ message: 'Invitation expired' });
    if (invitation.uses >= invitation.max_uses) return res.status(410).json({ message: 'Invitation usage limit reached' });
    const existingRole = await boardMemberModel.getMemberRole(invitation.board_id, userId);
    if (existingRole) return res.status(409).json({ message: 'Already a board member' });
    await boardMemberModel.addMember({ boardId: invitation.board_id, userId, role: invitation.role });
    await incrementUsage(invitation.id);
    res.json({ message: 'Joined board successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
