const mongoose = require('mongoose');

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
  infraccionesPrestamo: { type: Number, default: 0 },
  baneado: { type: Boolean, default: false },
});
const Usuario = mongoose.model('Usuario', UsuarioSchema, 'usuarios');

const RecursoSchema = new mongoose.Schema({
  codigoInventario: String, nombre: String, tipo: String, autor: String,
  categoria: String, especificaciones: String, ubicacion: String,
  disponible: Boolean, edicion: String, lugar: String, editorial: String,
  anio: String, codigosCopias: [String], activo: { type: Boolean, default: true },
});
const Recurso = mongoose.model('Recurso', RecursoSchema, 'recursos');

const PrestamoSchema = new mongoose.Schema({
  usuarioId: { type: mongoose.Schema.Types.ObjectId, ref: 'Usuario', required: true },
  recursoId: { type: mongoose.Schema.Types.ObjectId, ref: 'Recurso', required: true },
  reservaId: { type: mongoose.Schema.Types.ObjectId, ref: 'Reserva' },
  qrToken: { type: String, unique: true, sparse: true }, fechaPrestamo: Date,
  fechaDevolucionEstimada: Date, fechaDevolucionReal: Date,
  estado: { type: String, default: 'Pendiente' }, plazoDias: Number,
  plazoUnidad: { type: String, enum: ['horas', 'dias'] }, plazoValor: Number,
  plazoMinutos: Number, avisoVencimientoEn: Date, infraccionAplicadaEn: Date,
  createdAt: { type: Date, default: Date.now },
});
PrestamoSchema.index({ estado: 1, fechaDevolucionEstimada: 1 });
const Prestamo = mongoose.model('Prestamo', PrestamoSchema, 'prestamos');

const ReservaSchema = new mongoose.Schema({
  usuarioId: { type: mongoose.Schema.Types.ObjectId, ref: 'Usuario' },
  recursoId: { type: mongoose.Schema.Types.ObjectId, ref: 'Recurso' },
  fechaReserva: { type: Date, default: Date.now }, fechaExpiracion: Date,
  duracionMinutos: Number, estado: { type: String, default: 'Activa' },
});
const Reserva = mongoose.model('Reserva', ReservaSchema, 'reservas');

const NotificacionSchema = new mongoose.Schema({
  usuarioId: { type: mongoose.Schema.Types.ObjectId, ref: 'Usuario' },
  titulo: String, mensaje: String, leida: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now },
});
const Notificacion = mongoose.model('Notificacion', NotificacionSchema, 'notificaciones');

const PasswordResetSchema = new mongoose.Schema({
  usuarioId: { type: mongoose.Schema.Types.ObjectId, ref: 'Usuario', required: true },
  codigoHash: { type: String, required: true }, intentos: { type: Number, default: 0 },
  usado: { type: Boolean, default: false }, expiraEn: { type: Date, required: true },
  createdAt: { type: Date, default: Date.now },
});
PasswordResetSchema.index({ expiraEn: 1 }, { expireAfterSeconds: 0 });
const PasswordReset = mongoose.model('PasswordReset', PasswordResetSchema, 'passwordresets');

const SessionSchema = new mongoose.Schema({
  usuarioId: { type: mongoose.Schema.Types.ObjectId, ref: 'Usuario', required: true },
  tokenHash: { type: String, required: true, unique: true },
  expiraEn: { type: Date, required: true },
  createdAt: { type: Date, default: Date.now },
});
SessionSchema.index({ expiraEn: 1 }, { expireAfterSeconds: 0 });
const Session = mongoose.model('Session', SessionSchema, 'sessions');

module.exports = { Usuario, Recurso, Prestamo, Reserva, Notificacion, PasswordReset, Session };
