const client = require('prom-client');

// Collect Node.js default metrics (CPU, memory, event-loop …)
client.collectDefaultMetrics({ prefix: 'crm_' });

// ── Custom application metrics ──────────────────────────────
const httpRequestsTotal = new client.Counter({
  name:       'crm_http_requests_total',
  help:       'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
});

const httpRequestDuration = new client.Histogram({
  name:       'crm_http_request_duration_seconds',
  help:       'HTTP request duration in seconds',
  labelNames: ['method', 'route'],
  buckets:    [0.005, 0.01, 0.05, 0.1, 0.5, 1, 5],
});

const httpErrors = new client.Counter({
  name:       'crm_http_errors_total',
  help:       'Total HTTP 4xx/5xx responses',
  labelNames: ['method', 'status_code'],
});

const customersCreated = new client.Counter({
  name: 'crm_customers_created_total',
  help: 'Total customers created',
});

const contactsCreated = new client.Counter({
  name: 'crm_contacts_created_total',
  help: 'Total contacts created',
});

const interactionsCreated = new client.Counter({
  name: 'crm_interactions_created_total',
  help: 'Total interactions created',
});

// ── Middleware ───────────────────────────────────────────────
function metricsMiddleware(req, res, next) {
  const start = process.hrtime.bigint();

  res.on('finish', () => {
    const durationNs = Number(process.hrtime.bigint() - start);
    const durationS  = durationNs / 1e9;
    const route      = req.route ? req.baseUrl + req.route.path : req.path;

    httpRequestsTotal.inc({
      method:      req.method,
      route,
      status_code: res.statusCode,
    });
    httpRequestDuration.observe({ method: req.method, route }, durationS);

    if (res.statusCode >= 400) {
      httpErrors.inc({ method: req.method, status_code: res.statusCode });
    }
  });

  next();
}

module.exports = {
  metricsMiddleware,
  customersCreated,
  contactsCreated,
  interactionsCreated,
};
