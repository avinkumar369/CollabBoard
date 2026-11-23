
const express = require('express');
const router = express.Router({ mergeParams: true });

const { authenticateToken } = require('../middleware/auth');

const {
  getObjectsHandler,
  createObjectHandler,
  updateObjectHandler,
  deleteObjectHandler,
} = require('../controllers/canvasController');

// Authentication middleware
router.use(authenticateToken);

// GET canvas objects
router.get('/:id/objects', getObjectsHandler);

// CREATE canvas object
router.post('/:id/objects', createObjectHandler);

// UPDATE canvas object
router.put('/:id/objects/:objectId', updateObjectHandler);

// DELETE canvas object
router.delete('/:id/objects/:objectId', deleteObjectHandler);

// Child router routes:
// /api/boards/:boardId/objects
router.get('/', getObjectsHandler);
router.post('/', createObjectHandler);

router.put('/:objectId', updateObjectHandler);
router.delete('/:objectId', deleteObjectHandler);

module.exports = router;
