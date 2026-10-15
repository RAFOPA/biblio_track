const { Usuario, Recurso, Prestamo, Reserva } = require('../models');
const { withResourceAvailability } = require('./resource_availability');

const reportCatalog = [
  { id: 'usuarios_totales', title: 'Clientes totales', withDates: false },
  { id: 'usuarios_activos', title: 'Clientes activos', withDates: false },
  { id: 'recursos_totales', title: 'Recursos totales', withDates: false },
  { id: 'recursos_disponibles', title: 'Recursos disponibles', withDates: false },
  { id: 'prestamos_activos', title: 'Préstamos activos', withDates: false },
  { id: 'prestamos_periodo', title: 'Préstamos registrados', withDates: true },
  { id: 'recursos_mas_utilizados', title: 'Recursos más utilizados', withDates: true },
  { id: 'usuarios_mas_activos', title: 'Clientes con más préstamos', withDates: true },
  { id: 'reservas_periodo', title: 'Reservas recibidas', withDates: true },
  { id: 'infracciones_periodo', title: 'Infracciones por vencimiento', withDates: true },
];

const REPORT_ROW_LIMIT = 20000;

const dateRange = (query) => {
  const end = query.end ? new Date(`${query.end}T23:59:59.999`) : new Date();
  const start = query.start ? new Date(`${query.start}T00:00:00.000`) : new Date(end.getTime() - 29 * 86400000);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || start > end) {
    const error = new Error('El rango de fechas no es válido.');
    error.status = 400;
    throw error;
  }
  return { start, end };
};

