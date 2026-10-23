const { Pool } = require('pg');
const logger = require('../utils/logger');

const pool = new Pool({
  host:     process.env.DB_HOST     || 'db',
  port:     parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME     || process.env.POSTGRES_DB   || 'crm_db',
  user:     process.env.DB_USER     || process.env.POSTGRES_USER || 'crm_app',
  password: process.env.DB_PASSWORD || process.env.POSTGRES_PASSWORD || 'password',
  max:                20,
  idleTimeoutMillis:  30000,
  connectionTimeoutMillis: 5000,
});

pool.on('error', (err) => {
  logger.error('db_pool_error', { error: err.message });
});

pool.on('connect', () => {
  logger.info('db_client_connected');
});

module.exports = pool;
