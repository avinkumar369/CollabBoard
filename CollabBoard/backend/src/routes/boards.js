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

// All board routes require authentication
router.post('/', authenticateToken, createBoardHandler);
router.get('/', authenticateToken, listBoardsHandler);
router.get('/:id', authenticateToken, getBoardHandler);
router.put('/:id', authenticateToken, updateBoardHandler);
router.delete('/:id', authenticateToken, deleteBoardHandler);
router.post('/:id/duplicate', authenticateToken, duplicateBoardHandler);

module.exports = router;
