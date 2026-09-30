const config = require('./config');
const { createApp } = require('./app');
const db = require('./db');

const app = createApp();
const server = app.listen(config.port, () => {
  // logs b json bach ysahal n9lbo fihom mn b3d
  console.log(
    JSON.stringify({
      level: 'info',
      msg: 'backend démarré',
      port: config.port,
      env: config.nodeEnv,
      version: config.appVersion,
    }),
  );
});

// docker stop kaysift SIGTERM : kansaliw les requetes li khdamin w nsdo pool 3ad nkhrjo
const shutdown = (signal) => {
  console.log(JSON.stringify({ level: 'info', msg: `signal ${signal}, arrêt en cours` }));
  server.close(async () => {
    await db.close();
    process.exit(0);
  });
  // ila tbloqa chi 7aja, n9t3o mn b3d 10s
  setTimeout(() => process.exit(1), 10000).unref();
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
