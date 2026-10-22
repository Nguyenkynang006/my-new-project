const express = require('express');
const { body, validationResult } = require('express-validator');

const contactService      = require('../services/contactService');
const customerService     = require('../services/customerService');
const { contactsCreated } = require('../middleware/metrics');

const router = express.Router();

// ── Validation ──────────────────────────────────────────────
const contactRules = [
  body('first_name').trim().notEmpty().withMessage('Họ không được để trống'),
  body('last_name').trim().notEmpty().withMessage('Tên không được để trống'),
  body('email').optional({ values: 'falsy' }).isEmail().withMessage('Email không hợp lệ'),
  body('phone').optional({ values: 'falsy' }).matches(/^[\d\s\-+().]{7,20}$/).withMessage('Số điện thoại không hợp lệ'),
];

// ── POST /customers/:customerId/contacts — tạo mới ──────────
router.post('/:customerId/contacts', contactRules, async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      const customer = await customerService.getById(req.params.customerId);
      return res.status(422).render('contacts/form', {
        title:      'Thêm liên hệ',
        active:     'customers',
        customer,
        contact:    req.body,
        errors:     errors.array(),
      });
    }
    await contactService.create({
      ...req.body,
      customer_id: req.params.customerId,
    });
    contactsCreated.inc();
    res.redirect(`/customers/${req.params.customerId}?msg=contact_created`);
  } catch (err) { next(err); }
});

// ── GET /customers/:customerId/contacts/new — form ──────────
router.get('/:customerId/contacts/new', async (req, res, next) => {
  try {
    const customer = await customerService.getById(req.params.customerId);
    if (!customer) { const e = new Error('Not found'); e.status = 404; return next(e); }
    res.render('contacts/form', {
      title:   'Thêm liên hệ',
      active:  'customers',
      customer,
      contact: null,
      errors:  [],
    });
  } catch (err) { next(err); }
});

// ── GET /customers/:customerId/contacts/:id/edit ────────────
router.get('/:customerId/contacts/:id/edit', async (req, res, next) => {
  try {
    const [customer, contact] = await Promise.all([
      customerService.getById(req.params.customerId),
      contactService.getById(req.params.id),
    ]);
    if (!customer || !contact) { const e = new Error('Not found'); e.status = 404; return next(e); }
    res.render('contacts/form', {
      title:   'Sửa liên hệ',
      active:  'customers',
      customer,
      contact,
      errors:  [],
    });
  } catch (err) { next(err); }
});

// ── PUT /customers/:customerId/contacts/:id ─────────────────
router.put('/:customerId/contacts/:id', contactRules, async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      const customer = await customerService.getById(req.params.customerId);
      return res.status(422).render('contacts/form', {
        title:   'Sửa liên hệ',
        active:  'customers',
        customer,
        contact: { ...req.body, id: req.params.id },
        errors:  errors.array(),
      });
    }
    await contactService.update(req.params.id, {
      ...req.body,
      customer_id: req.params.customerId,
    });
    res.redirect(`/customers/${req.params.customerId}?msg=contact_updated`);
  } catch (err) { next(err); }
});

// ── DELETE /customers/:customerId/contacts/:id ──────────────
router.delete('/:customerId/contacts/:id', async (req, res, next) => {
  try {
    await contactService.delete(req.params.id);
    res.redirect(`/customers/${req.params.customerId}?msg=contact_deleted`);
  } catch (err) { next(err); }
});

module.exports = router;
