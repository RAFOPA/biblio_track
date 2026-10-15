const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const crypto = require('node:crypto');
const { promisify } = require('node:util');
const path = require('node:path');
const nodemailer = require('nodemailer');
const { Usuario, Recurso, Prestamo, Reserva, Notificacion, PasswordReset, Session } = require('./models');
const adminRoutes = require('./routes/admin');
const { isComputer, resourceCapacity, withResourceAvailability } = require('./services/resource_availability');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const pbkdf2 = promisify(crypto.pbkdf2);

const app = express();
const PORT = Number(process.env.PORT || 3000);
const userLocks = new Map();
const resourceLocks = new Map();

const allowedOrigins = (process.env.CORS_ORIGINS ?? (process.env.NODE_ENV === 'production' ? '' : 'http://localhost:3000,http://127.0.0.1:3000'))
  .split(',').map((origin) => origin.trim()).filter(Boolean);
app.use(cors({
  origin(origin, callback) {
    const isLocalDevelopmentOrigin = process.env.NODE_ENV !== 'production'
      && /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin ?? '');
    if (!origin || allowedOrigins.includes(origin) || isLocalDevelopmentOrigin) {
      return callback(null, true);
    }
    return callback(new Error('Origen no permitido por la política CORS.'));
  },
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json({ limit: '3mb' }));

const smtpConfigured = Boolean(process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS);
const mailTransporter = smtpConfigured ? nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: Number(process.env.SMTP_PORT || 587),
  secure: process.env.SMTP_SECURE === 'true',
  auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
  connectionTimeout: 10_000,
  greetingTimeout: 10_000,
  socketTimeout: 15_000,
}) : null;
app.get('/', (req, res) => {
  res.json({ mensaje: "API de BiblioTrack funcionando al 100%" });
});

app.get('/api/health', (_req, res) => {
  const connected = mongoose.connection.readyState === 1;
  return res.status(connected ? 200 : 503).json({
    api: 'ok',
    database: connected ? 'connected' : 'disconnected',
  });
});

const hashPassword = async (password) => {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = await pbkdf2(password, salt, 210000, 32, 'sha256');
  return `pbkdf2$${salt}$${hash.toString('hex')}`;
};

const checkPassword = async (password, storedPassword) => {
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
};

