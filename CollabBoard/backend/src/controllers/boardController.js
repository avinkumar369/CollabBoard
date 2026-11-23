
// src/controllers/boardController.js

const {
  createBoard,
  getBoardById,
  getBoardsForUser,
  updateBoard,
  deleteBoard,
  duplicateBoard,
} = require('../models/boardModel');

const {
  addMember,
  getMemberRole,
} = require('../models/boardMemberModel');

// Helper: Validate board ID
function isValidBoardId(id) {
  return id !== undefined &&
    id !== null &&
    /^\d+$/.test(String(id)) &&
    Number(id) > 0;
}

// Helper: Check board permissions
async function checkPermission(boardId, userId) {
  const role = await getMemberRole(boardId, userId);

  return role === 'owner' || role === 'editor';
}

// POST /api/boards
async function createBoardHandler(req, res) {
  try {
    const { title, description = '' } = req.body;

    if (!req.user || !req.user.id) {
      return res.status(401).json({
        message: 'Authentication required',
      });
    }

    if (!title || typeof title !== 'string' || !title.trim()) {
      return res.status(400).json({
        message: 'A valid board title is required',
      });
    }

    const boardId = await createBoard({
      ownerId: req.user.id,
      title: title.trim(),
      description: typeof description === 'string' ? description.trim() : '',
    });

    await addMember({
      boardId,
      userId: req.user.id,
      role: 'owner',
    });

    return res.status(201).json({
      id: boardId,
      title: title.trim(),
      description,
      message: 'Board created successfully',
    });
  } catch (err) {
    console.error('Create board error:', err);

    return res.status(500).json({
      message: 'Failed to create board',
    });
  }
}

// GET /api/boards
async function listBoardsHandler(req, res) {
  try {
    if (!req.user || !req.user.id) {
      return res.status(401).json({
        message: 'Authentication required',
      });
    }

    const boards = await getBoardsForUser(req.user.id);

    return res.status(200).json(boards || []);
  } catch (err) {
    console.error('List boards error:', err);

    return res.status(500).json({
      message: 'Failed to load boards',
    });
  }
}

// GET /api/boards/:id
async function getBoardHandler(req, res) {
  try {
    const boardId = req.params.id;

    if (!isValidBoardId(boardId)) {
      return res.status(400).json({
        message: 'Invalid board ID',
      });
    }

    const board = await getBoardById(boardId);

    if (!board) {
      return res.status(404).json({
        message: 'Board not found',
      });
    }

    const role = await getMemberRole(board.id, req.user.id);

    if (!role) {
      return res.status(403).json({
        message: 'Access denied',
      });
    }

    return res.status(200).json(board);
  } catch (err) {
    console.error('Get board error:', err);

    return res.status(500).json({
      message: 'Failed to load board',
    });
  }
}

// PUT /api/boards/:id
async function updateBoardHandler(req, res) {
  try {
    const boardId = req.params.id;

    if (!isValidBoardId(boardId)) {
      return res.status(400).json({
        message: 'Invalid board ID',
      });
    }

    const hasPerm = await checkPermission(boardId, req.user.id);

    if (!hasPerm) {
      return res.status(403).json({
        message: 'Access denied',
      });
    }

    const { title, description } = req.body;

    if (
      title !== undefined &&
      (typeof title !== 'string' || !title.trim())
    ) {
      return res.status(400).json({
        message: 'Invalid board title',
      });
    }

    const affected = await updateBoard(boardId, {
      title: title !== undefined ? title.trim() : undefined,
      description,
    });

    if (affected === 0) {
      return res.status(404).json({
        message: 'Board not found',
      });
    }

    return res.status(200).json({
      message: 'Board updated successfully',
    });
  } catch (err) {
    console.error('Update board error:', err);

    return res.status(500).json({
      message: 'Failed to update board',
    });
  }
}

// DELETE /api/boards/:id
async function deleteBoardHandler(req, res) {
  try {
    const boardId = req.params.id;

    if (!isValidBoardId(boardId)) {
      return res.status(400).json({
        message: 'Invalid board ID',
      });
    }

    const role = await getMemberRole(boardId, req.user.id);

    if (!role) {
      return res.status(403).json({
        message: 'Access denied',
      });
    }

    if (role !== 'owner') {
      return res.status(403).json({
        message: 'Only the board owner can delete this board',
      });
    }

    const affected = await deleteBoard(boardId);

    if (affected === 0) {
      return res.status(404).json({
        message: 'Board not found',
      });
    }

    return res.status(200).json({
      message: 'Board deleted successfully',
    });
  } catch (err) {
    console.error('Delete board error:', err);

    return res.status(500).json({
      message: 'Failed to delete board',
    });
  }
}

// POST /api/boards/:id/duplicate
async function duplicateBoardHandler(req, res) {
  try {
    const boardId = req.params.id;

    if (!isValidBoardId(boardId)) {
      return res.status(400).json({
        message: 'Invalid board ID',
      });
    }

    const role = await getMemberRole(boardId, req.user.id);

    if (!role) {
      return res.status(403).json({
        message: 'Access denied',
      });
    }

    const newTitle = req.body.title;

    const newBoardId = await duplicateBoard(
      boardId,
      req.user.id,
      newTitle
    );

    if (!newBoardId) {
      return res.status(404).json({
        message: 'Board not found',
      });
    }

    await addMember({
      boardId: newBoardId,
      userId: req.user.id,
      role: 'owner',
    });

    const newBoard = await getBoardById(newBoardId);

    return res.status(201).json(newBoard);
  } catch (err) {
    console.error('Duplicate board error:', err);

    return res.status(500).json({
      message: 'Failed to duplicate board',
    });
  }
}

module.exports = {
  createBoardHandler,
  listBoardsHandler,
  getBoardHandler,
  updateBoardHandler,
  deleteBoardHandler,
  duplicateBoardHandler,
};
