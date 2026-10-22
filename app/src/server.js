const express        = require('express');
const path           = require('path');
const methodOverride = require('method-override');
const { register }   = require('prom-client');

const logger              = require('./utils/logger');
const pool                = require('./config/db');
const { metricsMiddleware } = require('./middleware/metrics');
const errorHandler        = require('./middleware/errorHandler');
const customerRoutes      = require('./routes/customerRoutes');
const contactRoutes       = require('./routes/contactRoutes');
const interactionRoutes   = require('./routes/interactionRoutes');
const customerService     = require('./services/customerService');
const interactionService  = require('./services/interactionService');

const app  = express();
const PORT = parseInt(process.env.APP_PORT || '3000', 10);

// ── View engine ─────────────────────────────────────────────
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// ── Middleware ───────────────────────────────────────────────
app.use(express.static(path.join(__dirname, 'public')));
app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(methodOverride('_method'));
app.use(metricsMiddleware);

// ── Request logging ─────────────────────────────────────────
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    logger.info('http_request', {
      method:   req.method,
      path:     req.originalUrl,
      status:   res.statusCode,
      duration: Date.now() - start,
    });
  });
  next();
});

// ── Routes ──────────────────────────────────────────────────

// Dashboard
app.get('/', async (req, res, next) => {
  try {
    const [stats, recentInteractions] = await Promise.all([
      customerService.getStats(),
      interactionService.getRecent(10),
    ]);
    res.render('dashboard', {
      title:  'Dashboard',
      active: 'dashboard',
      stats,
      recentInteractions,
      statusMap: customerService.STATUS_MAP,
      typeMap:   interactionService.TYPE_MAP,
    });
  } catch (err) { next(err); }
});

// CRM routes
app.use('/customers', customerRoutes);
app.use('/customers', contactRoutes);
app.use('/customers', interactionRoutes);

// ── Health endpoint ─────────────────────────────────────────
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({
      status:    'healthy',
      db:        'connected',
      uptime:    process.uptime(),
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    logger.error('health_check_failed', { error: err.message });
    res.status(503).json({
      status: 'unhealthy',
      db:     'disconnected',
    });
  }
});

// ── Metrics endpoint (Prometheus) ───────────────────────────
app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (err) {
    res.status(500).end(err.message);
  }
});

// ── 404 fallback ────────────────────────────────────────────
app.use((req, res, next) => {
  const err = new Error('Not found');
  err.status = 404;
  next(err);
});

// ── Error handler ───────────────────────────────────────────
app.use(errorHandler);

// ── Start server ────────────────────────────────────────────
app.listen(PORT, '0.0.0.0', () => {
  logger.info('server_started', { port: PORT });
});

module.exports = app;