const isValidEmail = (email) => typeof email === 'string'
  && email.length <= 254
  && /^[^\s@.][^\s@]*@(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/i.test(email);
const hashResetCode = (code) => crypto.createHash('sha256').update(code).digest('hex');
const hashSessionToken = (token) => crypto.createHash('sha256').update(token).digest('hex');

const publicUser = (user) => ({
  id: user._id,
  carnet: user.carnet,
  nombre: user.nombre,
  correo: user.correo,
  rol: user.rol,
  carrera: user.carrera,
  reservasNoRetiradas: user.reservasNoRetiradas ?? 0,
  baneado: user.baneado === true,
});

const requireUser = async (req, res, next) => {
  const token = req.headers.authorization?.replace(/^Bearer\s+/i, '');
  if (!token) return res.status(401).json({ error: 'Inicia sesión para continuar.' });
  try {
    const session = await Session.findOne({ tokenHash: hashSessionToken(token), expiraEn: { $gt: new Date() } }).lean();
    if (!session) return res.status(401).json({ error: 'La sesión ya no es válida.' });
    const user = await Usuario.findById(session.usuarioId);
    if (!user) return res.status(401).json({ error: 'La sesión ya no es válida.' });
    if (user.baneado && !['admin', 'administrador'].includes(user.rol?.toLowerCase())) {
      return res.status(403).json({ error: 'Tu cuenta está suspendida por reservas vencidas sin recoger. Contacta al personal de biblioteca.' });
    }
    req.user = user;
    next();
  } catch (error) {
    return res.status(500).json({ error: 'No se pudo validar la sesión.' });
  }
};

const requireAdmin = (req, res, next) => {
  if (!['admin', 'administrador'].includes(req.user.rol?.toLowerCase())) {
    return res.status(403).json({ error: 'Esta acción requiere una cuenta de administrador.' });
  }
  next();
};

const requireStudent = (req, res, next) => {
  if (!['estudiante', 'docente'].includes(req.user.rol?.toLowerCase())) {
    return res.status(403).json({ error: 'Esta acción requiere una cuenta de estudiante o docente.' });
  }
  next();
};

const withUserLock = async (userId, operation) => {
  const key = userId.toString();
  const previous = userLocks.get(key) ?? Promise.resolve();
  let release;
  const current = new Promise((resolve) => { release = resolve; });
  userLocks.set(key, current);
  await previous;
  try {
    return await operation();
  } finally {
    release();
    if (userLocks.get(key) === current) userLocks.delete(key);
  }
};

const withResourceLock = async (resourceId, operation) => {
  const key = resourceId.toString();
  const previous = resourceLocks.get(key) ?? Promise.resolve();
  let release;
  const current = new Promise((resolve) => { release = resolve; });
  resourceLocks.set(key, current);
  await previous;
  try { return await operation(); }
  finally {
    release();
    if (resourceLocks.get(key) === current) resourceLocks.delete(key);
  }
};

const isBook = (resource) => /libro/i.test(resource?.tipo ?? '');

const refreshResourceAvailability = async (resourceId) => {
  const db = mongoose.connection.db;
  if (!db) throw new Error('MongoDB todavía no está conectado.');
  const resource = await db.collection('recursos').findOne({ _id: resourceId });
  if (!resource) return;
  const [updated] = await withResourceAvailability([resource]);
  await db.collection('recursos').updateOne(
    { _id: resource._id },
    { $set: { disponible: updated.disponible } },
  );
};

const expireReservations = async () => {
  const now = new Date();
  const db = mongoose.connection.db;
  if (!db) return;
  const expired = await db.collection('reservas').find({
    _id: { $type: 'objectId' },
    usuarioId: { $type: 'objectId' },
    recursoId: { $type: 'objectId' },
    estado: { $in: ['Activa', 'activa'] },
    fechaExpiracion: { $lte: now },
  }).toArray();
  for (const reservation of expired) {
    await withResourceLock(reservation.recursoId, async () => {
      const result = await Reserva.updateOne(
        { _id: reservation._id, estado: { $in: ['Activa', 'activa'] }, fechaExpiracion: { $lte: now } },
        { $set: { estado: 'Expirada' } },
      );
      if (!result.modifiedCount) return;
      await Prestamo.updateMany({ reservaId: reservation._id, estado: { $in: ['Pendiente', 'pendiente'] } }, { $set: { estado: 'Cancelado' } });
      const user = await Usuario.findById(reservation.usuarioId);
      if (user && !['admin', 'administrador'].includes(user.rol?.toLowerCase())) {
        const count = (user.reservasNoRetiradas ?? 0) + 1;
        user.reservasNoRetiradas = count;
        const shouldBan = count >= 3;
        if (shouldBan) user.baneado = true;
        await Notificacion.create({
          usuarioId: user._id,
          titulo: shouldBan ? 'Cuenta suspendida' : 'Advertencia por reserva vencida',
          mensaje: shouldBan
            ? 'Tu cuenta fue suspendida tras 3 reservas vencidas sin recoger. Contacta al personal de biblioteca.'
            : `No recogiste una reserva dentro del plazo. Advertencia ${count} de 3: si esta situación se repite, tu cuenta será suspendida.`,
        });
        if (shouldBan) {
          await Session.deleteMany({ usuarioId: user._id });
        }
        await user.save();
      }
      await refreshResourceAvailability(reservation.recursoId);
    });
  }
};

app.post('/api/auth/register', async (req, res) => {
  try {
    const { carnet, nombre, correo, carrera, password } = req.body;
    const rol = typeof req.body?.rol === 'string' ? req.body.rol.trim() : 'Estudiante';
    if (typeof nombre !== 'string' || !nombre.trim()
      || typeof correo !== 'string' || !correo.trim()
      || typeof password !== 'string' || !password) {
      return res.status(400).json({ error: 'Nombre, correo y contraseña son obligatorios.' });
    }
    if (!isValidEmail(correo.trim())) {
      return res.status(400).json({ error: 'Ingresa un correo válido.' });
    }
    if (password.length < 8) {
      return res.status(400).json({ error: 'La contraseña debe tener al menos 8 caracteres.' });
    }
    if (!['estudiante', 'docente'].includes(rol.toLowerCase())) {
      return res.status(400).json({ error: 'Selecciona Estudiante o Docente. Las cuentas administrativas las habilita el personal.' });
    }

    const normalizedEmail = correo.trim().toLowerCase();
    const duplicate = await Usuario.findOne({
      $or: [
        { correo: normalizedEmail },
        ...(typeof carnet === 'string' && carnet.trim() ? [{ carnet: carnet.trim() }] : []),
      ],
    });
    if (duplicate) {
      return res.status(409).json({ error: 'Ya existe una cuenta con ese correo o carnet.' });
    }

    const normalizedCarnet = typeof carnet === 'string' ? carnet.trim() : '';
    const normalizedCareer = typeof carrera === 'string' ? carrera.trim() : '';
    const userData = {
      nombre: nombre.trim(),
      correo: normalizedEmail,
      rol: rol[0].toUpperCase() + rol.slice(1).toLowerCase(),
      password: await hashPassword(password),
    };
    if (normalizedCarnet) userData.carnet = normalizedCarnet;
    if (normalizedCareer) userData.carrera = normalizedCareer;
    const user = await Usuario.create(userData);
    return res.status(201).json({ usuario: publicUser(user) });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({ error: 'Ya existe una cuenta con ese correo o carnet.' });
    }
    console.error('Error al registrar usuario:', error);
    return res.status(500).json({ error: 'No se pudo crear la cuenta.' });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { correo, password } = req.body;
    if (typeof correo !== 'string' || !correo.trim() || typeof password !== 'string' || !password) {
      return res.status(400).json({ error: 'Ingresa tu correo y contraseña.' });
    }
    const user = await Usuario.findOne({ correo: correo.trim().toLowerCase() });
    if (!user || !(await checkPassword(password, user.password))) {
      return res.status(401).json({ error: 'Correo o contraseña incorrectos.' });
    }
    if (user.baneado && !['admin', 'administrador'].includes(user.rol?.toLowerCase())) {
      return res.status(403).json({ error: 'Tu cuenta está suspendida por reservas vencidas sin recoger. Contacta al personal de biblioteca.' });
    }
    if (!user.password.startsWith('pbkdf2$')) {
      user.password = await hashPassword(password);
      await user.save();
    }
    const token = crypto.randomBytes(32).toString('hex');
    // Each account can have one valid session at a time. A login on another
    // phone revokes the token that was previously stored for this user.
    await Session.deleteMany({ usuarioId: user._id });
    await Session.create({ usuarioId: user._id, tokenHash: hashSessionToken(token), expiraEn: new Date(Date.now() + 7 * 24 * 60 * 60_000) });
    return res.json({ usuario: publicUser(user), token });
  } catch (error) {
    console.error('Error al iniciar sesión:', error);
    return res.status(500).json({ error: 'No se pudo iniciar sesión.' });
  }
});

