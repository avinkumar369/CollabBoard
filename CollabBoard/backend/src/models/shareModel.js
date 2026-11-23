// src/models/shareModel.js
//
// Everything the public share link needs, kept in one place so no existing
// model has to change.

const db = require('../config/db');

// Save (or rotate) the token on a board.
async function setShareToken(boardId, token) {
  await db.execute(
    'UPDATE boards SET share_token = ? WHERE id = ?',
    [token, boardId]
  );
}

async function getShareToken(boardId) {
  const [rows] = await db.execute(
    'SELECT share_token FROM boards WHERE id = ?',
    [boardId]
  );

  return rows.length ? rows[0].share_token : null;
}

async function getBoardByShareToken(token) {
  const [rows] = await db.execute(
    `SELECT id, title, description, created_at, updated_at
       FROM boards
      WHERE share_token = ?
      LIMIT 1`,
    [token]
  );

  return rows.length ? rows[0] : null;
}

// Same shape as GET /boards/:id/objects, so the Flutter client parses it
// with CanvasObject.fromJson unchanged.
async function getObjectsForBoard(boardId) {
  const [rows] = await db.execute(
    `SELECT id, board_id, user_id, object_type, object_data, created_at, updated_at
       FROM canvas_objects
      WHERE board_id = ?
      ORDER BY id ASC`,
    [boardId]
  );

  return rows;
}

module.exports = {
  setShareToken,
  getShareToken,
  getBoardByShareToken,
  getObjectsForBoard,
};