async function getUsageReport(query) {
  const { start, end } = dateRange(query);
  const loanDateFilter = { $or: [
    { fechaPrestamo: { $gte: start, $lte: end } },
    { fechaPrestamo: { $exists: false }, createdAt: { $gte: start, $lte: end } },
  ] };
  const loanFilter = { estado: { $in: ['Activo', 'Devuelto'] }, ...loanDateFilter };
  const loanAggregation = [
    { $match: loanFilter },
    { $lookup: { from: 'recursos', localField: 'recursoId', foreignField: '_id', as: 'recurso' } },
    { $unwind: { path: '$recurso', preserveNullAndEmptyArrays: true } },
    { $lookup: { from: 'usuarios', localField: 'usuarioId', foreignField: '_id', as: 'usuario' } },
    { $unwind: { path: '$usuario', preserveNullAndEmptyArrays: true } },
  ];
  const [usuarios, recursos, prestamos, reservas, topResources, dailyLoans, loansByType, topBorrowers] = await Promise.all([
    Usuario.countDocuments(),
    Recurso.countDocuments({ activo: { $ne: false } }),
    Prestamo.countDocuments(loanFilter),
    Reserva.countDocuments({ fechaReserva: { $gte: start, $lte: end } }),
    Reserva.aggregate([
      { $match: { fechaReserva: { $gte: start, $lte: end }, estado: { $ne: 'Cancelada' } } },
      { $group: { _id: '$recursoId', solicitudes: { $sum: 1 } } },
      { $sort: { solicitudes: -1 } }, { $limit: 5 },
      { $lookup: { from: 'recursos', localField: '_id', foreignField: '_id', as: 'recurso' } },
      { $unwind: { path: '$recurso', preserveNullAndEmptyArrays: true } },
      { $project: { _id: 1, nombre: { $ifNull: ['$recurso.nombre', 'Recurso eliminado'] }, tipo: '$recurso.tipo', solicitudes: 1 } },
    ]),
    Prestamo.aggregate([
      { $match: { fechaPrestamo: { $gte: start, $lte: end } } },
      { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$fechaPrestamo' } }, total: { $sum: 1 } } },
      { $sort: { _id: 1 } },
    ]),
    Prestamo.aggregate([
      ...loanAggregation,
      { $group: { _id: { $ifNull: ['$recurso.tipo', 'Otro'] }, prestamos: { $sum: 1 } } },
      { $sort: { prestamos: -1, _id: 1 } },
      { $project: { _id: 0, tipo: '$_id', prestamos: 1 } },
    ]),
    Prestamo.aggregate([
      ...loanAggregation,
      { $group: {
        _id: '$usuarioId',
        nombre: { $first: { $ifNull: ['$usuario.nombre', 'Usuario desconocido'] } },
        carnet: { $first: '$usuario.carnet' },
        prestamos: { $sum: 1 },
      } },
      { $sort: { prestamos: -1, nombre: 1, _id: 1 } },
      { $limit: 10 },
      { $project: { _id: 0, usuarioId: '$_id', nombre: 1, carnet: 1, prestamos: 1 } },
    ]),
  ]);
  return {
    periodo: { inicio: start.toISOString(), fin: end.toISOString() },
    totales: { usuarios, recursos, prestamos, reservas },
    recursosMasSolicitados: topResources,
    prestamosPorDia: dailyLoans,
    prestamosPorTipo: loansByType,
    usuariosConMasPrestamos: topBorrowers,
  };
}

const asDate = (value) => {
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? '' : date.toISOString();
};

const reportResult = (definition, columns, rows, period = null) => ({
  type: definition.id,
  title: definition.title,
  columns,
  rows,
  period: period ? { start: period.start.toISOString(), end: period.end.toISOString() } : null,
});

const resourceColumns = ['Recurso', 'Tipo', 'Código de inventario', 'Autor', 'Año', 'Editorial', 'Categoría', 'Ubicación', 'Estado'];
const resourceRow = (resource) => [
  resource.nombre || '', resource.tipo || '', resource.codigoInventario || '',
  resource.autor || '', resource.anio || '', resource.editorial || '',
  resource.categoria || '', resource.ubicacion || '',
  resource.disponible ? 'Disponible' : 'No disponible',
];

async function getDetailedReport(query) {
  const definition = reportCatalog.find((item) => item.id === query.type);
  if (!definition) {
    const error = new Error('Selecciona un tipo de reporte válido.');
    error.status = 400;
    throw error;
  }
  const period = definition.withDates ? dateRange(query) : null;

  if (definition.id === 'usuarios_totales' || definition.id === 'usuarios_activos') {
    const filter = definition.id === 'usuarios_activos' ? { baneado: { $ne: true } } : {};
    const users = await Usuario.find(filter)
      .select('nombre carnet correo carrera rol baneado reservasNoRetiradas infraccionesPrestamo')
      .sort({ nombre: 1, carnet: 1, _id: 1 })
      .limit(REPORT_ROW_LIMIT)
      .lean();
    return reportResult(definition,
      ['Nombre', 'Carnet', 'Correo', 'Carrera', 'Rol', 'Estado de cuenta', 'Reservas vencidas', 'Infracciones de préstamo'],
      users.map((user) => [
        user.nombre || '', user.carnet || '', user.correo || '', user.carrera || '',
        user.rol || '', user.baneado ? 'Suspendida' : 'Activa',
        String(user.reservasNoRetiradas || 0), String(user.infraccionesPrestamo || 0),
      ]));
  }

  if (definition.id === 'recursos_totales' || definition.id === 'recursos_disponibles') {
    const resources = await Recurso.find({ activo: { $ne: false } })
      .sort({ nombre: 1, _id: 1 })
      .limit(REPORT_ROW_LIMIT)
      .lean();
    const availability = await withResourceAvailability(resources);
    const selected = definition.id === 'recursos_disponibles'
      ? availability.filter((item) => item.disponible)
      : availability;
    return reportResult(definition, resourceColumns, selected.map(resourceRow));
  }

  const dateMatch = period
    ? { $or: [
      { fechaPrestamo: { $gte: period.start, $lte: period.end } },
      { fechaPrestamo: { $exists: false }, createdAt: { $gte: period.start, $lte: period.end } },
    ] }
    : null;
  const activeStates = { $in: ['Activo', 'activo'] };
  const baseLoans = [
    { $lookup: { from: 'recursos', localField: 'recursoId', foreignField: '_id', as: 'recurso' } },
    { $unwind: { path: '$recurso', preserveNullAndEmptyArrays: true } },
    { $lookup: { from: 'usuarios', localField: 'usuarioId', foreignField: '_id', as: 'usuario' } },
    { $unwind: { path: '$usuario', preserveNullAndEmptyArrays: true } },
  ];

  if (definition.id === 'prestamos_activos' || definition.id === 'prestamos_periodo') {
    const match = definition.id === 'prestamos_activos'
      ? { estado: activeStates }
      : { ...dateMatch, estado: { $in: ['Activo', 'activo', 'Devuelto', 'devuelto'] } };
    const loans = await Prestamo.aggregate([
      { $match: match }, ...baseLoans,
      { $sort: { fechaPrestamo: -1, createdAt: -1, _id: -1 } },
      { $limit: REPORT_ROW_LIMIT },
      { $project: {
        createdAt: 1,
        fechaPrestamo: 1, fechaDevolucionEstimada: 1, fechaDevolucionReal: 1,
        estado: 1, plazoUnidad: 1, plazoValor: 1, plazoDias: 1,
        recurso: { nombre: '$recurso.nombre', tipo: '$recurso.tipo', codigoInventario: '$recurso.codigoInventario', autor: '$recurso.autor' },
        usuario: { nombre: '$usuario.nombre', carnet: '$usuario.carnet', carrera: '$usuario.carrera', correo: '$usuario.correo' },
      } },
    ]).exec();
    return reportResult(definition,
      ['Fecha de préstamo', 'Fecha límite', 'Fecha real de devolución', 'Estado', 'Recurso', 'Tipo', 'Inventario', 'Autor', 'Cliente', 'Carnet', 'Carrera', 'Correo'],
      loans.map((loan) => [
        asDate(loan.fechaPrestamo || loan.createdAt), asDate(loan.fechaDevolucionEstimada), asDate(loan.fechaDevolucionReal),
        loan.estado || '', loan.recurso?.nombre || '', loan.recurso?.tipo || '', loan.recurso?.codigoInventario || '', loan.recurso?.autor || '',
        loan.usuario?.nombre || '', loan.usuario?.carnet || '', loan.usuario?.carrera || '', loan.usuario?.correo || '',
      ]), period);
  }

  if (definition.id === 'recursos_mas_utilizados') {
    const rows = await Prestamo.aggregate([
      { $match: { ...dateMatch, estado: { $in: ['Activo', 'activo', 'Devuelto', 'devuelto'] } } },
      ...baseLoans,
      { $group: {
        _id: '$recursoId', nombre: { $first: '$recurso.nombre' }, tipo: { $first: '$recurso.tipo' },
        inventario: { $first: '$recurso.codigoInventario' }, autor: { $first: '$recurso.autor' },
        prestamos: { $sum: 1 }, usuarios: { $addToSet: { $cond: [{ $ifNull: ['$usuario.nombre', false] }, { $concat: ['$usuario.nombre', ' (', { $ifNull: ['$usuario.carnet', 'sin carnet'] }, ')'] }, null] } },
      } },
      { $sort: { prestamos: -1, nombre: 1 } }, { $limit: 100 },
    ]).exec();
    return reportResult(definition,
      ['Recurso', 'Tipo', 'Inventario', 'Autor', 'Préstamos', 'Clientes que lo solicitaron'],
      rows.map((item) => [item.nombre || 'Recurso eliminado', item.tipo || '', item.inventario || '', item.autor || '', String(item.prestamos), (item.usuarios || []).filter(Boolean).join(', ')]), period);
  }

  if (definition.id === 'usuarios_mas_activos') {
    const rows = await Prestamo.aggregate([
      { $match: { ...dateMatch, estado: { $in: ['Activo', 'activo', 'Devuelto', 'devuelto'] } } },
      ...baseLoans,
      { $group: {
        _id: '$usuarioId', nombre: { $first: '$usuario.nombre' }, carnet: { $first: '$usuario.carnet' },
        carrera: { $first: '$usuario.carrera' }, correo: { $first: '$usuario.correo' }, prestamos: { $sum: 1 },
      } },
      { $sort: { prestamos: -1, nombre: 1 } }, { $limit: 500 },
    ]).exec();
    return reportResult(definition,
      ['Cliente', 'Carnet', 'Carrera', 'Correo', 'Préstamos'],
      rows.map((item) => [item.nombre || '', item.carnet || '', item.carrera || '', item.correo || '', String(item.prestamos)]), period);
  }

  if (definition.id === 'reservas_periodo') {
    const reservations = await Reserva.find({ fechaReserva: { $gte: period.start, $lte: period.end } })
      .populate('usuarioId', 'nombre carnet carrera correo')
      .populate('recursoId', 'nombre tipo codigoInventario autor')
      .sort({ fechaReserva: -1, _id: -1 })
      .limit(REPORT_ROW_LIMIT)
      .lean();
    return reportResult(definition,
      ['Fecha de reserva', 'Estado', 'Recurso', 'Tipo', 'Inventario', 'Autor', 'Cliente', 'Carnet', 'Carrera', 'Correo'],
      reservations.map((item) => [
        asDate(item.fechaReserva), item.estado || '', item.recursoId?.nombre || '', item.recursoId?.tipo || '',
        item.recursoId?.codigoInventario || '', item.recursoId?.autor || '', item.usuarioId?.nombre || '',
        item.usuarioId?.carnet || '', item.usuarioId?.carrera || '', item.usuarioId?.correo || '',
      ]), period);
  }

  const infractions = await Prestamo.find({
    infraccionAplicadaEn: { $gte: period.start, $lte: period.end },
  })
    .populate('usuarioId', 'nombre carnet carrera correo')
    .populate('recursoId', 'nombre tipo codigoInventario autor')
    .sort({ infraccionAplicadaEn: -1, _id: -1 })
    .limit(REPORT_ROW_LIMIT)
    .lean();
  return reportResult(definition,
    ['Fecha de infracción', 'Recurso', 'Tipo', 'Inventario', 'Cliente', 'Carnet', 'Carrera', 'Correo', 'Estado del préstamo'],
    infractions.map((item) => [
      asDate(item.infraccionAplicadaEn), item.recursoId?.nombre || '', item.recursoId?.tipo || '',
      item.recursoId?.codigoInventario || '', item.usuarioId?.nombre || '', item.usuarioId?.carnet || '',
      item.usuarioId?.carrera || '', item.usuarioId?.correo || '', item.estado || '',
    ]), period);
}

module.exports = { dateRange, getUsageReport, reportCatalog, getDetailedReport };
