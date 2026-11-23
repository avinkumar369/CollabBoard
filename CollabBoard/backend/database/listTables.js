require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mysql = require('mysql2/promise');
(async () => {
  try {
    const conn = await mysql.createConnection({
      host: process.env.DB_HOST,
      port: process.env.DB_PORT,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_DATABASE,
    });
    const [rows] = await conn.query('SHOW TABLES');
    console.log('Tables:');
    rows.forEach(r => console.log(Object.values(r)[0]));
    await conn.end();
  } catch (err) {
    console.error('Error listing tables:', err);
    process.exit(1);
  }
})();