app.post('/api/auth/forgot-password', async (req, res) => {
  const genericMessage = 'Si el correo pertenece a una cuenta, enviaremos un código para restablecer la contraseña.';
  const correo = typeof req.body?.correo === 'string' ? req.body.correo.trim().toLowerCase() : '';
  if (!isValidEmail(correo)) return res.status(400).json({ error: 'Ingresa un correo electrónico válido.' });
  if (!mailTransporter) return res.status(503).json({ error: 'La recuperación por correo aún no está configurada. Contacta al administrador del sistema.' });
  try {
    const user = await Usuario.findOne({ correo });
    if (!user) return res.json({ mensaje: genericMessage });
    const recent = await PasswordReset.exists({ usuarioId: user._id, usado: false, createdAt: { $gt: new Date(Date.now() - 60_000) } });
    if (recent) return res.json({ mensaje: genericMessage });

    await PasswordReset.updateMany({ usuarioId: user._id, usado: false }, { $set: { usado: true } });
    const code = crypto.randomInt(0, 100_000_000).toString().padStart(8, '0');
    await PasswordReset.create({ usuarioId: user._id, codigoHash: hashResetCode(code), expiraEn: new Date(Date.now() + 15 * 60_000) });
    try {
      await mailTransporter.sendMail({
        from: process.env.MAIL_FROM || process.env.SMTP_USER,
        to: user.correo,
        subject: 'Código para cambiar tu contraseña de BiblioTrack',
        text: `Hola ${user.nombre},\n\nTu código para restablecer la contraseña es: ${code}\n\nVence en 15 minutos. Si no solicitaste este cambio, puedes ignorar este correo.`,
      });
    } catch (mailError) {
      await PasswordReset.updateMany({ usuarioId: user._id, usado: false }, { $set: { usado: true } });
      console.error('No se pudo enviar el correo de recuperación:', mailError.message);
      return res.status(503).json({ error: 'No se pudo enviar el correo. Revisa la configuración del servidor e inténtalo de nuevo.' });
    }
    return res.json({ mensaje: genericMessage });
  } catch (error) {
    console.error('Error al solicitar recuperación:', error);
    return res.status(500).json({ error: 'No se pudo procesar la solicitud de recuperación.' });
  }
});

