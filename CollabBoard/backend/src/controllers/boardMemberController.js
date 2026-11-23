// src/controllers/boardMemberController.js
const { getMembers, addMember, removeMember, getMemberRole, updateMemberRole } = require('../models/boardMemberModel');
const { getBoardById } = require('../models/boardModel');

// Helper: ensure requester is owner of the board
async function ensureOwner(boardId, userId) {
  const role = await getMemberRole(boardId, userId);
  if (role !== 'owner') {
    const err = new Error('Only board owner can perform this action');
    err.status = 403;
    throw err;
  }
}

// GET /api/boards/:boardId/members – list members of a board
async function listMembersHandler(req, res) {
  try {
    const boardId = req.params.boardId;
    // verify requester is a member (any role)
    const requesterRole = await getMemberRole(boardId, req.user.id);
    if (!requesterRole) return res.status(403).json({ message: 'Access denied' });
    const members = await getMembers(boardId);
    res.json(members);
  } catch (err) {
    console.error('List members error:', err);
    res.status(err.status || 500).json({ message: err.message || 'Server error' });
  }
}

// POST /api/boards/:boardId/members – invite a user (owner only)
// body: { email: string, role: 'editor'|'viewer' }
async function inviteMemberHandler(req, res) {
  try {
    const boardId = req.params.boardId;
    await ensureOwner(boardId, req.user.id);
    const { email, role } = req.body;
    if (!email || !role) return res.status(400).json({ message: 'email and role required' });
    // find user by email
    const { getUserByEmail } = require('../models/userModel');
    const user = await getUserByEmail(email);
    if (!user) return res.status(404).json({ message: 'User not found' });
    // add to board_members
    await addMember({ boardId: boardId, userId: user.id, role });
    res.status(201).json({ message: 'User invited', userId: user.id, role });
  } catch (err) {
    console.error('Invite member error:', err);
    res.status(err.status || 500).json({ message: err.message || 'Server error' });
  }
}

// PUT /api/boards/:boardId/members/:userId – update role (owner only)
async function updateMemberRoleHandler(req, res) {
  try {
    const boardId = req.params.boardId;
    const targetUserId = parseInt(req.params.userId, 10);
    await ensureOwner(boardId, req.user.id);
    const { role } = req.body;
    if (!role) return res.status(400).json({ message: 'role required' });
    const affected = await updateMemberRole(boardId, targetUserId, role);
    if (affected === 0) return res.status(404).json({ message: 'Member not found' });
    res.json({ message: 'Role updated' });
  } catch (err) {
    console.error('Update member role error:', err);
    res.status(err.status || 500).json({ message: err.message || 'Server error' });
  }
}

// DELETE /api/boards/:boardId/members/:userId – remove member (owner can remove others, members can leave themselves)
async function removeMemberHandler(req, res) {
  try {
    const boardId = req.params.boardId;
    const targetUserId = parseInt(req.params.userId, 10);
    // Determine role of requester
    const requesterRole = await getMemberRole(boardId, req.user.id);
    // If requester is owner, prevent them from removing themselves
    if (requesterRole === 'owner' && targetUserId === req.user.id) {
      return res.status(400).json({ message: 'Owner cannot remove themselves' });
    }
    // If requester is the target (leaving) and not owner, allow
    if (targetUserId === req.user.id) {
      const affected = await removeMember(boardId, targetUserId);
      if (affected === 0) return res.status(404).json({ message: 'Member not found' });
      return res.json({ message: 'You have left the board' });
    }
    // Otherwise, ensure requester is owner to remove others
    await ensureOwner(boardId, req.user.id);
    const affected = await removeMember(boardId, targetUserId);
    if (affected === 0) return res.status(404).json({ message: 'Member not found' });
    res.json({ message: 'Member removed' });
  } catch (err) {
    console.error('Remove member error:', err);
    res.status(err.status || 500).json({ message: err.message || 'Server error' });
  }
}

module.exports = {
  listMembersHandler,
  inviteMemberHandler,
  updateMemberRoleHandler,
  removeMemberHandler,
};
