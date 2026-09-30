const express = require('express');
const helmet = require('helmet');
const config = require('./config');
const { register, metricsMiddleware } = require('./metrics');

// db kandkhloha mn bra bach f tests n3tiw fake db (ma n7tajoch postgres)
const createApp = ({ db } = {}) => {
  const getPool = db ? () => db : require('./db').getPool;
  const app = express();

  app.disable('x-powered-by');
  app.set('trust proxy', 1); // 7na mor nginx
  app.use(helmet());
  app.use(express.json({ limit: '100kb' }));
  app.use(metricsMiddleware);

  // liveness : l process 7ay w kayjawb
  app.get('/health', (req, res) => {
    res.json({ status: 'ok', version: config.appVersion, uptime: process.uptime() });
  });

  // readiness : wach db kat3awd
  app.get('/health/ready', async (req, res) => {
    try {
      await getPool().query('SELECT 1');
      res.json({ status: 'ok', database: 'up' });
    } catch {
      res.status(503).json({ status: 'error', database: 'down' });
    }
  });

  // prometheus kayscrapi hna (ma khasoch ykon public, nginx kaybloquih)
  app.get('/metrics', async (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  });

  app.get('/api/messages', async (req, res, next) => {
    try {
      const { rows } = await getPool().query(
        'SELECT id, content, created_at FROM messages ORDER BY id DESC LIMIT 50',
      );
      res.json(rows);
    } catch (err) {
      next(err);
    }
  });

  app.post('/api/messages', async (req, res, next) => {
    const content = typeof req.body?.content === 'string' ? req.body.content.trim() : '';
    if (!content || content.length > 280) {
      return res.status(400).json({ error: 'content requis (1 à 280 caractères)' });
    }
    try {
      // query parametrée => ma kaynch sql injection
      const { rows } = await getPool().query(
        'INSERT INTO messages (content) VALUES ($1) RETURNING id, content, created_at',
        [content],
      );
      return res.status(201).json(rows[0]);
    } catch (err) {
      return next(err);
    }
  });

  app.use((req, res) => res.status(404).json({ error: 'Not found' }));

  // ma nrj3och l stack trace l client, kanloggiwha 7na
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    console.error(JSON.stringify({ level: 'error', msg: err.message, path: req.path }));
    res.status(500).json({ error: 'Internal server error' });
  });

  return app;
};

module.exports = { createApp };
