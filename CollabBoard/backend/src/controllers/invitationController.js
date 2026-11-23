// src/controllers/invitationController.js
const { createInvitation, getByToken, incrementUsage, revoke } = require('../models/invitationModel');
const boardModel = require('../models/boardModel');
const boardMemberModel = require('../models/boardMemberModel');
const db = require('../config/db');

/** Create a new invitation. Only the board owner can create. */
async function createInvitationHandler(req, res) {
  try {
    const { boardId } = req.params; // URL: /boards/:boardId/invitations
    const { expiresInSec, maxUses, role } = req.body;
    const inviterId = req.user.id; // from authenticateToken middleware

    // Verify inviter is owner of the board
    const board = await boardModel.getBoardById(boardId);
    if (!board) return res.status(404).json({ message: 'Board not found' });
    if (board.owner_id !== inviterId) {
      return res.status(403).json({ message: 'Only board owner can create invitations' });
    }

    const invitation = await createInvitation({
      boardId,
      inviterId,
      expiresInSec: expiresInSec || 7 * 24 * 60 * 60,
      maxUses: maxUses || 1,
      role: role || 'viewer',
    });

    // Return minimal info (code & link)
    const link = `${req.protocol}://${req.get('host')}/join/${invitation.token}`;
    res.status(201).json({
      id: invitation.id,
      token: invitation.token,
      link,
      role: invitation.role,
      expiresAt: invitation.expires_at,
      maxUses: invitation.max_uses,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
}

/** Get invitation details (used for preview before joining). */
async function getInvitationHandler(req, res) {
  try {
    const { token } = req.params;
    const invitation = await getByToken(token);
    if (!invitation) return res.status(404).json({ message: 'Invitation not found' });
    // Hide token but expose board info
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
}

/** Join a board using an invitation token. */
async function joinInvitationHandler(req, res) {
  try {
    const { token } = req.params;
    const userId = req.user.id;
    const invitation = await getByToken(token);
    if (!invitation) return res.status(404).json({ message: 'Invalid invitation' });
    // validate expiry, revocation, usage limits
    if (invitation.revoked) return res.status(410).json({ message: 'Invitation revoked' });
    if (new Date(invitation.expires_at) < new Date()) return res.status(410).json({ message: 'Invitation expired' });
    if (invitation.uses >= invitation.max_uses) return res.status(410).json({ message: 'Invitation usage limit reached' });

    // Check if user already a member
    const existingRole = await boardMemberModel.getMemberRole(invitation.board_id, userId);
    if (existingRole) return res.status(409).json({ message: 'Already a board member' });

    // Add member with role from invitation
    await boardMemberModel.addMember({
      boardId: invitation.board_id,
      userId,
      role: invitation.role,
    });
    await incrementUsage(invitation.id);
    res.json({ message: 'Joined board successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
}

/** Revoke an invitation (owner only). */
async function revokeInvitationHandler(req, res) {
  try {
    const { token } = req.params;
    const userId = req.user.id;
    const invitation = await getByToken(token);
    if (!invitation) return res.status(404).json({ message: 'Invitation not found' });
    // Verify owner of the board
    const board = await boardModel.getBoardById(invitation.board_id);
    if (board.owner_id !== userId) return res.status(403).json({ message: 'Only board owner can revoke' });
    await revoke(invitation.id);
    res.json({ message: 'Invitation revoked' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
}

/** List all invitations for a board (owner). */
async function listInvitationsHandler(req, res) {
  try {
    const { boardId } = req.params;
    const userId = req.user.id;
    const board = await boardModel.getBoardById(boardId);
    if (!board) return res.status(404).json({ message: 'Board not found' });
    if (board.owner_id !== userId) return res.status(403).json({ message: 'Only owner can view invitations' });
    const [rows] = await db.execute('SELECT * FROM invitations WHERE board_id = ?', [boardId]);
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
}

module.exports = {
  createInvitationHandler,
  getInvitationHandler,
  joinInvitationHandler,
  revokeInvitationHandler,
  listInvitationsHandler,
};
