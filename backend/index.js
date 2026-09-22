const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');

const app = express();
const PORT = 3000;

// Middlewares para que el servidor entienda JSON y acepte peticiones de Flutter
app.use(cors());
app.use(express.json());

// 1. CONEXIÓN A MONGODB (Usando tu base de datos local "biblio_track")
mongoose.connect('mongodb://127.0.0.1:27017/biblio_track')
  .then(() => console.log('¡Conectado a MongoDB exitosamente! 🚀'))
  .catch(err => console.error('Error al conectar a MongoDB:', err));

// 2. DEFINIR LOS MODELOS (Estructura de las colecciones)

// Modelo de Usuario
const UsuarioSchema = new mongoose.Schema({
  carnet: String,
  nombre: String,
  correo: String,
  rol: String
});
const Usuario = mongoose.model('Usuario', UsuarioSchema);

// Modelo de Recurso (Libros y Computadoras unificados)
const RecursoSchema = new mongoose.Schema({
  codigoInventario: String,
  nombre: String,
  tipo: String, // "Libro" o "Computadora"
  autor: String,
  categoria: String,
  especificaciones: String,
  ubicacion: String,
  disponible: Boolean
});
const Recurso = mongoose.model('Recurso', RecursoSchema);

// Modelo de Préstamo
const PrestamoSchema = new mongoose.Schema({
  usuarioId: { type: mongoose.Schema.Types.ObjectId, ref: 'Usuario' },
  recursoId: { type: mongoose.Schema.Types.ObjectId, ref: 'Recurso' },
  fechaPrestamo: { type: Date, default: Date.now },
  fechaDevolucionEstimada: Date,
  fechaDevolucionReal: Date,
  estado: { type: String, default: 'Activo' }
});
const Prestamo = mongoose.model('Prestamo', PrestamoSchema);


// 3. RUTAS BÁSICAS (Endpoints para que Flutter hable con la BD)

// Ruta de prueba
app.get('/', (req, res) => {
  res.json({ mensaje: "API de BiblioTrack funcionando al 100%" });
});

// OBTENER TODOS LOS RECURSOS (Libros y Computadoras)
app.get('/api/recursos', async (req, res) => {
  try {
    const recursos = await Recurso.find();
    res.json(recursos);
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener los recursos' });
  }
});

// CREAR UN NUEVO RECURSO
app.post('/api/recursos', async (req, res) => {
  try {
    const nuevoRecurso = new Recurso(req.body);
    await nuevoRecurso.save();
    res.json({ mensaje: 'Recurso guardado con éxito', recurso: nuevoRecurso });
  } catch (error) {
    res.status(500).json({ error: 'Error al guardar el recurso' });
  }
});


// 4. ENCENDER EL SERVIDOR
app.listen(PORT, () => {
  console.log(`Servidor corriendo en http://localhost:${PORT}`);
});