<?php
/**
 * api/config.php
 * Conexión a PostgreSQL, CORS, autenticación por token y utilidades comunes.
 * Todos los endpoints de /api hacen `require __DIR__ . '/config.php';`
 * Compatible con PHP 7.4+ (extensión pdo_pgsql habilitada).
 */

error_reporting(E_ALL);
ini_set('display_errors', '0');   // el JSON debe salir limpio; los errores van al log de PHP
ini_set('log_errors', '1');

// ---------------------------------------------------------------------------
// Configuración (se puede sobrescribir con api/config.local.php o variables de entorno)
// ---------------------------------------------------------------------------
function kds_config($clave = null)
{
    static $cfg = null;
    if ($cfg === null) {
        $cfg = array(
            'db_host'      => getenv('KDS_DB_HOST') ?: '127.0.0.1',
            'db_port'      => getenv('KDS_DB_PORT') ?: '5432',
            'db_name'      => getenv('KDS_DB_NAME') ?: 'sazontrack_db2',
            'db_user'      => getenv('KDS_DB_USER') ?: 'postgres',
            'db_pass'      => getenv('KDS_DB_PASS') !== false ? getenv('KDS_DB_PASS') : '123456789',
            'debug'        => getenv('KDS_DEBUG') !== false ? (getenv('KDS_DEBUG') === '1') : true,
            'auto_migrar'  => true,    // crea las tablas/columnas que falten (sql/migracion_kds.sql)
            'token_horas'  => 12,      // duración de la sesión
        );
        $local = __DIR__ . '/config.local.php';
        if (file_exists($local)) {
            $extra = require $local;
            if (is_array($extra)) {
                $cfg = array_merge($cfg, $extra);
            }
        }
    }
    return $clave === null ? $cfg : $cfg[$clave];
}

// ---------------------------------------------------------------------------
// CORS (también está en .htaccess; aquí se repite por si Apache no lo aplica)
// ---------------------------------------------------------------------------
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Content-Type: application/json; charset=UTF-8');

if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// ---------------------------------------------------------------------------
// Errores y respuestas
// ---------------------------------------------------------------------------
class ApiError extends Exception
{
    public $http;
    public function __construct($mensaje, $http = 400)
    {
        parent::__construct($mensaje);
        $this->http = $http;
    }
}

function json_salida($arr, $http)
{
    http_response_code($http);
    echo json_encode($arr, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PARTIAL_OUTPUT_ON_ERROR);
    exit;
}

/** Respuesta correcta: {"status":"ok","data":...} */
function responder($data = null, $http = 200)
{
    json_salida(array('status' => 'ok', 'data' => $data), $http);
}

/** Aborta con un error legible para la app: {"status":"error","message":"..."} */
function fallar($mensaje, $http = 400)
{
    throw new ApiError($mensaje, $http);
}

set_exception_handler(function ($e) {
    if ($e instanceof ApiError) {
        json_salida(array('status' => 'error', 'message' => $e->getMessage()), $e->http);
    }
    error_log('[KDS API] ' . get_class($e) . ': ' . $e->getMessage());
    $mensaje = 'Error interno del servidor.';
    $http = 500;
    if ($e instanceof PDOException) {
        $estado = (string)$e->getCode();
        if ($estado === '23503') {
            $mensaje = 'El registro está relacionado con otros datos y no se puede modificar o eliminar.';
            $http = 409;
        } elseif ($estado === '23505') {
            $mensaje = 'Ya existe un registro con esos datos.';
            $http = 409;
        } elseif ($estado === '23502' || $estado === '22P02' || $estado === '22007' || $estado === '22008') {
            $mensaje = 'Datos inválidos o incompletos.';
            $http = 422;
        }
    }
    $resp = array('status' => 'error', 'message' => $mensaje);
    if (kds_config('debug')) {
        $resp['detalle'] = get_class($e) . ': ' . $e->getMessage();
    }
    json_salida($resp, $http);
});

// ---------------------------------------------------------------------------
// Base de datos
// ---------------------------------------------------------------------------
function db()
{
    static $pdo = null;
    if ($pdo === null) {
        $dsn = 'pgsql:host=' . kds_config('db_host') . ';port=' . kds_config('db_port')
             . ';dbname=' . kds_config('db_name');
        $pdo = new PDO($dsn, kds_config('db_user'), kds_config('db_pass'), array(
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ));
        asegurar_esquema($pdo);
    }
    return $pdo;
}

/** Ejecuta sql/migracion_kds.sql si todavía no existen las tablas nuevas. */
function asegurar_esquema($pdo)
{
    $v = $pdo->query("SELECT (to_regclass('public.orden_detalle') IS NOT NULL
                          AND to_regclass('public.api_tokens') IS NOT NULL)")->fetchColumn();
    $existe = in_array($v, array(true, 't', '1', 1), true);
    if ($existe) {
        return;
    }
    if (!kds_config('auto_migrar')) {
        fallar('Falta ejecutar sql/migracion_kds.sql en la base de datos.', 500);
    }
    $archivo = dirname(__DIR__) . '/sql/migracion_kds.sql';
    if (!is_readable($archivo)) {
        fallar('No se encontró sql/migracion_kds.sql en el servidor.', 500);
    }
    $pdo->exec(file_get_contents($archivo));
}

function q($sql, $params = array())
{
    $st = db()->prepare($sql);
    $st->execute($params);
    return $st;
}

function pgbool($v)
{
    if (is_string($v)) {
        $v = in_array(strtolower($v), array('1', 't', 'true', 'si', 'sí', 'yes'), true);
    }
    return $v ? 't' : 'f';
}

