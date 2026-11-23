
const db = require('../config/db');

// Safely parse JSON stored in MySQL
function parseObjectData(value) {
  if (value === null || value === undefined) {
    return {};
  }

  if (typeof value !== 'string') {
    return value;
  }

  try {
    return JSON.parse(value);
  } catch (error) {
    console.error('Invalid canvas object JSON:', error.message);

    // Preserve the original value instead of crashing the API.
    return value;
  }
}

// GET all objects belonging to a board
async function getObjects(boardId) {
  const [rows] = await db.execute(
    `SELECT
       id,
       board_id,
       user_id,
       object_type,
       object_data,
       created_at,
       updated_at
     FROM canvas_objects
     WHERE board_id = ?
     ORDER BY id ASC`,
    [boardId]
  );

  return rows.map((row) => ({
    ...row,
    object_data: parseObjectData(row.object_data),
  }));
}

// GET a single canvas object
async function getObjectById(id) {
  const [rows] = await db.execute(
    `SELECT
       id,
       board_id,
       user_id,
       object_type,
       object_data,
       created_at,
       updated_at
     FROM canvas_objects
     WHERE id = ?
     LIMIT 1`,
    [id]
  );

  if (!rows.length) {
    return null;
  }

  return {
    ...rows[0],
    object_data: parseObjectData(rows[0].object_data),
  };
}

// CREATE canvas object
async function createObject({
  boardId,
  userId,
  objectType,
  objectData,
}) {
  const dataJson =
    typeof objectData === 'string'
      ? objectData
      : JSON.stringify(objectData);

  if (dataJson === undefined) {
    throw new Error('Canvas object data must be JSON serializable');
  }

  // Validate JSON before inserting
  JSON.parse(dataJson);

  const [result] = await db.execute(
    `INSERT INTO canvas_objects
      (board_id, user_id, object_type, object_data, created_at, updated_at)
     VALUES (?, ?, ?, ?, NOW(), NOW())`,
    [boardId, userId, objectType, dataJson]
  );

  return result.insertId;
}

// UPDATE canvas object
async function updateObject(id, {
  objectType,
  objectData,
}) {
  const dataJson =
    typeof objectData === 'string'
      ? objectData
      : JSON.stringify(objectData);

  if (dataJson === undefined) {
    throw new Error('Canvas object data must be JSON serializable');
  }

  JSON.parse(dataJson);

  const [result] = await db.execute(
    `UPDATE canvas_objects
     SET object_type = ?,
         object_data = ?,
         updated_at = NOW()
     WHERE id = ?`,
    [objectType, dataJson, id]
  );

  return result.affectedRows;
}

// DELETE canvas object
async function deleteObject(id) {
  const [result] = await db.execute(
    'DELETE FROM canvas_objects WHERE id = ?',
    [id]
  );

  return result.affectedRows;
}

// CLEAR all objects from a board
async function clearBoardObjects(boardId) {
  const [result] = await db.execute(
    'DELETE FROM canvas_objects WHERE board_id = ?',
    [boardId]
  );

  return result.affectedRows;
}

module.exports = {
  getObjects,
  getObjectById,
  createObject,
  updateObject,
  deleteObject,
  clearBoardObjects,
};