app.post('/api/auth/reset-password', async (req, res) => {
  const correo = typeof req.body?.correo === 'string' ? req.body.correo.trim().toLowerCase() : '';
  const codigo = typeof req.body?.codigo === 'string' ? req.body.codigo.trim() : '';
  const newPassword = req.body?.newPassword;
  if (!isValidEmail(correo) || !/^\d{8}$/.test(codigo) || typeof newPassword !== 'string') {
    return res.status(400).json({ error: 'Ingresa el correo, el código de 8 dígitos y una contraseña nueva.' });
  }
  if (newPassword.length < 8) return res.status(400).json({ error: 'La nueva contraseña debe tener al menos 8 caracteres.' });
  try {
    const user = await Usuario.findOne({ correo });
    if (!user) return res.status(400).json({ error: 'El código no es válido o ya venció.' });
    const reset = await PasswordReset.findOne({ usuarioId: user._id, usado: false, expiraEn: { $gt: new Date() } }).sort({ createdAt: -1 });
    if (!reset) return res.status(400).json({ error: 'El código no es válido o ya venció.' });
    const actualHash = Buffer.from(reset.codigoHash, 'hex');
    const submittedHash = Buffer.from(hashResetCode(codigo), 'hex');
    if (!crypto.timingSafeEqual(actualHash, submittedHash)) {
      reset.intentos += 1;
      if (reset.intentos >= 5) reset.usado = true;
      await reset.save();
      return res.status(400).json({ error: reset.usado ? 'Se agotaron los intentos. Solicita un código nuevo.' : 'El código no es correcto.' });
    }
    reset.usado = true;
    await reset.save();
    user.password = await hashPassword(newPassword);
    await user.save();
    await PasswordReset.deleteMany({ usuarioId: user._id });
    await Session.deleteMany({ usuarioId: user._id });
    await Notificacion.create({ usuarioId: user._id, titulo: 'Contraseña actualizada', mensaje: 'La contraseña de tu cuenta se cambió mediante recuperación por correo.' });
    return res.json({ mensaje: 'La contraseña se restableció correctamente. Inicia sesión con la nueva contraseña.' });
  } catch (error) {
    console.error('Error al restablecer contraseña:', error);
    return res.status(500).json({ error: 'No se pudo restablecer la contraseña.' });
  }
});

app.post('/api/auth/logout', requireUser, (req, res) => {
  const token = req.headers.authorization?.replace(/^Bearer\s+/i, '');
  return Session.deleteOne({ tokenHash: hashSessionToken(token || '') })
    .then(() => res.json({ mensaje: 'Sesión cerrada.' }))
    .catch(() => res.status(500).json({ error: 'No se pudo cerrar la sesión.' }));
});

app.get('/api/users/me', requireUser, (req, res) => {
  return res.json({ usuario: { ...publicUser(req.user), fotoPerfil: req.user.fotoPerfil || '' } });
});

