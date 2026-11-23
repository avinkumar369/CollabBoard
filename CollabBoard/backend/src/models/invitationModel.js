// src/models/invitationModel.js
const crypto = require('crypto');
const db = require('../config/db');

/**
 * Generate a secure random token (url‑safe) for an invitation.
 * 32 bytes => 43‑character base64url string.
 */
function generateToken() {
  return crypto.randomBytes(32).toString('base64url');
}

/** Create a new invitation.
 * @param {Object} opts
 *   - boardId: ID of the board being shared
 *   - inviterId: user ID of the board owner creating the invite
 *   - expiresInSec: optional TTL in seconds (default 7 days)
 *   - maxUses: optional max number of uses (default 1)
 *   - role: role granted to the invited member ("editor" or "viewer")
 * @returns {Promise<Object>} the created invitation row
 */
async function createInvitation({ boardId, inviterId, expiresInSec = 7 * 24 * 60 * 60, maxUses = 1, role = 'viewer' }) {
  const token = generateToken();
  const expiresAt = new Date(Date.now() + expiresInSec * 1000);
  const [result] = await db.execute(
    `INSERT INTO invitations (board_id, inviter_id, token, role, max_uses, expires_at, created_at, revoked)
     VALUES (?,?,?,?,?, ?, NOW(), false)`,
    [boardId, inviterId, token, role, maxUses, expiresAt]
  );
  // Return the full row for convenience
  const [rows] = await db.execute('SELECT * FROM invitations WHERE id = ?', [result.insertId]);
  return rows[0];
}

/** Retrieve an invitation by its token (code). */
async function getByToken(token) {
  const [rows] = await db.execute('SELECT * FROM invitations WHERE token = ?', [token]);
  return rows[0] || null;
}

/** Mark an invitation as used (increment usage counter). */
async function incrementUsage(invitationId) {
  await db.execute(
    `UPDATE invitations SET uses = uses + 1 WHERE id = ?`,
    [invitationId]
  );
}

/** Revoke an invitation (owner action). */
async function revoke(invitationId) {
  const [result] = await db.execute(
    `UPDATE invitations SET revoked = true WHERE id = ?`,
    [invitationId]
  );
  return result.affectedRows;
}

module.exports = { createInvitation, getByToken, incrementUsage, revoke };
