// MySQL connection. Credentials come from the .env file, never from the code.
const mysql = require('mysql2/promise');

// Pool: a group of reusable connections, ready to be used.
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

module.exports = pool;