// src/routes/boards.js
const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');
const {
  createBoardHandler,
  listBoardsHandler,
  getBoardHandler,
  updateBoardHandler,
  deleteBoardHandler,
  duplicateBoardHandler,
} = require('../controllers/boardController');

const {
  createShareLinkHandler,
  getSharedBoardHandler,
} = require('../controllers/shareController');

// PUBLIC ROUTE - no authentication.
// IMPORTANT: this must be declared BEFORE '/:id', otherwise Express matches
// '/boards/share/abc' as '/boards/:id' with id = "share" and rejects it.
router.get('/share/:token', getSharedBoardHandler);

// All other board routes require authentication
router.post('/', authenticateToken, createBoardHandler);
router.get('/', authenticateToken, listBoardsHandler);
router.get('/:id', authenticateToken, getBoardHandler);
router.put('/:id', authenticateToken, updateBoardHandler);
router.delete('/:id', authenticateToken, deleteBoardHandler);
router.post('/:id/duplicate', authenticateToken, duplicateBoardHandler);

// Owner-only: returns (or creates) the read-only share token
router.post('/:id/share', authenticateToken, createShareLinkHandler);

module.exports = router;
