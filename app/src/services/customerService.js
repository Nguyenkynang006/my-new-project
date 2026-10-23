const pool   = require('../config/db');
const logger = require('../utils/logger');

// ── Helpers ─────────────────────────────────────────────────
const STATUS_MAP = {
  lead:      'Tiềm năng',
  nurturing: 'Đang chăm sóc',
  active:    'Khách hàng hiện tại',
  inactive:  'Ngừng hoạt động',
};

// ── Service ─────────────────────────────────────────────────
const customerService = {

  STATUS_MAP,

  /** Lấy danh sách (tìm kiếm, lọc trạng thái, phân trang). */
  async getAll({ search, status, page = 1, limit = 12 } = {}) {
    const conditions = ['deleted_at IS NULL'];
    const params     = [];
    let idx          = 1;

    if (search) {
      conditions.push(
        `(name ILIKE $${idx} OR company_name ILIKE $${idx} OR email ILIKE $${idx} OR phone ILIKE $${idx})`
      );
      params.push(`%${search}%`);
      idx++;
    }
    if (status) {
      conditions.push(`status = $${idx}`);
      params.push(status);
      idx++;
    }

    const where = conditions.join(' AND ');

    const countRes = await pool.query(
      `SELECT COUNT(*) FROM customers WHERE ${where}`, params
    );
    const total      = parseInt(countRes.rows[0].count, 10);
    const totalPages = Math.ceil(total / limit) || 1;

    const dataParams = [...params, limit, (page - 1) * limit];
    const dataRes    = await pool.query(
      `SELECT * FROM customers WHERE ${where}
       ORDER BY created_at DESC
       LIMIT $${idx} OFFSET $${idx + 1}`,
      dataParams
    );

    return { customers: dataRes.rows, total, page, totalPages };
  },

  /** Lấy chi tiết một khách hàng (chưa bị xóa mềm). */
  async getById(id) {
    const res = await pool.query(
      'SELECT * FROM customers WHERE id = $1 AND deleted_at IS NULL',
      [id]
    );
    return res.rows[0] || null;
  },

  /** Tạo mới khách hàng. */
  async create(data) {
    const { name, company_name, industry, email, phone, address, status } = data;
    const res = await pool.query(
      `INSERT INTO customers (name, company_name, industry, email, phone, address, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [name, company_name || null, industry || null, email || null, phone || null, address || null, status || 'lead']
    );
    logger.info('customer_created', { customer_id: res.rows[0].id, name });
    return res.rows[0];
  },

  /** Cập nhật khách hàng. */
  async update(id, data) {
    const { name, company_name, industry, email, phone, address, status } = data;
    const res = await pool.query(
      `UPDATE customers
       SET name=$1, company_name=$2, industry=$3, email=$4, phone=$5, address=$6, status=$7,
           updated_at = NOW()
       WHERE id=$8 AND deleted_at IS NULL RETURNING *`,
      [name, company_name || null, industry || null, email || null, phone || null, address || null, status, id]
    );
    if (res.rows[0]) logger.info('customer_updated', { customer_id: id });
    return res.rows[0] || null;
  },

  /** Xóa mềm — giữ lại dữ liệu lịch sử CRM. */
  async softDelete(id) {
    const res = await pool.query(
      `UPDATE customers SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL RETURNING id`,
      [id]
    );
    if (res.rows[0]) logger.info('customer_deleted', { customer_id: id });
    return res.rows[0] || null;
  },

  /** Thống kê số lượng khách hàng theo trạng thái (dashboard). */
  async getStats() {
    const res = await pool.query(
      `SELECT status, COUNT(*) AS count
       FROM customers WHERE deleted_at IS NULL
       GROUP BY status`
    );
    const stats = { lead: 0, nurturing: 0, active: 0, inactive: 0, total: 0 };
    res.rows.forEach(r => {
      stats[r.status] = parseInt(r.count, 10);
      stats.total += parseInt(r.count, 10);
    });
    return stats;
  },
};

module.exports = customerService;
