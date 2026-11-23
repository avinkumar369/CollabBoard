
const canvasModel = require('../models/canvasModel');
const boardMemberModel = require('../models/boardMemberModel');
const { getIO } = require('../sockets/socket');

// Validate numeric IDs
function isValidId(id) {
  return (
    id !== undefined &&
    id !== null &&
    /^\d+$/.test(String(id)) &&
    Number(id) > 0
  );
}

// Broadcast successful REST changes through Socket.IO.
function broadcastToBoard(boardId, event, data) {
  const io = getIO();

  if (!io) {
    console.warn('Socket.IO is not initialized');
    return;
  }

  io.to(`board_${boardId}`).emit(event, data);
}

// Check whether user can edit the board
async function checkEditPermission(boardId, userId) {
  const role = await boardMemberModel.getMemberRole(boardId, userId);

  return role === 'owner' || role === 'editor';
}

// GET /api/boards/:boardId/objects
async function getObjectsHandler(req, res) {
  try {
    const boardId = req.params.boardId || req.params.id;

    if (!req.user || !req.user.id) {
      return res.status(401).json({
        message: 'Authentication required',
      });
    }

    if (!isValidId(boardId)) {
      return res.status(400).json({
        message: 'Invalid board ID',
      });
    }

    const role = await boardMemberModel.getMemberRole(
      boardId,
      req.user.id
    );

    if (!role) {
      return res.status(403).json({
        message: 'Access denied',
      });
    }

    const objects = await canvasModel.getObjects(boardId);

    return res.status(200).json(
      Array.isArray(objects) ? objects : []
    );

  } catch (err) {
    console.error('Get objects error:', err);

    return res.status(500).json({
      message: 'Failed to load canvas objects',
      error: process.env.NODE_ENV === 'development'
        ? err.message
        : undefined,
    });
  }
}

// POST /api/boards/:boardId/objects
async function createObjectHandler(req, res) {
  try {
    const boardId = req.params.boardId || req.params.id;

    if (!req.user || !req.user.id) {
      return res.status(401).json({
        message: 'Authentication required',
      });
    }

    if (!isValidId(boardId)) {
      return res.status(400).json({
        message: 'Invalid board ID',
      });
    }

    const canEdit = await checkEditPermission(
      boardId,
      req.user.id
    );

    if (!canEdit) {
      return res.status(403).json({
        message: 'Only owners and editors can modify the canvas',
      });
    }

    const { objectType, objectData } = req.body;

    if (
      typeof objectType !== 'string' ||
      !objectType.trim() ||
      objectData === undefined ||
      objectData === null
    ) {
      return res.status(400).json({
        message: 'Valid objectType and objectData are required',
      });
    }

    // REST is the only database persistence route.
    const insertId = await canvasModel.createObject({
      boardId,
      userId: req.user.id,
      objectType: objectType.trim(),
      objectData,
    });

    const newObj = await canvasModel.getObjectById(insertId);

    if (!newObj) {
      throw new Error('Created object could not be retrieved');
    }

    // Notify all clients in the board room.
    broadcastToBoard(
      boardId,
      'canvas_object_created',
      newObj
    );

    return res.status(201).json(newObj);

  } catch (err) {
    console.error('Create object error:', err);

    return res.status(500).json({
      message: 'Failed to create canvas object',
    });
  }
}

// PUT /api/objects/:objectId
async function updateObjectHandler(req, res) {
  try {
    const objectId = req.params.objectId;

    if (!req.user || !req.user.id) {
      return res.status(401).json({
        message: 'Authentication required',
      });
    }

    if (!isValidId(objectId)) {
      return res.status(400).json({
        message: 'Invalid object ID',
      });
    }

    const obj = await canvasModel.getObjectById(objectId);

    if (!obj) {
      return res.status(404).json({
        message: 'Object not found',
      });
    }

    const canEdit = await checkEditPermission(
      obj.board_id,
      req.user.id
    );

    if (!canEdit) {
      return res.status(403).json({
        message: 'Only owners and editors can modify the canvas',
      });
    }

    const { objectType, objectData } = req.body;

    await canvasModel.updateObject(objectId, {
      objectType: objectType !== undefined
        ? objectType
        : obj.object_type,

      objectData: objectData !== undefined
        ? objectData
        : obj.object_data,
    });

    const updated = await canvasModel.getObjectById(objectId);

    if (!updated) {
      throw new Error('Updated object could not be retrieved');
    }

    // Notify all clients after the database update succeeds.
    broadcastToBoard(
      obj.board_id,
      'canvas_object_updated',
      updated
    );

    return res.status(200).json(updated);

  } catch (err) {
    console.error('Update object error:', err);

    return res.status(500).json({
      message: 'Failed to update canvas object',
    });
  }
}

// DELETE /api/objects/:objectId
async function deleteObjectHandler(req, res) {
  try {
    const objectId = req.params.objectId;

    if (!req.user || !req.user.id) {
      return res.status(401).json({
        message: 'Authentication required',
      });
    }

    if (!isValidId(objectId)) {
      return res.status(400).json({
        message: 'Invalid object ID',
      });
    }

    const obj = await canvasModel.getObjectById(objectId);

    if (!obj) {
      return res.status(404).json({
        message: 'Object not found',
      });
    }

    const canEdit = await checkEditPermission(
      obj.board_id,
      req.user.id
    );

    if (!canEdit) {
      return res.status(403).json({
        message: 'Only owners and editors can modify the canvas',
      });
    }

    const boardId = obj.board_id;

    // REST is the only database deletion route.
    await canvasModel.deleteObject(objectId);

    // Notify all clients after successful deletion.
    broadcastToBoard(
      boardId,
      'canvas_object_deleted',
      {
        id: Number(objectId),
        boardId,
      }
    );

    return res.status(200).json({
      message: 'Object deleted successfully',
    });

  } catch (err) {
    console.error('Delete object error:', err);

    return res.status(500).json({
      message: 'Failed to delete canvas object',
    });
  }
}

module.exports = {
  getObjectsHandler,
  createObjectHandler,
  updateObjectHandler,
  deleteObjectHandler,
};
