const assert = require('node:assert/strict');
const express = require('express');
const { after, before, test } = require('node:test');
const adminRoutes = require('../routes/admin');

const app = express();
app.use(express.json());
app.use('/api/admin', adminRoutes({
  requireUser: (_req, _res, next) => next(),
  requireAdmin: (_req, _res, next) => next(),
}));

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

test('user profile edit rejects an invalid email before database access', async () => {
  const response = await fetch(`${baseUrl}/api/admin/usuarios/507f1f77bcf86cd799439011`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ nombre: 'Ana', correo: 'correo-invalido' }),
  });
  assert.equal(response.status, 400);
  assert.match((await response.json()).error, /correo/i);
});

test('user profile edit rejects an empty name before database access', async () => {
  const response = await fetch(`${baseUrl}/api/admin/usuarios/507f1f77bcf86cd799439011`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ nombre: '   ', correo: 'ana@example.test' }),
  });
  assert.equal(response.status, 400);
  assert.match((await response.json()).error, /nombre/i);
});
