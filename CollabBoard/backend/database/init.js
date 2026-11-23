require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

(async () => {
  try {
    // Connect without specifying database (may not exist yet)
    const connectionConfig = {
      host: process.env.DB_HOST,
      port: process.env.DB_PORT,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      multipleStatements: true,
    };
    const conn = await mysql.createConnection(connectionConfig);
    console.log('Connected to MySQL');

    // Create database if it does not exist
    await conn.query(`CREATE DATABASE IF NOT EXISTS \`${process.env.DB_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;`);
    console.log('Database ensured');
    await conn.end();

    // Connect to the newly ensured database
    const dbConn = await mysql.createConnection({ ...connectionConfig, database: process.env.DB_DATABASE, multipleStatements: true });
    console.log('Connected to database', process.env.DB_DATABASE);

    // Load schema file
    const schemaPath = path.join(__dirname, 'schema.sql');
    const schemaSql = fs.readFileSync(schemaPath, 'utf8');
    await dbConn.query(schemaSql);
    console.log('Schema applied');
    await dbConn.end();
    console.log('Initialization complete');
  } catch (err) {
    console.error('Init error:', err);
    process.exit(1);
  }
})();
