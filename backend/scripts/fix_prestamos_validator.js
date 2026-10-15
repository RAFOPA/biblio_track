const path = require('node:path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const mongoose = require('mongoose');

const validator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['usuarioId', 'recursoId', 'estado'],
    properties: {
      usuarioId: {
        bsonType: 'objectId',
        description: 'El ID del usuario debe ser un ObjectId.',
      },
      recursoId: {
        bsonType: 'objectId',
        description: 'El ID del recurso debe ser un ObjectId.',
      },
      reservaId: { bsonType: ['objectId', 'null'] },
      qrToken: { bsonType: ['string', 'null'] },
      estado: {
        bsonType: 'string',
        enum: [
          'Pendiente', 'pendiente',
          'Activo', 'activo',
          'Devuelto', 'devuelto',
          'Cancelado', 'cancelado',
          'Vencido', 'vencido',
        ],
      },
      fechaPrestamo: { bsonType: ['date', 'string', 'null'] },
      fechaDevolucionEstimada: { bsonType: ['date', 'string', 'null'] },
      fechaDevolucionReal: { bsonType: ['date', 'string', 'null'] },
      plazoDias: { bsonType: ['int', 'long', 'double', 'null'] },
      plazoUnidad: { bsonType: ['string', 'null'], enum: ['horas', 'dias', null] },
      plazoValor: { bsonType: ['int', 'long', 'double', 'null'] },
      plazoMinutos: { bsonType: ['int', 'long', 'double', 'null'] },
      avisoVencimientoEn: { bsonType: ['date', 'string', 'null'] },
      infraccionAplicadaEn: { bsonType: ['date', 'string', 'null'] },
      createdAt: { bsonType: ['date', 'string', 'null'] },
      __v: { bsonType: ['int', 'long', 'double', 'null'] },
    },
  },
};

async function main() {
  const uri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/BiblioTrack';
  await mongoose.connect(uri);
  await mongoose.connection.db.command({
    collMod: 'prestamos',
    validator,
    validationLevel: 'strict',
    validationAction: 'error',
  });
  console.log('Validador de préstamos actualizado para admitir solicitudes QR pendientes y fechas ISO/BSON.');
}

main()
  .catch((error) => {
    console.error('No se pudo actualizar el validador de préstamos:', error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