app.put('/api/users/me/photo', requireUser, async (req, res) => {
  const photo = req.body?.fotoPerfil;
  if (typeof photo !== 'string' || !photo.startsWith('data:image/') || photo.length > 2_800_000) {
    return res.status(400).json({ error: 'La foto debe ser una imagen válida de máximo 2 MB.' });
  }
  req.user.fotoPerfil = photo;
  await req.user.save();
  return res.json({ fotoPerfil: req.user.fotoPerfil });
});

app.post('/api/auth/password', requireUser, async (req, res) => {
  const { currentPassword, newPassword } = req.body ?? {};
  if (typeof currentPassword !== 'string' || typeof newPassword !== 'string') {
    return res.status(400).json({ error: 'Completa tu contraseña actual y la nueva.' });
  }
  if (newPassword.length < 8) return res.status(400).json({ error: 'La nueva contraseña debe tener al menos 8 caracteres.' });
  if (!(await checkPassword(currentPassword, req.user.password))) {
    return res.status(401).json({ error: 'La contraseña actual no es correcta.' });
  }
  req.user.password = await hashPassword(newPassword);
  await req.user.save();
  return res.json({ mensaje: 'La contraseña se actualizó correctamente.' });
});

app.use('/api/admin', adminRoutes({ requireUser, requireAdmin }));

app.get('/api/favoritos/mios', requireUser, requireStudent, async (req, res) => {
  const user = await Usuario.findById(req.user._id).populate('favoritos').select('favoritos').lean();
  return res.json(user?.favoritos ?? []);
});

app.post('/api/favoritos/:recursoId', requireUser, requireStudent, async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.recursoId)) return res.status(400).json({ error: 'Recurso inválido.' });
  const resource = await Recurso.findById(req.params.recursoId).select('tipo').lean();
  if (!resource) return res.status(404).json({ error: 'No se encontró el recurso.' });
  if (!isBook(resource)) return res.status(400).json({ error: 'Solo puedes guardar libros como favoritos.' });
  return await withUserLock(req.user._id, async () => {
    const current = await Usuario.findById(req.user._id).select('favoritos');
    if (current.favoritos.some((id) => id.toString() === req.params.recursoId)) return res.json({ mensaje: 'El libro ya está en favoritos.' });
    if (current.favoritos.length >= 10) return res.status(409).json({ error: 'Puedes guardar hasta 10 libros favoritos.' });
    current.favoritos.push(resource._id);
    await current.save();
    return res.status(201).json({ mensaje: 'Libro agregado a favoritos.' });
  });
});

app.delete('/api/favoritos/:recursoId', requireUser, requireStudent, async (req, res) => {
  await Usuario.updateOne({ _id: req.user._id }, { $pull: { favoritos: req.params.recursoId } });
  return res.json({ mensaje: 'Se quitó de favoritos.' });
});

app.get('/api/notificaciones/mias', requireUser, async (req, res) => {
  const notifications = await Notificacion.find({ usuarioId: req.user._id }).sort({ createdAt: -1 }).lean();
  return res.json(notifications);
});

app.delete('/api/notificaciones/mias/:id', requireUser, async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ error: 'Notificación inválida.' });
  const result = await Notificacion.deleteOne({ _id: req.params.id, usuarioId: req.user._id });
  if (!result.deletedCount) return res.status(404).json({ error: 'No se encontró la notificación.' });
  return res.json({ mensaje: 'Notificación eliminada.' });
});

