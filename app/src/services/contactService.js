const pool   = require('../config/db');
const logger = require('../utils/logger');

const contactService = {

  /** Lấy tất cả liên hệ của một khách hàng. */
  async getByCustomerId(customerId) {
    const res = await pool.query(
      `SELECT * FROM contacts WHERE customer_id = $1 ORDER BY is_primary DESC, created_at ASC`,
      [customerId]
    );
    return res.rows;
  },

  /** Lấy một liên hệ theo id. */
  async getById(id) {
    const res = await pool.query('SELECT * FROM contacts WHERE id = $1', [id]);
    return res.rows[0] || null;
  },

  /** Tạo liên hệ mới. */
  async create(data) {
    const { customer_id, first_name, last_name, job_title, email, phone, is_primary } = data;

    // Nếu đặt làm liên hệ chính thì bỏ is_primary ở các liên hệ cũ
    if (is_primary) {
      await pool.query(
        'UPDATE contacts SET is_primary = FALSE WHERE customer_id = $1',
        [customer_id]
      );
    }

    const res = await pool.query(
      `INSERT INTO contacts (customer_id, first_name, last_name, job_title, email, phone, is_primary)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [customer_id, first_name, last_name, job_title || null, email || null, phone || null, is_primary ? true : false]
    );
    logger.info('contact_created', { contact_id: res.rows[0].id, customer_id });
    return res.rows[0];
  },

  /** Cập nhật liên hệ. */
  async update(id, data) {
    const { first_name, last_name, job_title, email, phone, is_primary, customer_id } = data;

    if (is_primary && customer_id) {
      await pool.query(
        'UPDATE contacts SET is_primary = FALSE WHERE customer_id = $1 AND id != $2',
        [customer_id, id]
      );
    }

    const res = await pool.query(
      `UPDATE contacts
       SET first_name=$1, last_name=$2, job_title=$3, email=$4, phone=$5, is_primary=$6
       WHERE id=$7 RETURNING *`,
      [first_name, last_name, job_title || null, email || null, phone || null, is_primary ? true : false, id]
    );
    if (res.rows[0]) logger.info('contact_updated', { contact_id: id });
    return res.rows[0] || null;
  },

  /** Xóa liên hệ (hard delete). */
  async delete(id) {
    const res = await pool.query(
      'DELETE FROM contacts WHERE id = $1 RETURNING id, customer_id',
      [id]
    );
    if (res.rows[0]) logger.info('contact_deleted', { contact_id: id });
    return res.rows[0] || null;
  },
};

module.exports = contactService;
