const mongoose = require('mongoose');

const isComputer = (resource) => /comput|equipo/i.test(resource?.tipo ?? '');

const resourceCapacity = (resource) => {
  if (isComputer(resource)) return 1;
  const copyCodes = Array.isArray(resource?.codigosCopias)
    ? new Set(resource.codigosCopias.map((code) => String(code).trim()).filter(Boolean))
    : null;
  return copyCodes?.size || 1;
};

const availabilityStatus = (reservations, loans) => loans > 0
  ? 'En préstamo'
  : reservations > 0 ? 'Reservado' : 'Disponible';

const idKey = (id) => `${id?._bsontype ?? typeof id}:${id?.toString() ?? ''}`;

async function withResourceAvailability(resources, now = new Date()) {
  if (!resources.length) return [];
  const db = mongoose.connection.db;
  if (!db) throw new Error('MongoDB todavía no está conectado.');
  const ids = resources.map((resource) => resource._id);
  const [reservationCounts, loanCounts] = await Promise.all([
    db.collection('reservas').aggregate([
      {
        $match: {
          recursoId: { $in: ids },
          estado: { $in: ['Activa', 'activa'] },
          fechaExpiracion: { $gt: now },
        },
      },
      { $group: { _id: '$recursoId', count: { $sum: 1 } } },
    ]).toArray(),
    db.collection('prestamos').aggregate([
      {
        $match: {
          recursoId: { $in: ids },
          estado: { $in: ['Activo', 'activo'] },
        },
      },
      { $group: { _id: '$recursoId', count: { $sum: 1 } } },
    ]).toArray(),
  ]);
  const reservationsByResource = new Map(
    reservationCounts.map(({ _id, count }) => [idKey(_id), count]),
  );
  const loansByResource = new Map(
    loanCounts.map(({ _id, count }) => [idKey(_id), count]),
  );

  return resources.map((resource) => {
    const key = idKey(resource._id);
    const reservations = reservationsByResource.get(key) ?? 0;
    const loans = loansByResource.get(key) ?? 0;
    return {
      ...resource,
      reservasActivas: reservations,
      prestamosActivos: loans,
      disponible: reservations + loans < resourceCapacity(resource),
      estadoDisponibilidad: availabilityStatus(reservations, loans),
    };
  });
}

module.exports = { isComputer, resourceCapacity, availabilityStatus, withResourceAvailability };
