# Documentación técnica y evidencias de API — BiblioTrack

**Proyecto:** BiblioTrack  
**Backend:** Node.js, Express y Mongoose  
**Base de datos:** MongoDB  
**Fecha de revisión:** 26 de octubre de 2026

## 1. Objetivo

Este documento describe la autenticación, autorización, acceso a MongoDB, operaciones de las entidades y reportes de BiblioTrack. También indica las capturas que se deben adjuntar como evidencia y la ubicación exacta del código.

## 2. Arquitectura implementada

El backend expone una API REST con Express. Los modelos Mongoose representan usuarios, recursos, préstamos, reservas, notificaciones y las colecciones internas de sesión y recuperación de contraseña. Las rutas de autenticación delegan en un controlador; el controlador usa el servicio de autenticación para validar contraseñas y emitir tokens. Las rutas administrativas aplican middleware de sesión y rol. Las consultas de reportes se separan en un servicio.

La aplicación Flutter conserva el mismo contrato de login: recibe `token` y lo envía como `Authorization: Bearer <token>`. El valor que emite el backend ahora es un JWT firmado HS256 con vigencia de siete días. El servidor conserva el hash del token en MongoDB para poder invalidarlo al cerrar sesión, cambiar o restablecer la contraseña. Durante la transición también acepta sesiones Bearer antiguas que sigan vigentes.

## 3. Autenticación y autorización

### Registro

La ruta `POST /api/auth/register` valida nombre, correo, contraseña, rol permitido y duplicados. Las contraseñas se almacenan derivadas con PBKDF2 y salt aleatorio. El registro público solo permite los roles Estudiante y Docente; las cuentas administrativas las asigna el personal.

### Inicio de sesión y JWT

La ruta `POST /api/auth/login` valida correo y contraseña, verifica el estado de la cuenta y devuelve el usuario público, el JWT, el tipo Bearer y su fecha de expiración. El secreto se lee de `JWT_SECRET`; debe tener al menos 32 bytes. En producción es obligatorio. Para desarrollo local se permite un secreto de desarrollo predeterminado para que la API existente pueda arrancar sin cambiar el `.env` local.

### Middleware de acceso

`requireUser` verifica la firma y expiración del JWT, comprueba que el token siga registrado en `sessions`, carga el usuario y comprueba si la cuenta está suspendida. `requireAdmin` limita las operaciones administrativas a administradores; `requireStudent` limita operaciones estudiantiles a estudiantes y docentes. Las rutas bajo `/api/admin` aplican ambos controles antes de ejecutar handlers.

### Cierre de sesión y recuperación

El cierre de sesión elimina de MongoDB el hash del token usado. El cambio o restablecimiento de contraseña elimina las sesiones existentes, por lo que los tokens emitidos anteriormente dejan de autorizar solicitudes.

## 4. Configuración

Se añadió `backend/.env.example`. Copia ese archivo como `backend/.env` y configura valores propios. Variables disponibles:

- `PORT`: puerto HTTP; predeterminado 3000.
- `NODE_ENV`: entorno de ejecución.
- `MONGODB_URI`: conexión a MongoDB.
- `CORS_ORIGINS`: lista separada por comas de orígenes web permitidos.
- `JWT_SECRET`: secreto aleatorio de al menos 32 bytes; obligatorio en producción.
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASS` y `MAIL_FROM`: configuración opcional para recuperación por correo.

El archivo `backend/.env` está excluido de Git. No adjuntes capturas que expongan el valor real del secreto, contraseñas, URI de base de datos, correo personal o tokens Bearer.

## 5. Endpoints disponibles

Todas las rutas `/api/admin/...` requieren JWT Bearer válido y rol administrador, salvo que se indique otra cosa. Los flujos de préstamo y reserva mantienen operaciones de dominio (por ejemplo, confirmar, devolver o cancelar) para no permitir cambios arbitrarios que rompan el historial.

### Autenticación y perfil

| Método | Ruta | Acceso | Uso |
|---|---|---|---|
| POST | `/api/auth/register` | Público | Crear cuenta de estudiante o docente. |
| POST | `/api/auth/login` | Público | Validar credenciales y emitir JWT Bearer. |
| POST | `/api/auth/logout` | Usuario autenticado | Revocar el token de la sesión actual. |
| POST | `/api/auth/forgot-password` | Público | Solicitar código de recuperación. |
| POST | `/api/auth/reset-password` | Público | Validar código, cambiar contraseña y revocar sesiones. |
| POST | `/api/auth/password` | Usuario autenticado | Cambiar contraseña con la contraseña actual. |
| GET | `/api/users/me` | Usuario autenticado | Consultar perfil propio. |
| PUT | `/api/users/me/photo` | Usuario autenticado | Actualizar foto de perfil. |

### Usuarios y recursos

| Método | Ruta | Acceso | Uso |
|---|---|---|---|
| GET | `/api/admin/usuarios` | Administrador | Listar usuarios con paginación y filtros. |
| PUT | `/api/admin/usuarios/:id` | Administrador | Editar nombre, correo, carnet y carrera. |
| PATCH | `/api/admin/usuarios/:id/rol` | Administrador | Cambiar rol con lista permitida. |
| PATCH | `/api/admin/usuarios/:id/suspension` | Administrador | Suspender o reactivar una cuenta. |
| DELETE | `/api/admin/usuarios/:id` | Administrador | Suspensión lógica y revocación de sesiones; conserva datos históricos. No permite auto suspensión ni borrar administradores. |
| GET/POST | `/api/recursos` | Lectura pública / escritura administrador | Consultar catálogo y crear recurso. |
| GET | `/api/admin/recursos` | Administrador | Listar recursos con paginación y filtros. |
| GET | `/api/admin/recursos/:id` | Administrador | Consultar un recurso. |
| POST | `/api/admin/recursos` | Administrador | Crear recurso. |
| PUT | `/api/admin/recursos/:id` | Administrador | Editar recurso. |
| DELETE | `/api/admin/recursos/:id` | Administrador | Baja lógica; bloquea recursos con préstamos activos y cancela reservas activas. |

### Reservas y préstamos

| Método | Ruta | Acceso | Uso |
|---|---|---|---|
| POST | `/api/recursos/:id/reservas` | Estudiante/docente autenticado | Crear reserva, validando límites y disponibilidad. |
| GET | `/api/reservas/mias` | Estudiante/docente autenticado | Consultar reservas propias activas. |
| GET | `/api/admin/reservas` | Administrador | Listar reservas, con filtros por estado, usuario y recurso. |
| GET | `/api/admin/reservas/:id` | Administrador | Consultar detalle de una reserva. |
| PATCH | `/api/admin/reservas/:id/cancelar` | Administrador | Cancelar reserva activa y su préstamo pendiente asociado. |
| POST | `/api/prestamos/pendientes` | Estudiante/docente autenticado | Crear solicitud pendiente a partir de una reserva válida. |
| GET | `/api/prestamos/mios` | Estudiante/docente autenticado | Consultar préstamos propios. |
| GET | `/api/admin/prestamos` | Administrador | Listar préstamos con filtros por usuario, recurso y estado. |
| GET | `/api/admin/prestamos/:id` | Administrador | Consultar detalle de préstamo. |
| GET | `/api/admin/prestamos/activos` | Administrador | Listar préstamos activos con búsqueda y paginación. |
| GET | `/api/admin/prestamos/qr/:token` | Administrador | Validar préstamo pendiente mediante QR. |
| POST | `/api/admin/prestamos/:id/confirmar` | Administrador | Confirmar préstamo y asignar plazo. |
| POST | `/api/admin/prestamos/:id/rechazar` | Administrador | Rechazar solicitud pendiente y cancelar la reserva asociada. |
| PATCH | `/api/admin/prestamos/:id/devolver` | Administrador | Registrar devolución sin borrar el historial. |

### Favoritos y notificaciones

| Método | Ruta | Acceso | Uso |
|---|---|---|---|
| GET/POST/DELETE | `/api/favoritos/...` | Estudiante/docente autenticado | Consultar, agregar o quitar favoritos del usuario actual. |
| GET | `/api/notificaciones/mias` | Usuario autenticado | Consultar notificaciones propias. |
| DELETE | `/api/notificaciones/mias/:id` | Usuario autenticado | Eliminar notificación propia. |
| GET | `/api/admin/notificaciones` | Administrador | Consultar notificaciones, opcionalmente filtradas por usuario. |
| POST | `/api/admin/notificaciones` | Administrador | Crear notificación para un usuario existente. |
| PATCH | `/api/admin/notificaciones/:id` | Administrador | Actualizar título, mensaje o estado de lectura. |
| DELETE | `/api/admin/notificaciones/:id` | Administrador | Eliminar notificación. |

### Reportes

| Método | Ruta | Acceso | Uso |
|---|---|---|---|
| GET | `/api/admin/reportes` | Administrador | Resumen de actividad con periodo de fechas. |
| GET | `/api/admin/reportes/catalogo` | Administrador | Catálogo de reportes disponibles. |
| GET | `/api/admin/reportes/detalle` | Administrador | Reporte tabular filtrado por tipo y fechas. |

## 6. Servicios CRUD y protección de datos

El servicio genérico asíncrono `createCrudService` implementa listar con paginación, buscar por ID, crear, actualizar con validadores y eliminar o dar de baja lógicamente. Se utiliza para recursos administrativos, con lista explícita de campos permitidos. Los handlers validan los datos de entrada antes de llamar al servicio.

Las entidades con reglas de negocio no exponen edición destructiva arbitraria: los préstamos se procesan mediante confirmar, rechazar y devolver; las reservas se crean con validación de capacidad y se cancelan por transición de estado; los usuarios se suspenden en lugar de borrarse para preservar historial. `sessions` y `passwordresets` son colecciones internas: no se ofrecen endpoints CRUD públicos ni administrativos para ver o modificar sus hashes/códigos.

## 7. Reportes y consultas MongoDB

Los reportes aplican rangos de fecha y consultas de agregación. Se realizan conteos paralelos con `Promise.all`; las agregaciones usan `$match` para filtrar, `$lookup` y `$unwind` para relacionar préstamos con usuarios y recursos, `$group` y `$sum` para resumir, y `$sort`/`$limit` para ordenar y limitar resultados. Hay reportes de totales, préstamos por tipo y día, recursos más solicitados, usuarios más activos, reservas e infracciones.

Los resultados detallados se muestran en el panel administrativo y se pueden exportar desde Flutter a PDF o Excel. La optimización está sustentada en paginación, proyecciones, límites e índices declarados en el esquema de préstamos y expiración; no se afirma una mejora de rendimiento medida con benchmark.

## 8. Guion de pruebas manuales para las capturas

Usa Postman o Insomnia y una base de datos de demostración. No reutilices datos personales reales.

1. Ejecuta `POST /api/auth/register` con nombre, correo ficticio y contraseña de demostración; captura estado `201` y el usuario devuelto.
2. Ejecuta `POST /api/auth/login`; captura estado `200`, `tokenType: Bearer` y `expiresAt`. Enmascara completamente el JWT.
3. Ejecuta `GET /api/users/me` sin Authorization; captura `401`.
4. Ejecuta una ruta `/api/admin/...` con JWT de estudiante; captura `403`.
5. Ejecuta las mismas rutas con JWT administrador; captura acceso `200` y encabezado `Authorization: Bearer ***` enmascarado.
6. En recursos, captura GET, POST, PUT y DELETE sobre un registro de prueba; verifica que DELETE resulte en baja lógica y que el recurso no se borre físicamente.
7. En usuarios, captura edición y suspensión lógica; comprueba que la sesión se revoque y que no se borre el historial.
8. En reservas y préstamos, captura creación/consulta y transición de cancelación, confirmación o devolución; no alteres estados directamente en MongoDB.
9. En notificaciones, captura lectura y una operación de creación/actualización/eliminación con usuario de prueba.
10. Ejecuta un reporte para un rango de fechas corto; captura el JSON/resultado en el panel y el código de agregación.
11. Captura la plantilla `backend/.env.example`, asegurándote de que solo contiene el texto de reemplazo para `JWT_SECRET`, nunca el secreto real.

## 9. Lista exacta de capturas y referencias de código

Las líneas indicadas corresponden a los archivos de esta entrega. En el editor usa “Ir a línea” (Ctrl+G) para llegar directamente. Si una edición futura mueve las líneas, busca el nombre del método o ruta indicada.

**Evidencia 1 — Modelos y colecciones**  
Captura las declaraciones de modelos y referencias en `backend/models/index.js`, líneas 3–71. Incluye usuario, recurso, préstamo, reserva, notificación, recuperación y sesión.

**Evidencia 2 — Variables de configuración**  
Captura `backend/.env.example`, líneas 1–14, y `README.md`, líneas 9–13. Enmarca `JWT_SECRET` como variable requerida en producción. No abras ni captures el `.env` real.

**Evidencia 3 — Contraseña y creación/verificación JWT**  
Captura `backend/services/auth_service.js`, líneas 7–18 y 20–78. Asegúrate de mostrar generación HS256, expiración, firma y verificación.

**Evidencia 4 — Controlador de registro y login**  
Captura `backend/controllers/auth_controller.js`, líneas 25–63 para registro y líneas 65–94 para login. La respuesta conserva `token`, `tokenType` y `expiresAt`.

**Evidencia 5 — Enrutamiento de autenticación**  
Captura `backend/routes/auth.js`, líneas 1–8, y `backend/index.js`, línea 298, donde se monta `/api/auth`.

**Evidencia 6 — Middleware de autenticación y roles**  
Captura `backend/index.js`, líneas 73–117, para la validación del Bearer, JWT, sesión, suspensión y roles; en `backend/routes/admin.js`, línea 23, captura la protección global del router administrativo.

**Evidencia 7 — Servicio CRUD genérico**  
Captura `backend/services/crud_service.js`, líneas 1–39. Ahí se ven las operaciones asíncronas genéricas y la selección de campos permitidos.

**Evidencia 8 — CRUD administrativo de recursos**  
Captura `backend/routes/admin.js`, líneas 409–471. Incluye listados, lectura por ID, POST, PUT y DELETE lógico con validaciones y protección administrativa.

**Evidencia 9 — Usuarios y reservas**  
Captura `backend/routes/admin.js`, líneas 25–122 para consulta, edición, rol, suspensión y suspensión lógica de usuarios; luego líneas 191–225 para consulta/cancelación de reservas.

**Evidencia 10 — Préstamos**  
Captura `backend/routes/admin.js`, líneas 227–408. Incluye rechazo, listado, consulta individual y devolución; en `backend/index.js`, líneas 483–507 y 520–558, están los flujos de reserva y préstamo del usuario.

**Evidencia 11 — Notificaciones**  
Captura `backend/routes/admin.js`, líneas 148–189, donde se implementan GET, POST, PATCH y DELETE administrativos.

**Evidencia 12 — Seguridad de tokens/revocación**  
Captura `backend/index.js`, líneas 368–399 para logout y cambio de contraseña, y `backend/controllers/auth_controller.js`, líneas 84–90 para sustituir la sesión existente al iniciar sesión.

**Evidencia 13 — Endpoint y agregaciones de reportes**  
Captura `backend/routes/admin.js`, líneas 124–133 para rutas de reportes y `backend/services/report_service.js`, líneas 35–91 y 167–220 para filtros, relaciones y agrupaciones.

**Evidencia 14 — Resultado visible del reporte**  
Captura el panel de reportes en la app con el filtro de fecha visible, el resultado y la exportación PDF/Excel. El archivo de interfaz está en `lib/screens/admin_management_screen.dart`, alrededor de las líneas 1327–1515 y 1569–1695.

## 10. Texto final para pegar en el informe

> El backend de BiblioTrack se desarrolló con Node.js, Express y Mongoose sobre MongoDB. El módulo de autenticación valida las credenciales, aplica validaciones de registro y almacena contraseñas derivadas con PBKDF2 y salt aleatorio. Al iniciar sesión se genera un JWT firmado con HS256, con expiración de siete días. El secreto se configura mediante `JWT_SECRET`, separado de los archivos versionados, y es obligatorio en producción. Para conservar la revocación de sesiones, el hash del token se almacena en MongoDB; cerrar sesión o cambiar/restablecer la contraseña invalida los tokens existentes. El middleware `requireUser` autentica las solicitudes, mientras `requireStudent` y `requireAdmin` autorizan las operaciones según el rol. Las rutas administrativas quedan protegidas en conjunto. Los servicios y handlers realizan operaciones asíncronas sobre usuarios, recursos, reservas, préstamos y notificaciones. El servicio CRUD genérico restringe los campos actualizables; las reglas de dominio conservan el historial mediante bajas o suspensiones lógicas y transiciones de estado para reservas y préstamos. Los reportes administrativos reutilizan rutas y servicios, filtran por fechas y usan agregaciones MongoDB con relaciones, agrupaciones, sumas, ordenamiento y límites. Las capturas adjuntas muestran la configuración sin secretos, la emisión y validación de tokens, las respuestas de autorización, las operaciones CRUD/estado y los resultados de reportes.

## 11. Validación realizada

Se ejecutó `npm.cmd test` en `backend`: 9 pruebas aprobadas y 0 fallidas. También se verificó la sintaxis de los archivos JavaScript modificados con `node --check`. No se requirió cambiar la app Flutter: conserva el mismo campo `token` y el mismo encabezado Bearer.
