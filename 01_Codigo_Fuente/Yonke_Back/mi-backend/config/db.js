const { Pool } = require('pg');
require('dotenv').config();

// Variables: DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME.
// DB_SSL=true activa TLS hacia RDS (rejectUnauthorized: false; cambiar a bundle CA en producción).
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : undefined,
});

pool.on('error', (err) => {
  console.error('Error inesperado en el pool de PostgreSQL', err);
});

// `pool` se exporta para las transacciones con cliente dedicado (utils/tx.js).
module.exports = {
  query: (text, params) => pool.query(text, params),
  pool,
};
