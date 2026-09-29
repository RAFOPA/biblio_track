# BiblioTrack

Aplicación Flutter y API Express para buscar recursos, reservarlos y tramitar préstamos con validación del personal de biblioteca.

## Iniciar el backend

Para habilitar la recuperaciÃ³n de contraseÃ±a por correo, copia `backend/.env.example` a `backend/.env` y configura los datos SMTP de una cuenta emisora. Para Gmail usa una contraseÃ±a de aplicaciÃ³n, no la contraseÃ±a habitual. El cÃ³digo vence a los 15 minutos y permite cinco intentos.

1. Inicia MongoDB local con la base `BiblioTrack`.
2. Desde `backend`, instala las dependencias con `npm install` si aún no están instaladas.
3. Inicia la API con `node index.js`.
4. En `lib/api_service.dart`, configura `baseUrl` con la IP de la computadora accesible desde el teléfono.

## Perfil, favoritos y advertencias

- Estudiantes y docentes comparten el flujo de bÃºsqueda, reservas y prÃ©stamos; las cuentas administrativas conservan el panel del personal.
- Cada estudiante puede guardar hasta 10 libros favoritos. La foto de perfil, favoritos y notificaciones se almacenan en su cuenta.
- El cupo por recurso es de una computadora o hasta cinco libros; si el libro tiene menos copias registradas, el cupo usa ese inventario.
- Una reservacion vencida sin recoger genera una advertencia. Al acumular tres, la cuenta queda suspendida y debe contactar al personal de biblioteca.
- El perfil incluye cambio de contrasena, cierre de sesion, historial de prestamos y acceso a todas las notificaciones de la cuenta.

## Cuentas y roles

El registro publico permite escoger los roles `Estudiante` o `Docente`. Para habilitar una cuenta del personal, registra la cuenta y cambia su rol en MongoDB:

```javascript
use BiblioTrack
db.usuarios.updateOne(
  { correo: "biblioteca@universidad.edu" },
  { $set: { rol: "Administrador" } }
)
```

El usuario debe cerrar sesión y volver a entrar para abrir el panel de biblioteca. Las cuentas de administrador pueden escanear los QR de préstamo y confirmar el plazo de devolución.

## Reglas de reserva y préstamo

- Las reservaciones duran 30 o 60 minutos, a elección del estudiante.
- Cada estudiante puede tener como máximo cinco libros/recursos y una computadora reservados o prestados al mismo tiempo.
- El préstamo comienza al confirmarlo un administrador. El plazo lo asigna el personal: 1, 3, 7 o 14 días.
- El QR es único por préstamo pendiente y queda invalidado al vencer la reservación o confirmarse el préstamo.
