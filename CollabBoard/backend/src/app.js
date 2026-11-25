
const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const rateLimit = require('express-rate-limit');

dotenv.config();

const app = express();

// ===============================
// CORS CONFIGURATION
// ===============================

const allowedOrigins = process.env.CORS_ORIGINS
  ? process.env.CORS_ORIGINS.split(',').map(origin => origin.trim())
  : null;

app.use(cors({
  origin: (origin, callback) => {
    // Allow requests without an Origin header (e.g. mobile apps)
    if (!origin) return callback(null, true);

    // Development fallback
    if (!allowedOrigins && process.env.NODE_ENV !== 'production') {
      return callback(null, true);
    }

    if (allowedOrigins && allowedOrigins.includes(origin)) {
      return callback(null, true);
    }

    return callback(new Error('Origin not allowed by CORS'));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// ===============================
// BODY PARSING
// ===============================

app.use(express.json({ limit: '2mb' }));

app.use(express.urlencoded({
  extended: true,
  limit: '2mb',
}));

// ===============================
// RATE LIMITING
// ===============================

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: Number(process.env.AUTH_RATE_LIMIT) || 100,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: {
    message: 'Too many requests. Please try again later.',
  },
});

app.use('/api/auth', authLimiter);

// ===============================
// ROUTES
// ===============================

app.use('/api/auth', require('./routes/auth'));

app.use('/api/boards', require('./routes/boards'));
app.use('/api/boards', require('./routes/boardMembers'));
app.use('/api/boards', require('./routes/canvas'));

app.use(
  '/api/boards/:boardId/invitations',
  require('./routes/invitations')
);

app.use(
  '/api/boards/invitations',
  require('./routes/publicInvitations')
);

app.use('/api/profile', require('./routes/profile'));
app.use('/api/notifications', require('./routes/notifications'));
app.use('/api/activity', require('./routes/activity'));

// ===============================
// HEALTH CHECK
// ===============================

app.get('/api/health', async (req, res) => {
  const db = require('./config/db');

  try {
    const conn = await db.getConnection();
    conn.release();

    res.status(200).json({
      status: 'ok',
      db: 'connected',
      service: 'CollabBoard API',
    });

  } catch (err) {
    console.error('Database health check failed:', err.message);

    res.status(503).json({
      status: 'error',
      db: 'disconnected',
      message: 'Database connection unavailable',
    });
  }
});

// ===============================
// 404 HANDLER
// ===============================

app.use((req, res) => {
  res.status(404).json({
    message: 'API endpoint not found',
    path: req.originalUrl,
  });
});

// ===============================
// CENTRALIZED ERROR HANDLER
// ===============================

app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);

  if (res.headersSent) {
    return next(err);
  }

  const status = err.status || err.statusCode || 500;

  res.status(status).json({
    message:
      process.env.NODE_ENV === 'production' && status >= 500
        ? 'Internal Server Error'
        : err.message || 'Internal Server Error',
  });
});

module.exports = app;

