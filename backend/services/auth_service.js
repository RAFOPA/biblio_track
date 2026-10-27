const crypto = require('node:crypto');
const { promisify } = require('node:util');

const pbkdf2 = promisify(crypto.pbkdf2);
const SESSION_DURATION_MS = 7 * 24 * 60 * 60_000;
const DEVELOPMENT_SECRET = 'bibliotrack-local-development-secret-change-before-production';

function getJwtSecret() {
  const secret = process.env.JWT_SECRET
    || (process.env.NODE_ENV === 'production' ? '' : DEVELOPMENT_SECRET);
  if (!secret || Buffer.byteLength(secret) < 32) {
    throw new Error('JWT_SECRET debe tener al menos 32 bytes y configurarse en producción.');
  }
  return secret;
}

const base64url = (value) => Buffer.from(value).toString('base64url');
const hashSessionToken = (token) => crypto.createHash('sha256').update(token).digest('hex');

async function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = await pbkdf2(password, salt, 210000, 32, 'sha256');
  return `pbkdf2$${salt}$${hash.toString('hex')}`;
}

async function checkPassword(password, storedPassword) {
  if (typeof storedPassword !== 'string') return false;
  if (!storedPassword.startsWith('pbkdf2$')) {
    const expected = Buffer.from(storedPassword);
    const actual = Buffer.from(password);
    return expected.length === actual.length && crypto.timingSafeEqual(expected, actual);
  }
  const [algorithm, salt, storedHash] = storedPassword.split('$');
  if (algorithm !== 'pbkdf2' || !salt || !storedHash) return false;
  const expected = Buffer.from(storedHash, 'hex');
  const actual = await pbkdf2(password, salt, 210000, expected.length, 'sha256');
  return expected.length === actual.length && crypto.timingSafeEqual(expected, actual);
}

function createAccessToken(user, now = Math.floor(Date.now() / 1000)) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const payload = {
    sub: user._id.toString(),
    role: user.rol,
    iat: now,
    exp: now + SESSION_DURATION_MS / 1000,
    jti: crypto.randomUUID(),
  };
  const unsigned = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
  const signature = crypto.createHmac('sha256', getJwtSecret()).update(unsigned).digest('base64url');
  return `${unsigned}.${signature}`;
}

function verifyAccessToken(token, now = Math.floor(Date.now() / 1000)) {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  try {
    const [encodedHeader, encodedPayload, suppliedSignature] = parts;
    const header = JSON.parse(Buffer.from(encodedHeader, 'base64url').toString('utf8'));
    const payload = JSON.parse(Buffer.from(encodedPayload, 'base64url').toString('utf8'));
    if (header.alg !== 'HS256' || header.typ !== 'JWT') return null;
    const unsigned = `${encodedHeader}.${encodedPayload}`;
    const expected = crypto.createHmac('sha256', getJwtSecret()).update(unsigned).digest();
    const actual = Buffer.from(suppliedSignature, 'base64url');
    if (actual.length !== expected.length || !crypto.timingSafeEqual(actual, expected)) return null;
    if (typeof payload.sub !== 'string' || typeof payload.exp !== 'number' || payload.exp <= now) return null;
    return payload;
  } catch (_) {
    return null;
  }
}

module.exports = {
  SESSION_DURATION_MS,
  checkPassword,
  createAccessToken,
  getJwtSecret,
  hashPassword,
  hashSessionToken,
  verifyAccessToken,
};
