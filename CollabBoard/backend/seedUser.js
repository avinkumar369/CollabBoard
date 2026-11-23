require('dotenv').config();
const bcrypt = require('bcrypt');
const db = require('./src/config/db');

(async () => {
  try {
    const email = 'avin963@gmail.com';
    const password = '12345678';
    const name = 'Avin';

    const [existing] = await db.execute('SELECT * FROM users WHERE email = ?', [email]);
    const hash = await bcrypt.hash(password, 10);

    if (existing.length > 0) {
      await db.execute('UPDATE users SET password_hash = ?, name = ?, updated_at = NOW() WHERE email = ?', [hash, name, email]);
      console.log('✅ Updated demo user: avin963@gmail.com / 12345678');
    } else {
      await db.execute('INSERT INTO users (name, email, password_hash, created_at, updated_at) VALUES (?, ?, ?, NOW(), NOW())', [name, email, hash]);
      console.log('✅ Created demo user: avin963@gmail.com / 12345678');
    }
    process.exit(0);
  } catch (err) {
    console.error('Error seeding user:', err);
    process.exit(1);
  }
})();