app.post('/api/recursos/:id/reservas', requireUser, requireStudent, async (req, res) => {
  try {
    await expireReservations();
    const duracionMinutos = Number(req.body.duracionMinutos);
    if (![30, 60].includes(duracionMinutos)) {
      return res.status(400).json({ error: 'Elige una reserva de 30 o 60 minutos.' });
    }
    const resource = await Recurso.findById(req.params.id).lean();
    if (!resource) return res.status(404).json({ error: 'No se encontró el recurso.' });

    const reservation = await withUserLock(req.user._id, async () => withResourceLock(resource._id, async () => {
      const now = new Date();
      const activeReservations = await Reserva.find({
        usuarioId: req.user._id,
        estado: { $in: ['Activa', 'activa'] },
        fechaExpiracion: { $gt: now },
      }).populate('recursoId', 'tipo').lean();
      const activeLoans = await Prestamo.find({ usuarioId: req.user._id, estado: { $in: ['Activo', 'activo'] } })
        .populate('recursoId', 'tipo').lean();
      const alreadyHoldsResource = [...activeReservations, ...activeLoans].some((item) =>
        item.recursoId?._id?.toString() === resource._id.toString(),
      );
      if (alreadyHoldsResource) {
        const error = new Error('Ya tienes una reserva o préstamo activo de este recurso.');
        error.status = 409;
        throw error;
      }
      const heldResources = [...activeReservations, ...activeLoans].map((item) => item.recursoId).filter(Boolean);
      const heldOfSameType = heldResources.filter((item) => isComputer(item) === isComputer(resource)).length;
      const maxAllowed = isComputer(resource) ? 1 : 5;
      if (heldOfSameType >= maxAllowed) {
        const label = isComputer(resource) ? 'una computadora' : 'cinco libros o recursos';
        const error = new Error(`Solo puedes tener ${label} reservados o prestados al mismo tiempo.`);
        error.status = 409;
        throw error;
      }

      const capacity = resourceCapacity(resource);
      const [occupiedReservations, occupiedLoans] = await Promise.all([
        Reserva.countDocuments({ recursoId: resource._id, estado: { $in: ['Activa', 'activa'] }, fechaExpiracion: { $gt: now } }),
        Prestamo.countDocuments({ recursoId: resource._id, estado: { $in: ['Activo', 'activo'] } }),
      ]);
      if (occupiedReservations + occupiedLoans >= capacity) {
        const error = new Error(isComputer(resource)
          ? 'Esta computadora ya está reservada o prestada.'
          : 'Este recurso alcanzó su límite de reservas o préstamos disponibles.');
        error.status = 409;
        throw error;
      }
      try {
        const created = await Reserva.create({
          usuarioId: req.user._id,
          recursoId: resource._id,
          fechaReserva: now,
          fechaExpiracion: new Date(now.getTime() + duracionMinutos * 60_000),
          duracionMinutos,
          estado: 'Activa',
        });
        await refreshResourceAvailability(resource._id);
        await Notificacion.create({
          usuarioId: req.user._id,
          titulo: 'Reserva creada',
          mensaje: `Reservaste “${resource.nombre || 'un recurso'}”. Tienes ${duracionMinutos} minutos para recogerlo.`,
        });
        return created;
      } catch (error) {
        throw error;
      }
    }));

    const populated = await Reserva.findById(reservation._id).populate('recursoId').lean();
    return res.status(201).json({ reserva: populated });
  } catch (error) {
    console.error('Error al reservar recurso:', error);
    return res.status(error.status ?? 500).json({ error: error.message || 'No se pudo reservar el recurso.' });
  }
});

app.get('/api/reservas/mias', requireUser, requireStudent, async (req, res) => {
  try {
    await expireReservations();
    const reservations = await Reserva.find({
      usuarioId: req.user._id,
      estado: { $in: ['Activa', 'activa'] },
      fechaExpiracion: { $gt: new Date() },
    }).populate('recursoId').sort({ fechaExpiracion: 1 }).lean();
    return res.json(reservations);
  } catch (error) {
    return res.status(500).json({ error: 'No se pudieron cargar tus reservas.' });
  }
});

