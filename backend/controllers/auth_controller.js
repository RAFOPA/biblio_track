const { Usuario, Session } = require('../models');
const {
  SESSION_DURATION_MS,
  checkPassword,
  createAccessToken,
  hashPassword,
  hashSessionToken,
} = require('../services/auth_service');

const isValidEmail = (email) => typeof email === 'string'
  && email.length <= 254
  && /^[^\s@.][^\s@]*@(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/i.test(email);

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

async function register(req, res) {
  try {
    const { carnet, nombre, correo, carrera, password } = req.body;
    const rol = typeof req.body?.rol === 'string' ? req.body.rol.trim() : 'Estudiante';
    if (typeof nombre !== 'string' || !nombre.trim()
      || typeof correo !== 'string' || !correo.trim()
      || typeof password !== 'string' || !password) {
      return res.status(400).json({ error: 'Nombre, correo y contraseña son obligatorios.' });
    }
    if (!isValidEmail(correo.trim())) return res.status(400).json({ error: 'Ingresa un correo válido.' });
    if (password.length < 8) return res.status(400).json({ error: 'La contraseña debe tener al menos 8 caracteres.' });
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
    if (duplicate) return res.status(409).json({ error: 'Ya existe una cuenta con ese correo o carnet.' });

    const userData = {
      nombre: nombre.trim(),
      correo: normalizedEmail,
      rol: rol[0].toUpperCase() + rol.slice(1).toLowerCase(),
      password: await hashPassword(password),
    };
    if (typeof carnet === 'string' && carnet.trim()) userData.carnet = carnet.trim();
    if (typeof carrera === 'string' && carrera.trim()) userData.carrera = carrera.trim();
    const user = await Usuario.create(userData);
    return res.status(201).json({ usuario: publicUser(user) });
  } catch (error) {
    if (error.code === 11000) return res.status(409).json({ error: 'Ya existe una cuenta con ese correo o carnet.' });
    console.error('Error al registrar usuario:', error);
    return res.status(500).json({ error: 'No se pudo crear la cuenta.' });
  }
}

async function login(req, res) {
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

    const token = createAccessToken(user);
    const expiresAt = new Date(Date.now() + SESSION_DURATION_MS);
    await Session.deleteMany({ usuarioId: user._id });
    await Session.create({ usuarioId: user._id, tokenHash: hashSessionToken(token), expiraEn: expiresAt });
    return res.json({ usuario: publicUser(user), token, tokenType: 'Bearer', expiresAt: expiresAt.toISOString() });
  } catch (error) {
    console.error('Error al iniciar sesión:', error);
    return res.status(500).json({ error: 'No se pudo iniciar sesión.' });
  }
}

module.exports = { login, publicUser, register };
