const config = require('./config');
const { createApp } = require('./app');
const db = require('./db');

const app = createApp();
const server = app.listen(config.port, () => {
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

// Arrêt propre (docker stop envoie SIGTERM).
const shutdown = (signal) => {
  console.log(JSON.stringify({ level: 'info', msg: `signal ${signal}, arrêt en cours` }));
  server.close(async () => {
    await db.close();
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10000).unref();
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