app.post('/api/prestamos/pendientes', requireUser, requireStudent, async (req, res) => {
  try {
    await expireReservations();
    const reservaId = req.body.reservaId;
    if (!mongoose.isValidObjectId(reservaId)) {
      return res.status(400).json({ error: 'Selecciona una reserva válida.' });
    }
    const result = await withUserLock(req.user._id, async () => {
      const reservation = await Reserva.findOne({
        _id: reservaId,
        usuarioId: req.user._id,
        estado: { $in: ['Activa', 'activa'] },
        fechaExpiracion: { $gt: new Date() },
      });
      if (!reservation) {
        const error = new Error('La reserva ya venció o no pertenece a tu cuenta.');
        error.status = 409;
        throw error;
      }
      let loan = await Prestamo.findOne({ reservaId: reservation._id, estado: 'Pendiente' });
      if (!loan) {
        loan = await Prestamo.create({
          usuarioId: req.user._id,
          recursoId: reservation.recursoId,
          reservaId: reservation._id,
          qrToken: crypto.randomBytes(32).toString('hex'),
          estado: 'Pendiente',
        });
      }
      return loan;
    });
    const loan = await Prestamo.findById(result._id).populate('recursoId').lean();
    return res.status(201).json({ prestamo: loan, qr: `BIBLIOTRACK:${loan.qrToken}` });
  } catch (error) {
    return res.status(error.status ?? 500).json({ error: error.message || 'No se pudo preparar el préstamo.' });
  }
});

app.get('/api/prestamos/mios', requireUser, requireStudent, async (req, res) => {
  try {
    const loans = await Prestamo.find({ usuarioId: req.user._id })
      .populate('recursoId').populate('reservaId').sort({ createdAt: -1 }).lean();
    return res.json(loans);
  } catch (error) {
    return res.status(500).json({ error: 'No se pudieron cargar tus préstamos.' });
  }
});

app.get('/api/admin/prestamos/qr/:token', requireUser, requireAdmin, async (req, res) => {
  try {
    await expireReservations();
    const loan = await Prestamo.findOne({ qrToken: req.params.token, estado: 'Pendiente' })
      .populate('usuarioId', 'carnet nombre correo carrera')
      .populate('recursoId')
      .populate('reservaId')
      .lean();
    if (!loan) return res.status(404).json({ error: 'QR inválido o el préstamo ya fue procesado.' });
    if (!['Activa', 'activa'].includes(loan.reservaId?.estado) || !loan.reservaId.fechaExpiracion
      || new Date(loan.reservaId.fechaExpiracion) <= new Date()) {
      return res.status(409).json({ error: 'La reservación asociada venció; solicita al estudiante una reserva nueva.' });
    }
    return res.json({ prestamo: loan });
  } catch (error) {
    return res.status(500).json({ error: 'No se pudo consultar el préstamo.' });
  }
});

app.post('/api/admin/prestamos/:id/confirmar', requireUser, requireAdmin, async (req, res) => {
  try {
    const plazoDias = Number(req.body.plazoDias);
    if (![1, 3, 7, 14].includes(plazoDias)) {
      return res.status(400).json({ error: 'Selecciona un plazo válido de préstamo.' });
    }
    await expireReservations();
    const loan = await Prestamo.findOne({ _id: req.params.id, estado: 'Pendiente' });
    if (!loan) return res.status(404).json({ error: 'El préstamo ya fue procesado o no existe.' });
    return await withResourceLock(loan.recursoId, async () => {
    const start = new Date();
    const reservation = await Reserva.updateOne(
      { _id: loan.reservaId, estado: { $in: ['Activa', 'activa'] }, fechaExpiracion: { $gt: start } },
      { $set: { estado: 'Prestada' } },
    );
    if (!reservation.modifiedCount) {
      return res.status(409).json({ error: 'La reservación venció antes de confirmar el préstamo.' });
    }
    const confirmed = await Prestamo.findOneAndUpdate(
      { _id: loan._id, estado: 'Pendiente' },
      {
        $set: {
          estado: 'Activo',
          fechaPrestamo: start,
          fechaDevolucionEstimada: new Date(start.getTime() + plazoDias * 24 * 60 * 60_000),
          plazoDias,
        },
      },
      { new: true },
    );
    if (!confirmed) {
      await Reserva.updateOne({ _id: loan.reservaId, estado: 'Prestada' }, { $set: { estado: 'Activa' } });
      return res.status(409).json({ error: 'El préstamo ya fue procesado por otro administrador.' });
    }
    const populated = await Prestamo.findById(confirmed._id).populate('recursoId').populate('usuarioId', 'nombre carnet').lean();
    await refreshResourceAvailability(loan.recursoId);
    await Notificacion.create({
      usuarioId: loan.usuarioId,
      titulo: 'Préstamo confirmado',
      mensaje: `El personal confirmó el préstamo de “${populated.recursoId?.nombre || 'tu recurso'}” por ${plazoDias} días.`,
    });
    return res.json({ prestamo: populated });
    });
  } catch (error) {
    return res.status(error.status ?? 500).json({ error: error.message || 'No se pudo confirmar el préstamo.' });
  }
});

