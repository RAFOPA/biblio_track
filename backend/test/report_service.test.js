const assert = require('node:assert/strict');
const { test } = require('node:test');
const models = require('../models');
const { dateRange, getUsageReport } = require('../services/report_service');

test('report date range includes the complete requested end date', () => {
  const { start, end } = dateRange({ start: '2026-10-01', end: '2026-10-15' });
  assert.deepEqual([start.getFullYear(), start.getMonth(), start.getDate(), start.getHours()], [2026, 9, 1, 0]);
  assert.deepEqual([end.getFullYear(), end.getMonth(), end.getDate(), end.getHours(), end.getMinutes(), end.getSeconds(), end.getMilliseconds()], [2026, 9, 15, 23, 59, 59, 999]);
});

test('report date range rejects malformed and inverted periods', () => {
  assert.throws(() => dateRange({ start: 'not-a-date', end: '2026-10-15' }), { status: 400 });
  assert.throws(() => dateRange({ start: '2026-10-16', end: '2026-10-15' }), { status: 400 });
});

test('usage report returns loan totals by resource type and most active borrowers', async () => {
  const original = {
    userCount: models.Usuario.countDocuments,
    resourceCount: models.Recurso.countDocuments,
    loanCount: models.Prestamo.countDocuments,
    reservationCount: models.Reserva.countDocuments,
    loanAggregate: models.Prestamo.aggregate,
    reservationAggregate: models.Reserva.aggregate,
  };
  models.Usuario.countDocuments = async () => 4;
  models.Recurso.countDocuments = async () => 7;
  models.Prestamo.countDocuments = async () => 3;
  models.Reserva.countDocuments = async () => 5;
  models.Reserva.aggregate = async () => [{ nombre: 'Libro A', tipo: 'Libro', solicitudes: 2 }];
  models.Prestamo.aggregate = async (pipeline) => {
    const group = pipeline.find((stage) => stage.$group)?.$group;
    if (group?._id?.$dateToString) return [{ _id: '2026-10-15', total: 3 }];
    if (group?._id?.$ifNull) return [{ tipo: 'Libro', prestamos: 2 }, { tipo: 'Computadora', prestamos: 1 }];
    return [{ nombre: 'Ana Pérez', carnet: 'A1', prestamos: 2 }];
  };

  try {
    const report = await getUsageReport({ start: '2026-10-01', end: '2026-10-15' });
    assert.deepEqual(report.totales, { usuarios: 4, recursos: 7, prestamos: 3, reservas: 5 });
    assert.deepEqual(report.prestamosPorTipo, [
      { tipo: 'Libro', prestamos: 2 },
      { tipo: 'Computadora', prestamos: 1 },
    ]);
    assert.deepEqual(report.usuariosConMasPrestamos, [
      { nombre: 'Ana Pérez', carnet: 'A1', prestamos: 2 },
    ]);
  } finally {
    models.Usuario.countDocuments = original.userCount;
    models.Recurso.countDocuments = original.resourceCount;
    models.Prestamo.countDocuments = original.loanCount;
    models.Reserva.countDocuments = original.reservationCount;
    models.Prestamo.aggregate = original.loanAggregate;
    models.Reserva.aggregate = original.reservationAggregate;
  }
});
