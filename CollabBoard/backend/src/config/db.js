const mysql = require('mysql2/promise');
require('dotenv').config();

// Validate required database configuration
const requiredEnv = [
  'DB_HOST',
  'DB_USER',
  'DB_DATABASE',
];

const missingEnv = requiredEnv.filter(
  (key) => !process.env[key]
);

if (missingEnv.length > 0) {
  throw new Error(
    `Missing database environment variables: ${missingEnv.join(', ')}`
  );
}

// MySQL connection pool
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_DATABASE,

  waitForConnections: true,
  connectionLimit: 10,
  maxIdle: 10,
  idleTimeout: 60000,
  queueLimit: 0,

  enableKeepAlive: true,
  keepAliveInitialDelay: 0,

  charset: 'utf8mb4',
});

// Ensure necessary database columns exist (safe migration)
async function ensureTablesAndColumns() {
  let connection;
  try {
    connection = await pool.getConnection();

    const [cols] = await connection.execute(
      `SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'role'`
    );
    if (cols.length === 0) {
      await connection.execute(`ALTER TABLE users ADD COLUMN role VARCHAR(50) DEFAULT 'user'`);
      console.log('📦 Added missing "role" column to users table.');
    }

    const [activeCols] = await connection.execute(
      `SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'is_active'`
    );
    if (activeCols.length === 0) {
      await connection.execute(`ALTER TABLE users ADD COLUMN is_active BOOLEAN DEFAULT TRUE`);
      console.log('📦 Added missing "is_active" column to users table.');
    }

    const [avatarCols] = await connection.execute(
      `SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'avatar_url'`
    );
    if (avatarCols.length === 0) {
      await connection.execute(`ALTER TABLE users ADD COLUMN avatar_url VARCHAR(255) DEFAULT NULL`);
      console.log('📦 Added missing "avatar_url" column to users table.');
    }
  } catch (err) {
    console.error('⚠️ Auto-migration check warning:', err.message);
  } finally {
    if (connection) connection.release();
  }
}

// Test database connection
async function testDatabaseConnection() {
  let connection;

  try {
    connection = await pool.getConnection();

    await connection.ping();

    await ensureTablesAndColumns();

    console.log('✅ MySQL database connected successfully');
    console.log(`📦 Database: ${process.env.DB_DATABASE}`);

    return true;
  } catch (error) {
    console.error('❌ MySQL connection failed:', {
      message: error.message,
      code: error.code,
    });

    throw error;
  } finally {
    if (connection) {
      connection.release();
    }
  }
}

module.exports = pool;
module.exports.testDatabaseConnection = testDatabaseConnection;
