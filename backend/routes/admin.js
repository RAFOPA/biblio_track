const express = require('express');
const mongoose = require('mongoose');
const { Usuario, Recurso, Reserva, Prestamo } = require('../models');
const { getUsageReport } = require('../services/report_service');
const { withResourceAvailability } = require('../services/resource_availability');

const fields = ['nombre', 'tipo', 'codigoInventario', 'autor', 'categoria', 'especificaciones', 'ubicacion', 'edicion', 'lugar', 'editorial', 'anio', 'codigosCopias'];
const router = express.Router();
const escapeRegex = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const paging = (query) => {
  const page = Math.max(1, Number.parseInt(query.page, 10) || 1);
  const limit = Math.min(50, Math.max(1, Number.parseInt(query.limit, 10) || 30));
  return { page, limit, skip: (page - 1) * limit };
};

module.exports = ({ requireUser, requireAdmin }) => {
  router.use(requireUser, requireAdmin);

  router.get('/usuarios', async (req, res) => {
    try {
      const { page, limit, skip } = paging(req.query);
      const filter = {};
      const q = String(req.query.q || '').trim();
      if (q) {
        const pattern = new RegExp(escapeRegex(q), 'i');
        filter.$or = [{ nombre: pattern }, { correo: pattern }, { carnet: pattern }, { carrera: pattern }];
      }
      if (['Estudiante', 'Docente', 'Administrador'].includes(req.query.rol)) filter.rol = req.query.rol;
      if (req.query.estado === 'suspendidos') {
        filter.$and = [...(filter.$and || []), { baneado: true }, { rol: { $nin: ['Administrador', 'admin', 'administrador'] } }];
      } else if (req.query.estado === 'activos') {
        filter.$and = [...(filter.$and || []), { $or: [{ baneado: { $ne: true } }, { rol: { $in: ['Administrador', 'admin', 'administrador'] } }] }];
      }
      const [users, total] = await Promise.all([
        Usuario.find(filter).select('-password -fotoPerfil').sort({ nombre: 1, _id: 1 }).skip(skip).limit(limit).lean(),
        Usuario.countDocuments(filter),
      ]);
      return res.json({ items: users.map((user) => ({
        ...user,
        baneado: ['admin', 'administrador'].includes(user.rol?.toLowerCase())
          ? false
          : user.baneado === true,
      })), total, page, limit });
    } catch (_) { return res.status(500).json({ error: 'No se pudieron cargar los usuarios.' }); }
  });

  router.patch('/usuarios/:id/rol', async (req, res) => {
    const role = typeof req.body?.rol === 'string' ? req.body.rol.trim() : '';
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ error: 'Usuario inválido.' });
    if (!['Estudiante', 'Docente', 'Administrador'].includes(role)) return res.status(400).json({ error: 'El rol debe ser Estudiante, Docente o Administrador.' });
    const user = await Usuario.findById(req.params.id);
    if (!user) return res.status(404).json({ error: 'No se encontró el usuario.' });
    user.rol = role;
    if (role === 'Administrador') {
      user.baneado = false;
      user.reservasNoRetiradas = 0;
    }
    await user.save();
    return res.json({ usuario: { id: user._id, nombre: user.nombre, correo: user.correo, rol: user.rol, baneado: user.baneado } });
  });

  router.patch('/usuarios/:id/suspension', async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ error: 'Usuario inválido.' });
    if (typeof req.body?.baneado !== 'boolean') return res.status(400).json({ error: 'Indica si la cuenta debe quedar suspendida.' });
    const user = await Usuario.findById(req.params.id);
    if (!user) return res.status(404).json({ error: 'No se encontró el usuario.' });
    if (['admin', 'administrador'].includes(user.rol?.toLowerCase())) {
      return res.status(400).json({ error: 'Las cuentas administrativas no se suspenden.' });
    }
    if (user._id.equals(req.user._id) && req.body.baneado) return res.status(400).json({ error: 'No puedes suspender tu propia cuenta.' });
    user.baneado = req.body.baneado;
    if (!user.baneado) user.reservasNoRetiradas = 0;
    await user.save();
    return res.json({ usuario: { id: user._id, nombre: user.nombre, baneado: user.baneado, reservasNoRetiradas: user.reservasNoRetiradas } });
  });

  router.get('/reportes', async (req, res) => {
    try { return res.json(await getUsageReport(req.query)); }
    catch (error) { return res.status(error.status || 500).json({ error: error.message || 'No se pudo generar el reporte.' }); }
  });

  router.get('/recursos', async (req, res) => {
    const { page, limit, skip } = paging(req.query);
    const filter = { activo: { $ne: false } };
    const q = String(req.query.q || '').trim();
    if (q) {
      const pattern = new RegExp(escapeRegex(q), 'i');
      filter.$or = ['nombre', 'autor', 'editorial', 'anio', 'categoria', 'codigoInventario', 'tipo', 'ubicacion', 'lugar']
        .map((field) => ({ [field]: pattern }));
    }
    for (const field of ['tipo', 'autor', 'anio', 'editorial', 'categoria']) {
      const value = String(req.query[field] || '').trim();
      if (value) filter[field] = new RegExp(escapeRegex(value), 'i');
    }
    const [resources, total] = await Promise.all([
      Recurso.find(filter).sort({ nombre: 1, _id: 1 }).skip(skip).limit(limit).lean(),
      Recurso.countDocuments(filter),
    ]);
    const enriched = await withResourceAvailability(resources);
    const result = enriched.map(({ reservasActivas, prestamosActivos, ...resource }) => ({
      ...resource,
      reservado: reservasActivas,
      enPrestamo: prestamosActivos,
    }));
    return res.json({ items: result, total, page, limit });
  });

  router.post('/recursos', async (req, res) => {
    const payload = Object.fromEntries(fields.filter((key) => req.body?.[key] !== undefined).map((key) => [key, req.body[key]]));
    if (typeof payload.nombre !== 'string' || !payload.nombre.trim() || !['Libro', 'Computadora'].includes(payload.tipo)) return res.status(400).json({ error: 'El nombre y un tipo válido (Libro o Computadora) son obligatorios.' });
    payload.nombre = payload.nombre.trim();
    payload.activo = true;
    if (Array.isArray(payload.codigosCopias)) payload.codigosCopias = payload.codigosCopias.map(String).map((code) => code.trim()).filter(Boolean);
    const resource = await Recurso.create(payload);
    return res.status(201).json(resource);
  });

  router.put('/recursos/:id', async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ error: 'Recurso inválido.' });
    const payload = Object.fromEntries(fields.filter((key) => req.body?.[key] !== undefined).map((key) => [key, req.body[key]]));
    if (payload.nombre !== undefined && (typeof payload.nombre !== 'string' || !payload.nombre.trim())) return res.status(400).json({ error: 'El nombre no puede quedar vacío.' });
    if (payload.tipo !== undefined && !['Libro', 'Computadora'].includes(payload.tipo)) return res.status(400).json({ error: 'El tipo debe ser Libro o Computadora.' });
    if (payload.nombre) payload.nombre = payload.nombre.trim();
    if (Array.isArray(payload.codigosCopias)) payload.codigosCopias = payload.codigosCopias.map(String).map((code) => code.trim()).filter(Boolean);
    const resource = await Recurso.findOneAndUpdate({ _id: req.params.id, activo: { $ne: false } }, { $set: payload }, { new: true, runValidators: true });
    if (!resource) return res.status(404).json({ error: 'No se encontró el recurso.' });
    return res.json(resource);
  });

  router.delete('/recursos/:id', async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ error: 'Recurso inválido.' });
    const resource = await Recurso.findOne({ _id: req.params.id, activo: { $ne: false } });
    if (!resource) return res.status(404).json({ error: 'No se encontró el recurso.' });
    const active = await Prestamo.exists({ recursoId: resource._id, estado: { $in: ['Activo', 'activo'] } });
    if (active) return res.status(409).json({ error: 'No puedes dar de baja un recurso con préstamos activos.' });
    await Reserva.updateMany({ recursoId: resource._id, estado: { $in: ['Activa', 'activa'] } }, { $set: { estado: 'Cancelada' } });
    resource.activo = false;
    await resource.save();
    return res.json({ mensaje: 'Recurso dado de baja.' });
  });

  return router;
};
