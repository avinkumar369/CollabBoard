// src/controllers/shareController.js

const crypto = require('crypto');

const { getMemberRole } = require('../models/boardMemberModel');

const {
  setShareToken,
  getShareToken,
  getBoardByShareToken,
  getObjectsForBoard,
} = require('../models/shareModel');

// The driver returns a JSON column either as an object or as a string,
// depending on the MySQL version, so handle both.
function parseObjectData(value) {
  if (value === null || value === undefined) return {};

  if (typeof value === 'string') {
    try {
      return JSON.parse(value);
    } catch (err) {
      return {};
    }
  }

  return value;
}

// POST /api/boards/:id/share   (owner only)
// Returns the existing token, or creates one. Pass { rotate: true } to
// invalidate the old link and issue a new one.
async function createShareLinkHandler(req, res) {
  try {
    const boardId = req.params.id;

    if (!/^\d+$/.test(String(boardId))) {
      return res.status(400).json({ message: 'Invalid board ID' });
    }

    const role = await getMemberRole(boardId, req.user.id);

    if (role !== 'owner') {
      return res.status(403).json({
        message: 'Only the board owner can share this board',
      });
    }

    const rotate = Boolean(req.body && req.body.rotate === true);

    let token = await getShareToken(boardId);

    if (!token || rotate) {
      token = crypto.randomBytes(24).toString('hex');
      await setShareToken(boardId, token);
    }

    return res.status(200).json({ shareToken: token });
  } catch (err) {
    console.error('Create share link error:', err);

    return res.status(500).json({
      message: 'Failed to create a share link',
    });
  }
}

// GET /api/boards/share/:token   (public, no authentication)
async function getSharedBoardHandler(req, res) {
  try {
    const token = req.params.token;

    if (!token || typeof token !== 'string') {
      return res.status(400).json({ message: 'Invalid share token' });
    }

    const board = await getBoardByShareToken(token);

    if (!board) {
      return res.status(404).json({ message: 'This link is not valid' });
    }

    const objects = await getObjectsForBoard(board.id);

    return res.status(200).json({
      board: {
        id: board.id,
        title: board.title,
        description: board.description,
      },
      objects: objects.map((row) => ({
        id: row.id,
        board_id: row.board_id,
        user_id: row.user_id,
        object_type: row.object_type,
        object_data: parseObjectData(row.object_data),
        created_at: row.created_at,
        updated_at: row.updated_at,
      })),
    });
  } catch (err) {
    console.error('Get shared board error:', err);

    return res.status(500).json({
      message: 'Failed to load the shared board',
    });
  }
}

module.exports = {
  createShareLinkHandler,
  getSharedBoardHandler,
};