// ---------------------------------------------------------------------------
// Entrada
// ---------------------------------------------------------------------------
function cuerpo()
{
    static $datos = null;
    if ($datos === null) {
        $raw = file_get_contents('php://input');
        $datos = array();
        if ($raw !== false && trim($raw) !== '') {
            $dec = json_decode($raw, true);
            if (!is_array($dec)) {
                fallar('El cuerpo de la petición no es un JSON válido.', 400);
            }
            $datos = $dec;
        }
    }
    return $datos;
}

function param_int($arr, $clave, $obligatorio = true)
{
    if (!isset($arr[$clave]) || $arr[$clave] === '' || $arr[$clave] === null) {
        if ($obligatorio) {
            fallar("Falta el campo '$clave'.", 422);
        }
        return null;
    }
    if (!is_numeric($arr[$clave])) {
        fallar("El campo '$clave' debe ser numérico.", 422);
    }
    return (int)$arr[$clave];
}

function texto($arr, $clave, $max = 255)
{
    $v = isset($arr[$clave]) ? trim((string)$arr[$clave]) : '';
    if (function_exists('mb_substr')) {
        return mb_substr($v, 0, $max, 'UTF-8');
    }
    return substr($v, 0, $max);
}

/**
 * UPDATE dinámico con lista blanca.
 * $permitidos: campo => tipo (int|num|str|bool|date|time)
 * Solo actualiza los campos presentes en $body. Devuelve filas afectadas.
 */
function actualizar_campos($tabla, $colId, $id, $permitidos, $body)
{
    $sets = array();
    $params = array();
    foreach ($permitidos as $campo => $tipo) {
        if (!array_key_exists($campo, $body)) {
            continue;
        }
        $v = $body[$campo];
        $ph = ':p_' . $campo;
        if ($v === null) {
            $sets[] = "$campo = CAST($ph AS " . tipo_sql($tipo) . ')';
            $params[$ph] = null;
            continue;
        }
        switch ($tipo) {
            case 'int':
                if (is_bool($v)) {
                    $v = $v ? 1 : 0;
                }
                if (!is_numeric($v)) {
                    fallar("El campo '$campo' debe ser numérico.", 422);
                }
                $params[$ph] = (int)round((float)$v);
                break;
            case 'num':
                if (!is_numeric($v)) {
                    fallar("El campo '$campo' debe ser numérico.", 422);
                }
                $params[$ph] = round((float)$v, 2);
                break;
            case 'bool':
                $params[$ph] = pgbool($v);
                break;
            default: // str, date, time
                $params[$ph] = trim((string)$v);
        }
        $sets[] = "$campo = CAST($ph AS " . tipo_sql($tipo) . ')';
    }
    if (count($sets) === 0) {
        fallar('No hay cambios que guardar.', 422);
    }
    $params[':p_id'] = $id;
    $sql = "UPDATE public.$tabla SET " . implode(', ', $sets) . " WHERE $colId = :p_id";
    $st = db()->prepare($sql);
    $st->execute($params);
    return $st->rowCount();
}

function tipo_sql($tipo)
{
    switch ($tipo) {
        case 'int':  return 'integer';
        case 'num':  return 'numeric';
        case 'bool': return 'boolean';
        case 'date': return 'date';
        case 'time': return 'time';
        default:     return 'text';
    }
}

// ---------------------------------------------------------------------------
// Autenticación (Bearer token emitido por login.php) y permisos
// ---------------------------------------------------------------------------
function leer_token()
{
    $h = '';
    if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $h = $_SERVER['HTTP_AUTHORIZATION'];
    } elseif (isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
        $h = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
    } elseif (function_exists('getallheaders')) {
        foreach (getallheaders() as $k => $v) {
            if (strtolower($k) === 'authorization') {
                $h = $v;
            }
        }
    }
    if (preg_match('/Bearer\s+(\S+)/i', $h, $m)) {
        return $m[1];
    }
    return null;
}

/** Usuario de la sesión actual (id, nombre, rol) o 401. */
function usuario_actual()
{
    static $usuario = null;
    if ($usuario !== null) {
        return $usuario;
    }
    $token = leer_token();
    if (!$token) {
        fallar('Sesión no válida. Inicia sesión de nuevo.', 401);
    }
    $st = q("SELECT u.id, u.nombre, u.rol
               FROM public.api_tokens t
               JOIN public.usuarios u ON u.id = t.id_usuario
              WHERE t.token_hash = :h AND t.expira_en > CURRENT_TIMESTAMP AND u.activo = true",
            array(':h' => hash('sha256', $token)));
    $fila = $st->fetch();
    if (!$fila) {
        fallar('La sesión expiró. Inicia sesión de nuevo.', 401);
    }
    $usuario = $fila;
    return $usuario;
}

function rol_usuario($u)
{
    return strtolower(trim((string)$u['rol']));
}

function es_admin($u)
{
    return in_array(rol_usuario($u), array('administrador', 'admin'), true);
}

function es_caja($u)
{
    return es_admin($u) || rol_usuario($u) === 'cajero';
}

/** Solo administrador: catálogo, áreas, estructura de mesas. */
function exigir_admin()
{
    $u = usuario_actual();
    if (!es_admin($u)) {
        fallar('Solo un administrador puede realizar esta acción.', 403);
    }
    return $u;
}

function exigir_caja()
{
    $u = usuario_actual();
    if (!es_caja($u)) {
        fallar('Solo caja o administración puede realizar esta acción.', 403);
    }
    return $u;
}

function en_transaccion($fn)
{
    $pdo = db();
    $pdo->beginTransaction();
    try {
        $r = $fn($pdo);
        $pdo->commit();
        return $r;
    } catch (Exception $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        throw $e;
    }
}
