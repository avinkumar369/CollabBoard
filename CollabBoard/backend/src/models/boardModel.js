// src/models/boardModel.js
const db = require('../config/db');

// Create a new board and return its id
async function createBoard({ ownerId, title, description }) {
  const [result] = await db.execute(
    'INSERT INTO boards (owner_id, title, description, created_at, updated_at) VALUES (?, ?, ?, NOW(), NOW())',
    [ownerId, title, description]
  );
  return result.insertId;
}

async function getBoardById(boardId) {
  const [rows] = await db.execute('SELECT * FROM boards WHERE id = ?', [boardId]);
  return rows[0];
}

async function getBoardsForUser(userId) {
  const [rows] = await db.execute(
    `SELECT DISTINCT b.* FROM boards b
     LEFT JOIN board_members bm ON b.id = bm.board_id
     WHERE b.owner_id = ? OR bm.user_id = ?
     ORDER BY b.updated_at DESC, b.id DESC`,
    [userId, userId]
  );
  return rows;
}

async function updateBoard(boardId, { title, description }) {
  const [result] = await db.execute(
    'UPDATE boards SET title = ?, description = ?, updated_at = NOW() WHERE id = ?',
    [title, description, boardId]
  );
  return result.affectedRows;
}

async function deleteBoard(boardId) {
  const [result] = await db.execute('DELETE FROM boards WHERE id = ?', [boardId]);
  return result.affectedRows;
}

async function duplicateBoard(boardId, newOwnerId, newTitle) {
  const original = await getBoardById(boardId);
  if (!original) return null;
  const newBoardId = await createBoard({
    ownerId: newOwnerId,
    title: newTitle || `${original.title} (Copy)`,
    description: original.description,
  });
  const [objects] = await db.execute('SELECT * FROM canvas_objects WHERE board_id = ?', [boardId]);
  for (const obj of objects) {
    await db.execute(
      'INSERT INTO canvas_objects (board_id, user_id, object_type, object_data, created_at, updated_at) VALUES (?, ?, ?, ?, NOW(), NOW())',
      [newBoardId, newOwnerId, obj.object_type, obj.object_data]
    );
  }
  return newBoardId;
}

module.exports = { createBoard, getBoardById, getBoardsForUser, updateBoard, deleteBoard, duplicateBoard };
