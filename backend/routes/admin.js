const express = require('express');
const mongoose = require('mongoose');
const { Usuario, Recurso, Reserva, Prestamo, Notificacion } = require('../models');
const { getUsageReport, getDetailedReport, reportCatalog } = require('../services/report_service');
const { withResourceAvailability } = require('../services/resource_availability');
const { createCrudService } = require('../services/crud_service');

const fields = ['nombre', 'tipo', 'codigoInventario', 'autor', 'categoria', 'especificaciones', 'ubicacion', 'edicion', 'lugar', 'editorial', 'anio', 'codigosCopias'];
const router = express.Router();
const escapeRegex = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const paging = (query) => {
  const page = Math.max(1, Number.parseInt(query.page, 10) || 1);
  const limit = Math.min(50, Math.max(1, Number.parseInt(query.limit, 10) || 30));
  return { page, limit, skip: (page - 1) * limit };
};
const resourceCrud = createCrudService(Recurso, {
  fields: [...fields, 'activo'],
  defaultSort: { nombre: 1, _id: 1 },
  softDeleteField: 'activo',
});

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

  router.put('/usuarios/:id', async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ error: 'Usuario inválido.' });
    const nombre = typeof req.body?.nombre === 'string' ? req.body.nombre.trim() : '';
    const correo = typeof req.body?.correo === 'string' ? req.body.correo.trim().toLowerCase() : '';
    const carnet = typeof req.body?.carnet === 'string' ? req.body.carnet.trim() : '';
    const carrera = typeof req.body?.carrera === 'string' ? req.body.carrera.trim() : '';
    if (!nombre) return res.status(400).json({ error: 'El nombre no puede quedar vacío.' });
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo)) return res.status(400).json({ error: 'Ingresa un correo electrónico válido.' });
    const user = await Usuario.findById(req.params.id);
    if (!user) return res.status(404).json({ error: 'No se encontró el usuario.' });
    try {
      user.nombre = nombre;
      user.correo = correo;
      user.carnet = carnet || undefined;
      user.carrera = carrera;
      await user.save();
    } catch (error) {
      if (error?.code === 11000) return res.status(409).json({ error: 'El correo o carnet ya pertenece a otra cuenta.' });
      throw error;
    }
    return res.json({ usuario: {
      id: user._id, nombre: user.nombre, correo: user.correo,
      carnet: user.carnet || '', carrera: user.carrera || '', rol: user.rol,
      baneado: user.baneado === true,
    } });
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

  router.delete('/usuarios/:id', async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ error: 'Usuario inválido.' });
    const user = await Usuario.findById(req.params.id);
    if (!user) return res.status(404).json({ error: 'No se encontró el usuario.' });
    if (user._id.equals(req.user._id)) return res.status(400).json({ error: 'No puedes suspender tu propia cuenta.' });
    if (['admin', 'administrador'].includes(user.rol?.toLowerCase())) {
      return res.status(400).json({ error: 'Las cuentas administrativas no se eliminan desde esta ruta.' });
    }
    user.baneado = true;
    await user.save();
    await Session.deleteMany({ usuarioId: user._id });
    return res.json({ mensaje: 'Cuenta suspendida; los datos históricos se conservaron.', usuario: { id: user._id, nombre: user.nombre, baneado: true } });
  });

  router.get('/reportes', async (req, res) => {
    try { return res.json(await getUsageReport(req.query)); }
    catch (error) { return res.status(error.status || 500).json({ error: error.message || 'No se pudo generar el reporte.' }); }
  });

  router.get('/reportes/catalogo', (_req, res) => res.json(reportCatalog));

  router.get('/reportes/detalle', async (req, res) => {
    try { return res.json(await getDetailedReport(req.query)); }
    catch (error) { return res.status(error.status || 500).json({ error: error.message || 'No se pudo generar el reporte detallado.' }); }
  });

  router.get('/notificaciones/vencidas', async (req, res) => {
    try {
      const notifications = await Notificacion.find({
        usuarioId: req.user._id,
        titulo: 'Préstamo vencido: infracción registrada',
      }).sort({ createdAt: -1 }).limit(100).lean();
      return res.json(notifications);
    } catch (_) {
      return res.status(500).json({ error: 'No se pudieron cargar las alertas de préstamos vencidos.' });
    }
  });

  router.get('/notificaciones', async (req, res) => {
    const { page, limit, skip } = paging(req.query);
    const filter = {};
    if (mongoose.isValidObjectId(req.query.usuarioId)) filter.usuarioId = req.query.usuarioId;
    const [items, total] = await Promise.all([
      Notificacion.find(filter).populate('usuarioId', 'nombre carnet correo')
        .sort({ createdAt: -1, _id: -1 }).skip(skip).limit(limit).lean(),
      Notificacion.countDocuments(filter),
    ]);
    return res.json({ items, total, page, limit });
  });

  router.post('/notificaciones', async (req, res) => {
    const { usuarioId, titulo, mensaje } = req.body ?? {};
    if (!mongoose.isValidObjectId(usuarioId)
      || typeof titulo !== 'string' || !titulo.trim()
      || typeof mensaje !== 'string' || !mensaje.trim()) {
      return res.status(400).json({ error: 'Indica un usuario válido, un título y un mensaje.' });
    }
    if (!await Usuario.exists({ _id: usuarioId })) return res.status(404).json({ error: 'No se encontró el usuario.' });
    const notification = await Notificacion.create({ usuarioId, titulo: titulo.trim(), mensaje: mensaje.trim() });
    return res.status(201).json(notification);
  });

  router.patch('/notificaciones/:id', async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ error: 'Notificación inválida.' });
    const payload = {};
    if (typeof req.body?.leida === 'boolean') payload.leida = req.body.leida;
    if (typeof req.body?.titulo === 'string' && req.body.titulo.trim()) payload.titulo = req.body.titulo.trim();
    if (typeof req.body?.mensaje === 'string' && req.body.mensaje.trim()) payload.mensaje = req.body.mensaje.trim();
    if (!Object.keys(payload).length) return res.status(400).json({ error: 'Indica al menos un campo válido para actualizar.' });
    const notification = await Notificacion.findByIdAndUpdate(req.params.id, { $set: payload }, { new: true, runValidators: true });
    if (!notification) return res.status(404).json({ error: 'No se encontró la notificación.' });
    return res.json(notification);
  });

  router.delete('/notificaciones/:id', async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ error: 'Notificación inválida.' });
    const result = await Notificacion.deleteOne({ _id: req.params.id });
    if (!result.deletedCount) return res.status(404).json({ error: 'No se encontró la notificación.' });
    return res.json({ mensaje: 'Notificación eliminada.' });
  });

  router.get('/reservas', async (req, res) => {
    const { page, limit, skip } = paging(req.query);
    const filter = {};
    if (['Activa', 'Prestada', 'Expirada', 'Cancelada'].includes(req.query.estado)) filter.estado = req.query.estado;
    if (mongoose.isValidObjectId(req.query.usuarioId)) filter.usuarioId = req.query.usuarioId;
    if (mongoose.isValidObjectId(req.query.recursoId)) filter.recursoId = req.query.recursoId;
    const [items, total] = await Promise.all([
      Reserva.find(filter).populate('usuarioId', 'nombre carnet correo')
        .populate('recursoId', 'nombre tipo codigoInventario')
        .sort({ fechaReserva: -1, _id: -1 }).skip(skip).limit(limit).lean(),
      Reserva.countDocuments(filter),
    ]);
    return res.json({ items, total, page, limit });
  });

  router.get('/reservas/:id', async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ error: 'Reserva inválida.' });
    const reservation = await Reserva.findById(req.params.id)
      .populate('usuarioId', 'nombre carnet correo')
      .populate('recursoId', 'nombre tipo codigoInventario').lean();
    if (!reservation) return res.status(404).json({ error: 'No se encontró la reserva.' });
    return res.json(reservation);
  });

  router.patch('/reservas/:id/cancelar', async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ error: 'Reserva inválida.' });
    const reservation = await Reserva.findOneAndUpdate(
      { _id: req.params.id, estado: { $in: ['Activa', 'activa'] } },
      { $set: { estado: 'Cancelada' } },
      { new: true },
    );
    if (!reservation) return res.status(404).json({ error: 'No se encontró una reserva activa para cancelar.' });
    await Prestamo.updateMany({ reservaId: reservation._id, estado: { $in: ['Pendiente', 'pendiente'] } }, { $set: { estado: 'Cancelado' } });
    return res.json({ reserva: reservation, mensaje: 'Reserva cancelada.' });
  });

  router.post('/prestamos/:id/rechazar', async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Préstamo inválido.' });
    }
    const loan = await Prestamo.findOneAndUpdate(
      { _id: req.params.id, estado: 'Pendiente' },
      { $set: { estado: 'Cancelado' } },
      { new: true },
    );
    if (!loan) {
      return res.status(409).json({
        error: 'El préstamo ya fue procesado o no está pendiente.',
      });
    }
    await Reserva.updateOne(
      { _id: loan.reservaId, estado: { $in: ['Activa', 'activa'] } },
      { $set: { estado: 'Cancelada' } },
    );
    const resource = await Recurso.findById(loan.recursoId)
      .select('nombre')
      .lean();
    try {
      await Notificacion.create({
        usuarioId: loan.usuarioId,
        titulo: 'Préstamo rechazado',
        mensaje: `El personal rechazó la solicitud de “${resource?.nombre || 'tu recurso'}”. La reserva asociada fue cancelada; puedes consultar al personal si necesitas más información.`,
      });
    } catch (error) {
      console.error('No se pudo notificar el rechazo del préstamo:', error);
    }
    return res.json({ mensaje: 'Préstamo rechazado y reserva cancelada.' });
  });

  router.get('/prestamos/activos', async (req, res) => {
    try {
      const { page, limit, skip } = paging(req.query);
      const q = String(req.query.q || '').trim();
      const pipeline = [
        { $match: { estado: { $in: ['Activo', 'activo'] } } },
        {
          $lookup: {
            from: 'usuarios',
            localField: 'usuarioId',
            foreignField: '_id',
            as: 'usuario',
          },
        },
        { $unwind: { path: '$usuario', preserveNullAndEmptyArrays: true } },
        {
          $lookup: {
            from: 'recursos',
            localField: 'recursoId',
            foreignField: '_id',
            as: 'recurso',
          },
        },
        { $unwind: { path: '$recurso', preserveNullAndEmptyArrays: true } },
      ];
      if (q) {
        const pattern = new RegExp(escapeRegex(q), 'i');
        pipeline.push({
          $match: {
            $or: [
              { 'usuario.nombre': pattern },
              { 'usuario.carnet': pattern },
              { 'usuario.correo': pattern },
              { 'recurso.nombre': pattern },
              { 'recurso.codigoInventario': pattern },
              { 'recurso.autor': pattern },
            ],
          },
        });
      }
      pipeline.push({
        $facet: {
          items: [
            { $sort: { fechaDevolucionEstimada: 1, fechaPrestamo: -1, _id: -1 } },
            { $skip: skip },
            { $limit: limit },
            {
              $project: {
                _id: 1,
                estado: 1,
                fechaPrestamo: 1,
                fechaDevolucionEstimada: 1,
                fechaDevolucionReal: 1,
                plazoDias: 1,
                plazoUnidad: 1,
                plazoValor: 1,
                avisoVencimientoEn: 1,
                infraccionAplicadaEn: 1,
                createdAt: 1,
                usuario: {
                  _id: '$usuario._id',
                  nombre: '$usuario.nombre',
                  carnet: '$usuario.carnet',
                  correo: '$usuario.correo',
                },
                recurso: {
                  _id: '$recurso._id',
                  nombre: '$recurso.nombre',
                  tipo: '$recurso.tipo',
                  autor: '$recurso.autor',
                  codigoInventario: '$recurso.codigoInventario',
                },
              },
            },
          ],
          total: [{ $count: 'count' }],
        },
      });
      const [result] = await Prestamo.aggregate(pipeline).exec();
      return res.json({
        items: result?.items ?? [],
        total: result?.total?.[0]?.count ?? 0,
        page,
        limit,
      });
    } catch (_) {
      return res.status(500).json({ error: 'No se pudieron cargar los préstamos activos.' });
    }
  });

  router.get('/prestamos', async (req, res) => {
    const { page, limit, skip } = paging(req.query);
    const filter = {};
    if (typeof req.query.estado === 'string' && req.query.estado.trim()) filter.estado = req.query.estado.trim();
    if (mongoose.isValidObjectId(req.query.usuarioId)) filter.usuarioId = req.query.usuarioId;
    if (mongoose.isValidObjectId(req.query.recursoId)) filter.recursoId = req.query.recursoId;
    const [items, total] = await Promise.all([
      Prestamo.find(filter).populate('usuarioId', 'nombre carnet correo carrera')
        .populate('recursoId', 'nombre tipo codigoInventario autor')
        .populate('reservaId').sort({ createdAt: -1, _id: -1 })
        .skip(skip).limit(limit).lean(),
      Prestamo.countDocuments(filter),
    ]);
    return res.json({ items, total, page, limit });
  });

  router.get('/prestamos/:id', async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ error: 'Préstamo inválido.' });
    const loan = await Prestamo.findById(req.params.id)
      .populate('usuarioId', 'nombre carnet correo carrera')
      .populate('recursoId', 'nombre tipo codigoInventario autor')
      .populate('reservaId').lean();
    if (!loan) return res.status(404).json({ error: 'No se encontró el préstamo.' });
    return res.json(loan);
  });

  router.patch('/prestamos/:id/devolver', async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Préstamo inválido.' });
    }
    const returned = await Prestamo.findOneAndUpdate(
      { _id: req.params.id, estado: { $in: ['Activo', 'activo'] } },
      { $set: { estado: 'Devuelto', fechaDevolucionReal: new Date() } },
      { new: true },
    );
    if (!returned) {
      const exists = await Prestamo.exists({ _id: req.params.id });
      return res.status(exists ? 409 : 404).json({
        error: exists
          ? 'Este préstamo ya no está activo; actualiza la lista para ver su estado.'
          : 'No se encontró el préstamo.',
      });
    }
    const loan = await Prestamo.findById(returned._id)
      .populate('recursoId', 'nombre tipo codigoInventario')
      .populate('usuarioId', 'nombre carnet correo')
      .lean();
    try {
      await Notificacion.create({
        usuarioId: returned.usuarioId,
        titulo: 'Recurso devuelto',
        mensaje: `El personal registró la devolución de “${loan?.recursoId?.nombre || 'tu recurso'}”.`,
      });
    } catch (error) {
      console.error('No se pudo crear la notificación de devolución:', error);
    }
    return res.json({ prestamo: loan });
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

  router.get('/recursos/:id', async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ error: 'Recurso inválido.' });
    const resource = await resourceCrud.getById(req.params.id);
    if (!resource || resource.activo === false) return res.status(404).json({ error: 'No se encontró el recurso.' });
    return res.json(resource);
  });

  router.post('/recursos', async (req, res) => {
    const payload = Object.fromEntries(fields.filter((key) => req.body?.[key] !== undefined).map((key) => [key, req.body[key]]));
    if (typeof payload.nombre !== 'string' || !payload.nombre.trim() || !['Libro', 'Computadora'].includes(payload.tipo)) return res.status(400).json({ error: 'El nombre y un tipo válido (Libro o Computadora) son obligatorios.' });
    payload.nombre = payload.nombre.trim();
    payload.activo = true;
    if (Array.isArray(payload.codigosCopias)) payload.codigosCopias = payload.codigosCopias.map(String).map((code) => code.trim()).filter(Boolean);
    const resource = await resourceCrud.create(payload);
    return res.status(201).json(resource);
  });

  router.put('/recursos/:id', async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ error: 'Recurso inválido.' });
    const payload = Object.fromEntries(fields.filter((key) => req.body?.[key] !== undefined).map((key) => [key, req.body[key]]));
    if (payload.nombre !== undefined && (typeof payload.nombre !== 'string' || !payload.nombre.trim())) return res.status(400).json({ error: 'El nombre no puede quedar vacío.' });
    if (payload.tipo !== undefined && !['Libro', 'Computadora'].includes(payload.tipo)) return res.status(400).json({ error: 'El tipo debe ser Libro o Computadora.' });
    if (payload.nombre) payload.nombre = payload.nombre.trim();
    if (Array.isArray(payload.codigosCopias)) payload.codigosCopias = payload.codigosCopias.map(String).map((code) => code.trim()).filter(Boolean);
    const resource = await resourceCrud.updateById(req.params.id, payload, { filter: { activo: { $ne: false } } });
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
    await resourceCrud.deleteById(resource._id);
    return res.json({ mensaje: 'Recurso dado de baja.' });
  });

  return router;
};
