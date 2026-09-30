const { Pool } = require('pg');
const { loadDbConfig } = require('./config');

let pool;

const getPool = () => {
  if (!pool) {
    pool = new Pool({ ...loadDbConfig(), max: 10, connectionTimeoutMillis: 3000 });
  }
  return pool;
};

const close = async () => {
  if (pool) {
    await pool.end();
    pool = undefined;
  }
};

module.exports = { getPool, close };