app.get('/api/recursos', async (req, res) => {
  try {
    const q = typeof req.query.q === 'string' ? req.query.q : '';
    const tipo = typeof req.query.tipo === 'string' ? req.query.tipo : undefined;
    const requestedPage = Number.parseInt(req.query.page, 10);
    const requestedLimit = Number.parseInt(req.query.limit, 10);
    const page = Number.isInteger(requestedPage) && requestedPage > 0 ? requestedPage : 1;
    const limit = Number.isInteger(requestedLimit) && requestedLimit > 0
      ? Math.min(requestedLimit, 100)
      : 100;
    const filter = {};
    if (q.trim()) {
      const escapedQuery = q.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const matcher = new RegExp(escapedQuery, 'i');
      filter.$or = ['nombre', 'autor', 'categoria', 'codigoInventario', 'editorial', 'ubicacion']
        .map((field) => ({ [field]: matcher }));
    }
    const typePattern = {
      Libro: /^libros?$/i,
      Computadora: /^computadoras?$/i,
      Equipo: /^equipos?$/i,
      Otro: /^otros?$/i,
    }[tipo];
    if (typePattern) filter.tipo = typePattern;

    filter.activo = { $ne: false };
    const db = mongoose.connection.db;
    if (!db) return res.status(503).json({ error: 'La base de datos no está conectada.' });
    const collection = db.collection('recursos');
    const total = await collection.countDocuments(filter);
    const recursos = await Recurso.aggregate([
      { $match: filter },
      { $sort: { nombre: 1, _id: 1 } },
      { $skip: (page - 1) * limit },
      { $limit: limit },
    ]).exec();
    const withAvailability = await withResourceAvailability(recursos);
    res.set('X-Total-Count', String(total));
    res.set('X-Page', String(page));
    res.set('X-Has-More', String(page * limit < total));
    return res.json(withAvailability);
  } catch (error) {
    console.error('Error al obtener los recursos:', error);
    res.status(500).json({ error: 'Error al obtener los recursos' });
  }
});

app.post('/api/recursos', requireUser, requireAdmin, async (req, res) => {
  try {
    const { nombre, tipo } = req.body ?? {};
    if (typeof nombre !== 'string' || !nombre.trim() || typeof tipo !== 'string' || !tipo.trim()) {
      return res.status(400).json({ error: 'El nombre y tipo del recurso son obligatorios.' });
    }
    const nuevoRecurso = new Recurso({ ...req.body, nombre: nombre.trim(), tipo: tipo.trim() });
    await nuevoRecurso.save();
    res.status(201).json(nuevoRecurso);
  } catch (error) {
    res.status(400).json({ mensaje: 'Error al guardar el recurso', error });
  }
});

app.use((error, req, res, next) => {
  if (error.message === 'Origen no permitido por la política CORS.') {
    return res.status(403).json({ error: error.message });
  }
  return next(error);
});

async function startServer() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/BiblioTrack');
  console.log('Conectado a MongoDB.');
  const server = await new Promise((resolve, reject) => {
    const instance = app.listen(PORT, '0.0.0.0', () => resolve(instance));
    instance.once('error', reject);
  });
  console.log(`Servidor corriendo en el puerto ${PORT}.`);
  const reservationExpiryTimer = setInterval(() => {
    expireReservations().catch((error) => console.error('Error al expirar reservaciones:', error));
  }, 15_000);
  reservationExpiryTimer.unref();
  return server;
}

if (require.main === module) {
  startServer().catch((error) => {
    console.error('No se pudo iniciar el backend:', error.message);
    process.exitCode = 1;
  });
}

module.exports = { app, startServer };
