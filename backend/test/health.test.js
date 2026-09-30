const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('../src/app');

// Faux pool PostgreSQL : les tests ne dépendent pas d'une vraie base.
const fakeDb = {
  healthy: true,
  async query(sql) {
    if (!this.healthy) throw new Error('db down');
    if (sql.startsWith('SELECT 1')) return { rows: [{ '?column?': 1 }] };
    if (sql.startsWith('SELECT')) return { rows: [{ id: 1, content: 'hello', created_at: 'now' }] };
    return { rows: [{ id: 2, content: 'new', created_at: 'now' }] };
  },
};

let server;
let baseUrl;

before(async () => {
  server = createApp({ db: fakeDb }).listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(() => server.close());

test('GET /health renvoie 200 et status ok', async () => {
  const res = await fetch(`${baseUrl}/health`);
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.status, 'ok');
});

test('GET /health/ready renvoie 503 si la base est indisponible', async () => {
  fakeDb.healthy = false;
  const res = await fetch(`${baseUrl}/health/ready`);
  fakeDb.healthy = true;
  assert.equal(res.status, 503);
});

test('GET /health ajoute les headers de sécurité (helmet)', async () => {
  const res = await fetch(`${baseUrl}/health`);
  assert.equal(res.headers.get('x-content-type-options'), 'nosniff');
  assert.equal(res.headers.get('x-powered-by'), null);
});

test('POST /api/messages valide le contenu', async () => {
  const res = await fetch(`${baseUrl}/api/messages`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ content: '' }),
  });
  assert.equal(res.status, 400);
});

test('POST /api/messages crée un message', async () => {
  const res = await fetch(`${baseUrl}/api/messages`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ content: 'new' }),
  });
  assert.equal(res.status, 201);
  assert.equal((await res.json()).content, 'new');
});

test('GET /metrics expose les métriques Prometheus', async () => {
  const res = await fetch(`${baseUrl}/metrics`);
  assert.equal(res.status, 200);
  assert.match(await res.text(), /http_request_duration_seconds/);
});
