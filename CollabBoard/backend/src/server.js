require('dotenv').config();

const http = require('http');
const app = require('./app');
const { testDatabaseConnection } = require('./config/db');
const { initSocket } = require('./sockets/socket');

const PORT = Number(process.env.PORT) || 5000;
const HOST = '0.0.0.0';

const server = http.createServer(app);

// Initialize Socket.IO
initSocket(server);

// Start server after verifying database connection and running auto-migrations
async function startServer() {
  try {
    await testDatabaseConnection();

    server.listen(PORT, HOST, () => {
      console.log('====================================');
      console.log('🚀 CollabBoard Backend Started');
      console.log(`🌐 Host: ${HOST}`);
      console.log(`🔌 Port: ${PORT}`);
      console.log(`📡 API: http://localhost:${PORT}/api`);
      console.log('🔗 Socket.IO initialized');
      console.log('====================================');
    });

  } catch (error) {
    console.error('❌ Backend startup failed:', error.message);
    process.exit(1);
  }
}

startServer();

// Handle unexpected errors
process.on('unhandledRejection', (reason) => {
  console.error('Unhandled Promise Rejection:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);

  server.close(() => {
    process.exit(1);
  });
});
