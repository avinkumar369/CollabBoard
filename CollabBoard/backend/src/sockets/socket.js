
const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const boardMemberModel = require('../models/boardMemberModel');

let io = null;

// Track active users per board:
// boardId -> Map(socketId, user information)
const boardActiveUsers = new Map();

function initSocket(server) {
  io = new Server(server, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST'],
    },
  });

  // Socket authentication middleware
  io.use((socket, next) => {
    const token =
      socket.handshake.auth?.token ||
      socket.handshake.headers?.authorization?.split(' ')[1] ||
      socket.handshake.query?.token;

    if (!token) {
      return next(new Error('Authentication error: Token missing'));
    }

    jwt.verify(
      token,
      process.env.JWT_SECRET || 'fallback_secret',
      (err, decoded) => {
        if (err) {
          return next(new Error('Authentication error: Invalid token'));
        }

        socket.user = decoded;
        next();
      }
    );
  });

  io.on('connection', (socket) => {
    console.log(
      `🤝 Authenticated socket connected: ${socket.id} (User: ${socket.user?.name})`
    );

    async function getUserRole(boardId) {
      return boardMemberModel.getMemberRole(
        boardId,
        socket.user.id
      );
    }

    // JOIN BOARD
    socket.on('join_board', async (data) => {
      try {
        const boardId =
          typeof data === 'object' ? data.boardId : data;

        if (!boardId) return;

        const role = await getUserRole(boardId);

        if (!role) {
          socket.emit('error', {
            message: 'Access denied to board',
          });
          return;
        }

        // Leave previous board if switching boards.
        if (
          socket.currentBoardId &&
          String(socket.currentBoardId) !== String(boardId)
        ) {
          leaveCurrentBoard(socket);
        }

        const roomName = `board_${boardId}`;

        socket.join(roomName);
        socket.currentBoardId = boardId;

        if (!boardActiveUsers.has(boardId)) {
          boardActiveUsers.set(boardId, new Map());
        }

        const usersMap = boardActiveUsers.get(boardId);

        usersMap.set(socket.id, {
          userId: socket.user.id,
          name: socket.user.name,
          email: socket.user.email,
          role,
        });

        const activeList = Array.from(usersMap.values());

        io.to(roomName).emit('active_users', activeList);

        socket.to(roomName).emit('user_joined', {
          userId: socket.user.id,
          name: socket.user.name,
          email: socket.user.email,
          role,
        });

        console.log(
          `User ${socket.user.name} joined room ${roomName}`
        );

      } catch (err) {
        console.error('Socket join_board error:', err);

        socket.emit('error', {
          message: 'Failed to join board',
        });
      }
    });

    // LEAVE BOARD
    socket.on('leave_board', (data) => {
      const boardId =
        (typeof data === 'object' ? data.boardId : data) ||
        socket.currentBoardId;

      if (!boardId) return;

      leaveBoard(socket, boardId);
    });

    // LIVE DRAWING UPDATES
    // Temporary drawing data only.
    // Permanent objects must be saved through REST.
    socket.on('drawing_updated', async (data) => {
      try {
        const { boardId } = data;

        if (!boardId) return;

        if (
          String(socket.currentBoardId) !== String(boardId)
        ) {
          return;
        }

        const role = await getUserRole(boardId);

        if (role === 'owner' || role === 'editor') {
          socket.to(`board_${boardId}`).emit(
            'drawing_updated',
            data
          );
        }

      } catch (err) {
        console.error('Socket drawing_updated error:', err);
      }
    });

    // CURSOR MOVEMENT
    socket.on('cursor_moved', async (data) => {
      try {
        const { boardId, position } = data;

        if (!boardId) return;

        if (
          String(socket.currentBoardId) !== String(boardId)
        ) {
          return;
        }

        const role = await getUserRole(boardId);

        if (!role) return;

        socket.to(`board_${boardId}`).emit(
          'cursor_moved',
          {
            userId: socket.user.id,
            name: socket.user.name,
            position,
          }
        );

      } catch (err) {
        console.error('Socket cursor_moved error:', err);
      }
    });

    // DISCONNECT
    socket.on('disconnect', () => {
      console.log(`👋 Socket disconnected: ${socket.id}`);

      if (socket.currentBoardId) {
        leaveBoard(socket, socket.currentBoardId);
      }
    });
  });
}

// Remove a socket from a board.
function leaveBoard(socket, boardId) {
  if (!boardId) return;

  const roomName = `board_${boardId}`;

  socket.leave(roomName);

  if (boardActiveUsers.has(boardId)) {
    const usersMap = boardActiveUsers.get(boardId);

    usersMap.delete(socket.id);

    if (usersMap.size === 0) {
      boardActiveUsers.delete(boardId);
    } else {
      io.to(roomName).emit(
        'active_users',
        Array.from(usersMap.values())
      );
    }
  }

  socket.to(roomName).emit('user_left', {
    userId: socket.user.id,
    name: socket.user.name,
  });

  if (
    String(socket.currentBoardId) === String(boardId)
  ) {
    delete socket.currentBoardId;
  }
}

// Leave the currently joined board.
function leaveCurrentBoard(socket) {
  if (socket.currentBoardId) {
    leaveBoard(socket, socket.currentBoardId);
  }
}

function getIO() {
  return io;
}

module.exports = {
  initSocket,
  getIO,
};
