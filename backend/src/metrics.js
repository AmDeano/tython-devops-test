const client = require('prom-client');

const register = new client.Registry();
client.collectDefaultMetrics({ register, prefix: 'tython_backend_' });

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Durée des requêtes HTTP en secondes',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.005, 0.01, 0.05, 0.1, 0.3, 0.5, 1, 2, 5],
  registers: [register],
});

const metricsMiddleware = (req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    const route = req.route ? req.baseUrl + req.route.path : 'unmatched';
    end({ method: req.method, route, status_code: res.statusCode });
  });
  next();
};

module.exports = { register, metricsMiddleware };
