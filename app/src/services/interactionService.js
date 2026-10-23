const pool   = require('../config/db');
const logger = require('../utils/logger');

const TYPE_MAP = {
  call:    'Cuộc gọi',
  email:   'Email',
  meeting: 'Cuộc họp',
  note:    'Ghi chú',
};

const interactionService = {

  TYPE_MAP,

  /** Lấy tương tác của khách hàng, mới nhất trước. */
  async getByCustomerId(customerId) {
    const res = await pool.query(
      `SELECT i.*, c.first_name AS contact_first, c.last_name AS contact_last
       FROM interactions i
       LEFT JOIN contacts c ON c.id = i.contact_id
       WHERE i.customer_id = $1
       ORDER BY i.occurred_at DESC`,
      [customerId]
    );
    return res.rows;
  },

  /** Lấy tương tác gần đây nhất (cho dashboard). */
  async getRecent(limit = 10) {
    const res = await pool.query(
      `SELECT i.*, cu.name AS customer_name, cu.company_name,
              c.first_name AS contact_first, c.last_name AS contact_last
       FROM interactions i
       JOIN customers cu ON cu.id = i.customer_id AND cu.deleted_at IS NULL
       LEFT JOIN contacts c ON c.id = i.contact_id
       ORDER BY i.occurred_at DESC
       LIMIT $1`,
      [limit]
    );
    return res.rows;
  },

  /** Tạo tương tác mới. */
  async create(data) {
    const { customer_id, contact_id, type, subject, notes, occurred_at } = data;
    // occurred_at từ form là "YYYY-MM-DDTHH:MM" (không timezone).
    // Nếu trống → để DB dùng DEFAULT now(). Nếu có → dùng giá trị truyền vào.
    const resolvedAt = occurred_at && occurred_at.trim() ? new Date(occurred_at) : new Date();
    const res = await pool.query(
      `INSERT INTO interactions (customer_id, contact_id, type, subject, notes, occurred_at)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [customer_id, contact_id || null, type, subject, notes || null, resolvedAt]
    );
    logger.info('interaction_created', {
      interaction_id: res.rows[0].id,
      customer_id,
      type,
    });
    return res.rows[0];
  },

  /** Xóa tương tác. */
  async delete(id) {
    const res = await pool.query(
      'DELETE FROM interactions WHERE id = $1 RETURNING id, customer_id',
      [id]
    );
    if (res.rows[0]) logger.info('interaction_deleted', { interaction_id: id });
    return res.rows[0] || null;
  },
};

module.exports = interactionService;
