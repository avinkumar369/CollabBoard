
const db = require('../config/db');

// Validate member role
const VALID_ROLES = ['owner', 'editor', 'viewer'];

function validateIds(boardId, userId) {
  if (
    !Number.isInteger(Number(boardId)) ||
    Number(boardId) <= 0 ||
    !Number.isInteger(Number(userId)) ||
    Number(userId) <= 0
  ) {
    throw new Error('Invalid board ID or user ID');
  }
}

// ADD MEMBER
async function addMember({ boardId, userId, role }) {
  validateIds(boardId, userId);

  if (!VALID_ROLES.includes(role)) {
    throw new Error('Invalid member role');
  }

  const [result] = await db.execute(
    `INSERT INTO board_members
      (board_id, user_id, role, joined_at)
     VALUES (?, ?, ?, NOW())`,
    [boardId, userId, role]
  );

  return result.insertId;
}

// GET ALL BOARD MEMBERS
async function getMembers(boardId) {
  if (!Number.isInteger(Number(boardId)) || Number(boardId) <= 0) {
    throw new Error('Invalid board ID');
  }

  const [rows] = await db.execute(
    `SELECT
       bm.*,
       u.name,
       u.email
     FROM board_members bm
     INNER JOIN users u ON bm.user_id = u.id
     WHERE bm.board_id = ?
     ORDER BY bm.joined_at ASC`,
    [boardId]
  );

  return rows;
}

// REMOVE MEMBER
async function removeMember(boardId, userId) {
  validateIds(boardId, userId);

  const [result] = await db.execute(
    `DELETE FROM board_members
     WHERE board_id = ? AND user_id = ?`,
    [boardId, userId]
  );

  return result.affectedRows;
}

// GET MEMBER ROLE
async function getMemberRole(boardId, userId) {
  validateIds(boardId, userId);

  const [rows] = await db.execute(
    `SELECT role
     FROM board_members
     WHERE board_id = ? AND user_id = ?
     LIMIT 1`,
    [boardId, userId]
  );

  return rows.length ? rows[0].role : null;
}

// UPDATE MEMBER ROLE
async function updateMemberRole(boardId, userId, role) {
  validateIds(boardId, userId);

  if (!VALID_ROLES.includes(role)) {
    throw new Error(
      'Invalid role. Allowed roles: owner, editor, viewer'
    );
  }

  const [result] = await db.execute(
    `UPDATE board_members
     SET role = ?
     WHERE board_id = ? AND user_id = ?`,
    [role, boardId, userId]
  );

  return result.affectedRows;
}

module.exports = {
  addMember,
  getMembers,
  removeMember,
  getMemberRole,
  updateMemberRole,
};
