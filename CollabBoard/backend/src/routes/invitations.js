// src/routes/invitations.js
const express = require('express');
const router = express.Router({ mergeParams: true }); // need boardId param from parent
const { authenticateToken } = require('../middleware/auth');
const invitationController = require('../controllers/invitationController');

// Create invitation (owner only)
router.post('/', authenticateToken, invitationController.createInvitationHandler);

// List invitations for a board (owner only)
router.get('/', authenticateToken, invitationController.listInvitationsHandler);

// Get invitation details (public, no auth needed for preview)
router.get('/info/:token', invitationController.getInvitationHandler);

// Join board using invitation (auth required)
router.post('/join/:token', authenticateToken, invitationController.joinInvitationHandler);

// Revoke invitation (owner only)
router.delete('/revoke/:token', authenticateToken, invitationController.revokeInvitationHandler);

module.exports = router;
