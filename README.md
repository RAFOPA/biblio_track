# BiblioTrack

Aplicación Flutter y API Express para buscar recursos, reservarlos y tramitar préstamos con validación del personal de biblioteca.

## Iniciar el backend

1. Inicia MongoDB local con la base `BiblioTrack`.
2. Desde `backend`, instala las dependencias con `npm.cmd install` en PowerShell (`npm install` en otros shells).
3. Configura las variables de entorno del backend y ejecuta `node index.js`.

La API usa `MONGODB_URI` para MongoDB y `CORS_ORIGINS` para una lista de orígenes web permitidos, separados por comas. Los clientes móviles sin encabezado `Origin` también pueden conectarse. En producción configura los dominios exactos de la aplicación web.

Las sesiones se guardan en MongoDB y vencen después de siete días. El cierre de sesión y el restablecimiento de contraseña revocan las sesiones almacenadas.

## Configurar la aplicación

En Flutter Web, la API usa por defecto el mismo host desde el que abriste la app. Si ejecutas Chrome en esta computadora, inicia Flutter sin `API_BASE_URL` (o usa `http://localhost:3000/api` explícitamente):

```sh
flutter run -d chrome --web-port 5000
```

Para probar desde un teléfono físico, configura la IP LAN de la computadora que ejecuta el backend:

```sh
flutter run --dart-define=API_BASE_URL=http://192.168.40.9:3000/api
```

Sustituye `192.168.40.9` por la IPv4 actual de esa computadora. Las compilaciones de producción requieren HTTPS:

```sh
flutter build apk --release --dart-define=API_BASE_URL=https://api.ejemplo.edu/api
```

Android permite HTTP solo en el manifiesto de depuración; en el manifiesto principal el tráfico sin cifrar está deshabilitado.

## Funciones administrativas

El panel de biblioteca permite confirmar préstamos mediante QR. Desde Administración también se pueden crear, editar y dar de baja libros y computadoras, gestionar roles y suspensiones, y consultar reportes con filtros de fechas.

La baja de recursos es lógica para mantener el historial. No se puede dar de baja un recurso con préstamos activos.

## Reglas de reserva y préstamo

- Las reservas duran 30 o 60 minutos, a elección del estudiante.
- Cada estudiante puede tener como máximo cinco libros o recursos y una computadora reservados o prestados al mismo tiempo.
- Los recursos indican si están disponibles, reservados o en préstamo.
- El préstamo comienza al confirmarlo un administrador. El plazo lo asigna el personal: 1, 3, 7 o 14 días.
- El QR es único por préstamo pendiente y queda invalidado al vencer la reserva o confirmarse el préstamo.
- Una reserva vencida sin recoger genera una advertencia. Al acumular tres, la cuenta queda suspendida y debe contactar al personal de biblioteca.

## Recuperación de contraseña

Para habilitar la recuperación por correo, configura `SMTP_HOST`, `SMTP_USER`, `SMTP_PASS` y las variables SMTP opcionales en el entorno del backend. Para Gmail usa una contraseña de aplicación. El código vence a los 15 minutos y permite cinco intentos.

## Pruebas

Ejecuta las pruebas Flutter desde la raíz del proyecto y las pruebas de integración de la API desde `backend`:

```sh
flutter test
cd backend
npm.cmd test
```
