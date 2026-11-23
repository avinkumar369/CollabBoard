const db = require('../config/db');

async function createUser(name, email, passwordHash, role = 'user') {
  const [result] = await db.execute(
    'INSERT INTO users (name, email, password_hash, role, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, TRUE, NOW(), NOW())',
    [name, email, passwordHash, role]
  );
  return result.insertId;
}

async function getUserByEmail(email) {
  const [rows] = await db.execute('SELECT * FROM users WHERE email = ?', [email]);
  return rows[0];
}

async function getUserById(id) {
  const [rows] = await db.execute('SELECT id, name, email, avatar_url, role, is_active, created_at, updated_at FROM users WHERE id = ?', [id]);
  return rows[0];
}

module.exports = { createUser, getUserByEmail, getUserById };
