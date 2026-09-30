// Toute la configuration vient des variables d'environnement : aucun secret n'est codé en dur.
const required = (name) => {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Variable d'environnement manquante : ${name}`);
  }
  return value;
};

const loadDbConfig = () => ({
  host: process.env.POSTGRES_HOST || 'db',
  port: Number(process.env.POSTGRES_PORT || 5432),
  database: required('POSTGRES_DB'),
  user: required('POSTGRES_USER'),
  password: required('POSTGRES_PASSWORD'),
});

module.exports = {
  port: Number(process.env.PORT || 3000),
  nodeEnv: process.env.NODE_ENV || 'development',
  appVersion: process.env.APP_VERSION || 'dev',
  loadDbConfig,
};
