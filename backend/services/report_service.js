const { Usuario, Recurso, Prestamo, Reserva } = require('../models');

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
  const [users, resources, loans, reservations, topResources, dailyLoans] = await Promise.all([
    Usuario.countDocuments(),
    Recurso.countDocuments({ activo: { $ne: false } }),
    Prestamo.countDocuments({ estado: { $in: ['Activo', 'Devuelto'] }, $or: [
      { fechaPrestamo: { $gte: start, $lte: end } },
      { fechaPrestamo: { $exists: false }, createdAt: { $gte: start, $lte: end } },
    ] }),
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
  ]);
  return {
    periodo: { inicio: start.toISOString(), fin: end.toISOString() },
    totales: { usuarios, recursos, prestamos: loans, reservas: reservations },
    recursosMasSolicitados: topResources,
    prestamosPorDia: dailyLoans,
  };
}

module.exports = { getUsageReport };
