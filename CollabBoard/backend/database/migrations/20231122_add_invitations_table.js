// migration: add invitations table
// Run with: node ./backend/database/migrations/20231122_add_invitations_table.js
const db = require('../src/config/db');

async function up() {
  await db.execute(`
    CREATE TABLE IF NOT EXISTS invitations (
      id INT AUTO_INCREMENT PRIMARY KEY,
      board_id INT NOT NULL,
      inviter_id INT NOT NULL,
      token VARCHAR(255) NOT NULL UNIQUE,
      role ENUM('editor','viewer') NOT NULL DEFAULT 'viewer',
      max_uses INT NOT NULL DEFAULT 1,
      uses INT NOT NULL DEFAULT 0,
      expires_at DATETIME NOT NULL,
      revoked BOOLEAN NOT NULL DEFAULT FALSE,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT fk_inv_board FOREIGN KEY (board_id) REFERENCES boards(id) ON DELETE CASCADE,
      CONSTRAINT fk_inv_user FOREIGN KEY (inviter_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB;
  `);
  console.log('Invitations table created');
}

async function down() {
  await db.execute('DROP TABLE IF EXISTS invitations');
  console.log('Invitations table dropped');
}

module.exports = { up, down };
