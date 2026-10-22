const express = require('express');
const { body, validationResult } = require('express-validator');

const interactionService        = require('../services/interactionService');
const customerService           = require('../services/customerService');
const contactService            = require('../services/contactService');
const { interactionsCreated }   = require('../middleware/metrics');

const router = express.Router();

// ── Validation ──────────────────────────────────────────────
const interactionRules = [
  body('type').isIn(['call','email','meeting','note']).withMessage('Loại tương tác không hợp lệ'),
  body('subject').trim().notEmpty().withMessage('Tiêu đề không được để trống'),
];

// ── GET /customers/:customerId/interactions/new — form ──────
router.get('/:customerId/interactions/new', async (req, res, next) => {
  try {
    const customer = await customerService.getById(req.params.customerId);
    if (!customer) { const e = new Error('Not found'); e.status = 404; return next(e); }
    const contacts = await contactService.getByCustomerId(customer.id);
    res.render('interactions/form', {
      title:   'Thêm tương tác',
      active:  'customers',
      customer,
      contacts,
      interaction: null,
      typeMap: interactionService.TYPE_MAP,
      errors:  [],
    });
  } catch (err) { next(err); }
});

// ── POST /customers/:customerId/interactions — tạo mới ──────
router.post('/:customerId/interactions', interactionRules, async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      const customer = await customerService.getById(req.params.customerId);
      const contacts = await contactService.getByCustomerId(req.params.customerId);
      return res.status(422).render('interactions/form', {
        title:   'Thêm tương tác',
        active:  'customers',
        customer,
        contacts,
        interaction: req.body,
        typeMap: interactionService.TYPE_MAP,
        errors:  errors.array(),
      });
    }
    await interactionService.create({
      ...req.body,
      customer_id: req.params.customerId,
    });
    interactionsCreated.inc();
    res.redirect(`/customers/${req.params.customerId}?msg=interaction_created`);
  } catch (err) { next(err); }
});

// ── DELETE /customers/:customerId/interactions/:id ───────────
router.delete('/:customerId/interactions/:id', async (req, res, next) => {
  try {
    await interactionService.delete(req.params.id);
    res.redirect(`/customers/${req.params.customerId}?msg=interaction_deleted`);
  } catch (err) { next(err); }
});

module.exports = router;
