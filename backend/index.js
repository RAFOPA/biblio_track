const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const crypto = require('node:crypto');
const { promisify } = require('node:util');
const path = require('node:path');
const nodemailer = require('nodemailer');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const pbkdf2 = promisify(crypto.pbkdf2);

const app = express();
const PORT = 3000;
const sessions = new Map();
const userLocks = new Map();
const resourceLocks = new Map();

app.use(cors());
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

// 1. CONEXIÓN A MONGODB (Nombre corregido: BiblioTrack)
mongoose.connect('mongodb://127.0.0.1:27017/BiblioTrack')
  .then(() => console.log('¡Conectado a la base de datos BiblioTrack exitosamente! 🚀'))
  .catch(err => console.error('Error al conectar a MongoDB:', err));

// ==========================================
// 2. DEFINICIÓN DE LOS 5 MODELOS EXACTOS
// ==========================================

// 1. Usuarios
const UsuarioSchema = new mongoose.Schema({
  carnet: { type: String, trim: true, unique: true, sparse: true },
  nombre: { type: String, required: true, trim: true },
  correo: { type: String, required: true, trim: true, lowercase: true, unique: true, sparse: true },
  rol: { type: String, default: 'Estudiante' },
  carrera: String,
  password: String,
  fotoPerfil: { type: String, default: '' },
  favoritos: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Recurso' }],
  reservasNoRetiradas: { type: Number, default: 0 },
  baneado: { type: Boolean, default: false },
});
const Usuario = mongoose.model('Usuario', UsuarioSchema);

// 2. Recursos (Actualizado para soportar tu Excel de 16k libros)
const RecursoSchema = new mongoose.Schema({
  codigoInventario: String,
  nombre: String,
  tipo: String, // "Libro" o "Computadora"
  autor: String,
  categoria: String,
  especificaciones: String,
  ubicacion: String,
  disponible: Boolean,
  // Nuevos campos adaptados al Excel:
  edicion: String,
  lugar: String,
  editorial: String,
  anio: String,
  codigosCopias: [String] // Array para guardar: ["04-000-308", "04-000-309"]
});
const Recurso = mongoose.model('Recurso', RecursoSchema);

// 3. Préstamos
const PrestamoSchema = new mongoose.Schema({
  usuarioId: { type: mongoose.Schema.Types.ObjectId, ref: 'Usuario' },
  recursoId: { type: mongoose.Schema.Types.ObjectId, ref: 'Recurso' },
  reservaId: { type: mongoose.Schema.Types.ObjectId, ref: 'Reserva' },
  qrToken: { type: String, unique: true, sparse: true },
  fechaPrestamo: Date,
  fechaDevolucionEstimada: Date,
  fechaDevolucionReal: Date,
  estado: { type: String, default: 'Pendiente' },
  plazoDias: Number,
  createdAt: { type: Date, default: Date.now }
});
const Prestamo = mongoose.model('Prestamo', PrestamoSchema);

// 4. Reservas
const ReservaSchema = new mongoose.Schema({
  usuarioId: { type: mongoose.Schema.Types.ObjectId, ref: 'Usuario' },
  recursoId: { type: mongoose.Schema.Types.ObjectId, ref: 'Recurso' },
  fechaReserva: { type: Date, default: Date.now },
  fechaExpiracion: Date,
  duracionMinutos: Number,
  estado: { type: String, default: 'Activa' }
});
const Reserva = mongoose.model('Reserva', ReservaSchema);

// 5. Notificaciones
const NotificacionSchema = new mongoose.Schema({
  usuarioId: { type: mongoose.Schema.Types.ObjectId, ref: 'Usuario' },
  titulo: String,
  mensaje: String,
  leida: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now }
});
const Notificacion = mongoose.model('Notificacion', NotificacionSchema);

