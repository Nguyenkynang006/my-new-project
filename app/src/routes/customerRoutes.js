const express = require('express');
const { body, validationResult } = require('express-validator');

const customerService     = require('../services/customerService');
const { customersCreated } = require('../middleware/metrics');

const router = express.Router();

// ── Validation rules ────────────────────────────────────────
const customerRules = [
  body('name').trim().notEmpty().withMessage('Tên khách hàng không được để trống'),
  body('email').optional({ values: 'falsy' }).isEmail().withMessage('Email không hợp lệ'),
  body('phone').optional({ values: 'falsy' }).matches(/^[\d\s\-+().]{7,20}$/).withMessage('Số điện thoại không hợp lệ'),
  body('status').isIn(['lead','nurturing','active','inactive']).withMessage('Trạng thái không hợp lệ'),
];

// ── GET /customers — danh sách ──────────────────────────────
router.get('/', async (req, res, next) => {
  try {
    const { search, status, page } = req.query;
    const result = await customerService.getAll({
      search,
      status: status || undefined,
      page:   parseInt(page, 10) || 1,
    });
    res.render('customers/index', {
      title:      'Khách hàng',
      active:     'customers',
      ...result,
      search:     search || '',
      statusFilter: status || '',
      statusMap:  customerService.STATUS_MAP,
      msg:        req.query.msg || null,
    });
  } catch (err) { next(err); }
});

// ── GET /customers/new — form tạo mới ───────────────────────
router.get('/new', (req, res) => {
  res.render('customers/form', {
    title:     'Thêm khách hàng',
    active:    'customers',
    customer:  null,
    statusMap: customerService.STATUS_MAP,
    errors:    [],
  });
});

// ── POST /customers — tạo mới ───────────────────────────────
router.post('/', customerRules, async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(422).render('customers/form', {
        title:     'Thêm khách hàng',
        active:    'customers',
        customer:  req.body,
        statusMap: customerService.STATUS_MAP,
        errors:    errors.array(),
      });
    }
    const customer = await customerService.create(req.body);
    customersCreated.inc();
    res.redirect(`/customers/${customer.id}?msg=created`);
  } catch (err) { next(err); }
});

// ── GET /customers/:id — chi tiết ───────────────────────────
router.get('/:id', async (req, res, next) => {
  try {
    const customer = await customerService.getById(req.params.id);
    if (!customer) {
      const err = new Error('Not found');
      err.status = 404;
      return next(err);
    }

    const contactService     = require('../services/contactService');
    const interactionService = require('../services/interactionService');

    const [contacts, interactions] = await Promise.all([
      contactService.getByCustomerId(customer.id),
      interactionService.getByCustomerId(customer.id),
    ]);

    res.render('customers/show', {
      title:    customer.name,
      active:   'customers',
      customer,
      contacts,
      interactions,
      statusMap: customerService.STATUS_MAP,
      typeMap:   interactionService.TYPE_MAP,
      msg:      req.query.msg || null,
    });
  } catch (err) { next(err); }
});

// ── GET /customers/:id/edit — form chỉnh sửa ────────────────
router.get('/:id/edit', async (req, res, next) => {
  try {
    const customer = await customerService.getById(req.params.id);
    if (!customer) {
      const err = new Error('Not found');
      err.status = 404;
      return next(err);
    }
    res.render('customers/form', {
      title:     'Sửa khách hàng',
      active:    'customers',
      customer,
      statusMap: customerService.STATUS_MAP,
      errors:    [],
    });
  } catch (err) { next(err); }
});

// ── PUT /customers/:id — cập nhật ───────────────────────────
router.put('/:id', customerRules, async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(422).render('customers/form', {
        title:     'Sửa khách hàng',
        active:    'customers',
        customer:  { ...req.body, id: req.params.id },
        statusMap: customerService.STATUS_MAP,
        errors:    errors.array(),
      });
    }
    const customer = await customerService.update(req.params.id, req.body);
    if (!customer) {
      const err = new Error('Not found');
      err.status = 404;
      return next(err);
    }
    res.redirect(`/customers/${customer.id}?msg=updated`);
  } catch (err) { next(err); }
});

// ── DELETE /customers/:id — xóa mềm ─────────────────────────
router.delete('/:id', async (req, res, next) => {
  try {
    const result = await customerService.softDelete(req.params.id);
    if (!result) {
      const err = new Error('Not found');
      err.status = 404;
      return next(err);
    }
    res.redirect('/customers?msg=deleted');
  } catch (err) { next(err); }
});

module.exports = router;
