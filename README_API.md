# SazónTrack / KDS — conexión con PostgreSQL

Arquitectura: **App Flutter → PHP (`/KDS/api/*.php`) → PostgreSQL (`sazontrack_db2`)**.

## 1. Servidor (Apache + PHP)
1. Requisitos: PHP 7.4+ con la extensión `pdo_pgsql`, Apache con `mod_rewrite` y `mod_headers`.
2. La carpeta `KDS/` debe quedar publicada en `http://<host>:8081/KDS/` (igual que antes).
3. Datos de conexión: valores por defecto en `api/config.php`
   (host `127.0.0.1`, puerto `5432`, BD `sazontrack_db2`, usuario `postgres`).
   Para cambiarlos copia `api/config.local.example.php` → `api/config.local.php`.
   También sirven variables de entorno `KDS_DB_HOST/PORT/NAME/USER/PASS`.
4. **Primera petición:** la API crea sola lo que falta (`sql/migracion_kds.sql`):
   tabla `orden_detalle` (platillos de cada comanda), `api_tokens` (sesiones),
   columnas `ordenes.comensales` y `mesas.grupo_union`, normaliza mesas (`LIBRE`→`disponible`,
   mesas sin área → primera área) y corrige secuencias de ID. Es idempotente; también
   puedes ejecutarla a mano con `psql -d sazontrack_db2 -f sql/migracion_kds.sql`.
   El usuario de BD necesita permisos DDL. Para desactivarlo: `'auto_migrar' => false`.
5. Diagnóstico: `POST /KDS/login.php` con cuerpo `{}` responde que la conexión a PostgreSQL funciona.

## 2. App Flutter
```
cd menu_mesaeros
flutter pub get
flutter run -d chrome                                   # web: usa el host desde el que se sirve
flutter run --dart-define=API_HOST=192.168.1.50         # móvil/escritorio: IP del servidor
flutter run --dart-define=API_HOST=10.0.2.2             # emulador Android
```
Opcionales: `--dart-define=API_PORT=8081`, `--dart-define=API_PATH=/KDS`.

## 3. Qué hace cada pantalla (todo contra la BD)
| Pantalla | Lee | Modifica |
|---|---|---|
| Login PIN | `usuarios` | crea sesión (`api_tokens`) |
| Dashboard | resumen en vivo (órdenes, mesas, reservas, ventas) | — |
| Mesas | `areas`, `mesas`, cuentas abiertas | asignar mesa, mover/unir/separar (se guarda), estado, crear/editar/eliminar mesa y área, **cobrar** (`pagos`) |
| Menú / POS | `categorias`, `productos`, comanda de la mesa | enviar comanda (`ordenes`+`orden_detalle`), cancelar platillo, **admin:** crear/editar/desactivar productos y categorías |
| Cocina / Barra (KDS) | platillos pendientes por estación | pendiente → en preparación → listo → entregado |
| Reservaciones | `reservas` por mes | crear/editar/confirmar/cancelar/eliminar (evita choques de mesa ±2 h) |

## 4. Permisos
Administrador: todo. Cajero: cobrar y cancelar cuentas con consumo. Resto: operar mesas, comandas y cocina.
Las reglas se aplican en el servidor (la app solo oculta botones).

## 5. API (todas devuelven `{"status":"ok","data":...}` o `{"status":"error","message":...}`)
`login.php` · `api/mesas.php` · `api/areas.php` · `api/categorias.php` · `api/productos.php` ·
`api/ordenes.php?accion=abrir|enviar|cancelar_item|cancelar_orden|pagar` · `api/kds.php` ·
`api/reservas.php` · `api/dashboard.php`. Se envía `Authorization: Bearer <token>` (12 h).