const PasswordResetSchema = new mongoose.Schema({
  usuarioId: { type: mongoose.Schema.Types.ObjectId, ref: 'Usuario', required: true },
  codigoHash: { type: String, required: true },
  intentos: { type: Number, default: 0 },
  usado: { type: Boolean, default: false },
  expiraEn: { type: Date, required: true },
  createdAt: { type: Date, default: Date.now },
});
PasswordResetSchema.index({ expiraEn: 1 }, { expireAfterSeconds: 0 });
const PasswordReset = mongoose.model('PasswordReset', PasswordResetSchema);


// ==========================================
// 3. RUTAS BÁSICAS DE PRUEBA
// ==========================================

app.get('/', (req, res) => {
  res.json({ mensaje: "API de BiblioTrack funcionando al 100%" });
});

const hashPassword = async (password) => {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = await pbkdf2(password, salt, 210000, 32, 'sha256');
  return `pbkdf2$${salt}$${hash.toString('hex')}`;
};

const checkPassword = async (password, storedPassword) => {
  if (typeof storedPassword !== 'string') return false;
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
  const userId = token && sessions.get(token);
  if (!userId) return res.status(401).json({ error: 'Inicia sesión para continuar.' });
  try {
    const user = await Usuario.findById(userId);
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

const isComputer = (resource) => /comput/i.test(resource?.tipo ?? '');
const isBook = (resource) => /libro/i.test(resource?.tipo ?? '');
const resourceCapacity = (resource) => isComputer(resource)
  ? 1
  : Math.min(5, Array.isArray(resource?.codigosCopias) && resource.codigosCopias.length ? resource.codigosCopias.length : 5);

const refreshResourceAvailability = async (resourceId) => {
  const resource = await Recurso.findById(resourceId).select('tipo codigosCopias').lean();
  if (!resource) return;
  const capacity = resourceCapacity(resource);
  const now = new Date();
  const [reservations, loans] = await Promise.all([
    Reserva.countDocuments({ recursoId: resourceId, estado: 'Activa', fechaExpiracion: { $gt: now } }),
    Prestamo.countDocuments({ recursoId: resourceId, estado: 'Activo' }),
  ]);
  await Recurso.updateOne({ _id: resourceId }, { $set: { disponible: reservations + loans < capacity } });
};

const expireReservations = async () => {
  const now = new Date();
  const expired = await Reserva.find({ estado: 'Activa', fechaExpiracion: { $lte: now } }).select('_id recursoId usuarioId');
  for (const reservation of expired) {
    await withResourceLock(reservation.recursoId, async () => {
      const result = await Reserva.updateOne(
        { _id: reservation._id, estado: 'Activa', fechaExpiracion: { $lte: now } },
        { $set: { estado: 'Expirada' } },
      );
      if (!result.modifiedCount) return;
      await Prestamo.updateMany({ reservaId: reservation._id, estado: 'Pendiente' }, { $set: { estado: 'Cancelado' } });
      const user = await Usuario.findByIdAndUpdate(reservation.usuarioId, { $inc: { reservasNoRetiradas: 1 } }, { new: true });
      if (user) {
        const count = user.reservasNoRetiradas ?? 1;
        const shouldBan = count >= 3;
        if (shouldBan && !user.baneado) await Usuario.updateOne({ _id: user._id }, { $set: { baneado: true } });
        await Notificacion.create({
          usuarioId: user._id,
          titulo: shouldBan ? 'Cuenta suspendida' : 'Advertencia por reserva vencida',
          mensaje: shouldBan
            ? 'Tu cuenta fue suspendida tras 3 reservas vencidas sin recoger. Contacta al personal de biblioteca.'
            : `No recogiste una reserva dentro del plazo. Advertencia ${count} de 3: si esta situación se repite, tu cuenta será suspendida.`,
        });
        if (shouldBan) {
          for (const [token, id] of sessions.entries()) if (id === user._id.toString()) sessions.delete(token);
        }
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

    const user = await Usuario.create({
      carnet: typeof carnet === 'string' ? carnet.trim() || undefined : undefined,
      nombre: nombre.trim(),
      correo: normalizedEmail,
      carrera: typeof carrera === 'string' ? carrera.trim() : '',
      rol: rol[0].toUpperCase() + rol.slice(1).toLowerCase(),
      password: await hashPassword(password),
    });
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
    const token = crypto.randomBytes(32).toString('hex');
    sessions.set(token, user._id.toString());
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
    for (const [token, id] of sessions.entries()) if (id === user._id.toString()) sessions.delete(token);
    await Notificacion.create({ usuarioId: user._id, titulo: 'Contraseña actualizada', mensaje: 'La contraseña de tu cuenta se cambió mediante recuperación por correo.' });
    return res.json({ mensaje: 'La contraseña se restableció correctamente. Inicia sesión con la nueva contraseña.' });
  } catch (error) {
    console.error('Error al restablecer contraseña:', error);
    return res.status(500).json({ error: 'No se pudo restablecer la contraseña.' });
  }
});

app.post('/api/auth/logout', requireUser, (req, res) => {
  const token = req.headers.authorization?.replace(/^Bearer\s+/i, '');
  if (token) sessions.delete(token);
  return res.json({ mensaje: 'Sesión cerrada.' });
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
        estado: 'Activa',
        fechaExpiracion: { $gt: now },
      }).populate('recursoId', 'tipo').lean();
      const activeLoans = await Prestamo.find({ usuarioId: req.user._id, estado: 'Activo' })
        .populate('recursoId', 'tipo').lean();
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
        Reserva.countDocuments({ recursoId: resource._id, estado: 'Activa', fechaExpiracion: { $gt: now } }),
        Prestamo.countDocuments({ recursoId: resource._id, estado: 'Activo' }),
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
      estado: 'Activa',
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
        estado: 'Activa',
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
    if (loan.reservaId?.estado !== 'Activa' || !loan.reservaId.fechaExpiracion
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
      { _id: loan.reservaId, estado: 'Activa', fechaExpiracion: { $gt: start } },
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

// Obtener recursos
app.get('/api/recursos', async (req, res) => {
  try {
    const q = typeof req.query.q === 'string' ? req.query.q : '';
    const tipo = typeof req.query.tipo === 'string' ? req.query.tipo : undefined;
    const filter = {};
    if (q.trim()) {
      const escapedQuery = q.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const matcher = new RegExp(escapedQuery, 'i');
      filter.$or = ['nombre', 'autor', 'categoria', 'codigoInventario', 'editorial', 'ubicacion']
        .map((field) => ({ [field]: matcher }));
    }
    if (tipo === 'Otros') filter.tipo = { $nin: ['Libro', 'Computadora'] };
    else if (tipo && tipo !== 'Todos') filter.tipo = tipo;

    const recursos = await Recurso.find(filter).sort({ nombre: 1 }).limit(100).lean();
    const withAvailability = await Promise.all(recursos.map(async (resource) => {
      const now = new Date();
      const [reservations, loans] = await Promise.all([
        Reserva.countDocuments({ recursoId: resource._id, estado: 'Activa', fechaExpiracion: { $gt: now } }),
        Prestamo.countDocuments({ recursoId: resource._id, estado: 'Activo' }),
      ]);
      return { ...resource, disponible: reservations + loans < resourceCapacity(resource) };
    }));
    res.json(withAvailability);
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener los recursos' });
  }
});

// Guardar un nuevo recurso
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


// 4. ENCENDER EL SERVIDOR
app.listen(PORT, () => {
  console.log(`Servidor corriendo en http://localhost:${PORT}`);
});

const reservationExpiryTimer = setInterval(() => {
  expireReservations().catch((error) => console.error('Error al expirar reservaciones:', error));
}, 15_000);
reservationExpiryTimer.unref();
