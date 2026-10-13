const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

process.env.CORS_ORIGINS = 'https://biblio.example.test';
const { app } = require('../index');

let server;
let baseUrl;

before(async () => {
  server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  if (server) await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
});

test('health endpoint responds with API status', async () => {
  const response = await fetch(`${baseUrl}/`);
  assert.equal(response.status, 200);
  assert.match((await response.json()).mensaje, /API de BiblioTrack/);
});

test('database health reports when MongoDB is unavailable', async () => {
  const response = await fetch(`${baseUrl}/api/health`);
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { api: 'ok', database: 'disconnected' });
});

test('CORS preflight accepts an explicitly configured origin', async () => {
  const response = await fetch(`${baseUrl}/api/auth/login`, {
    method: 'OPTIONS',
    headers: {
      Origin: 'https://biblio.example.test',
      'Access-Control-Request-Method': 'POST',
      'Access-Control-Request-Headers': 'content-type',
    },
  });
  assert.equal(response.status, 204);
  assert.equal(response.headers.get('access-control-allow-origin'), 'https://biblio.example.test');
});

test('CORS rejects an origin outside the configured allowlist', async () => {
  const response = await fetch(`${baseUrl}/`, { headers: { Origin: 'https://attacker.example' } });
  assert.equal(response.status, 403);
  assert.equal(response.headers.get('access-control-allow-origin'), null);
});
