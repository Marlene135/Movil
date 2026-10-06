<?php
require __DIR__ . '/config.php';
$u = usuario_actual();
$pdo = db();
$metodo = $_SERVER['REQUEST_METHOD'];
$id = isset($_GET['id']) ? (int)$_GET['id'] : 0;

const ESTADOS_RESERVA = array('programada', 'pendiente', 'confirmada', 'cancelada', 'completada');

const SELECT_RESERVA = "SELECT r.id_reserva AS id, r.id_mesa,
        COALESCE(m.numero_mesa, m.numero) AS mesa, a.nombre AS area,
        r.nombre_cliente, COALESCE(r.telefono, '') AS telefono,
        to_char(r.fecha_reserva, 'YYYY-MM-DD') AS fecha,
        to_char(r.hora_reserva, 'HH24:MI') AS hora,
        COALESCE(r.num_personas, 1) AS num_personas,
        COALESCE(r.tipo_evento, 'Normal') AS tipo_evento,
        COALESCE(r.alergias_notas, '') AS alergias_notas,
        lower(COALESCE(r.estado, 'programada')) AS estado
   FROM public.reservas r
   LEFT JOIN public.mesas m ON m.id_mesa = r.id_mesa
   LEFT JOIN public.areas a ON a.id_area = COALESCE(m.id_area, m.area_id)";

function validar_fecha($f)
{
    return is_string($f) && preg_match('/^\d{4}-\d{2}-\d{2}$/', $f) && checkdate((int)substr($f, 5, 2), (int)substr($f, 8, 2), (int)substr($f, 0, 4));
}

function validar_hora($h)
{
    return is_string($h) && preg_match('/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/', $h);
}

/** Evita dos reservas en la misma mesa con menos de 2 horas de diferencia. */
function revisar_choque($idMesa, $fecha, $hora, $ignorarId)
{
    if (!$idMesa) { return; }
    $st = q("SELECT nombre_cliente, to_char(hora_reserva, 'HH24:MI') AS hora
               FROM public.reservas
              WHERE id_mesa = :m AND fecha_reserva = CAST(:f AS date)
                AND lower(COALESCE(estado, 'programada')) NOT IN ('cancelada', 'completada')
                AND id_reserva <> :ign
                AND ABS(EXTRACT(EPOCH FROM (hora_reserva - CAST(:h AS time)))) < 7200
              LIMIT 1",
            array(':m' => $idMesa, ':f' => $fecha, ':h' => $hora, ':ign' => $ignorarId));
    $c = $st->fetch();
    if ($c) {
        fallar('Esa mesa ya está reservada a las ' . $c['hora'] . ' (' . $c['nombre_cliente'] . '). Deja al menos 2 horas entre reservas.', 409);
    }
}

// ---------------------------------------------------------------- GET
// ?mes=YYYY-MM | ?fecha=YYYY-MM-DD | sin filtro = todas
if ($metodo === 'GET') {
    $where = '';
    $params = array();
    if (isset($_GET['mes']) && preg_match('/^\d{4}-(0[1-9]|1[0-2])$/', $_GET['mes'])) {
        $where = "WHERE r.fecha_reserva >= CAST(:ini AS date)
                    AND r.fecha_reserva < (CAST(:ini2 AS date) + INTERVAL '1 month')";
        $params = array(':ini' => $_GET['mes'] . '-01', ':ini2' => $_GET['mes'] . '-01');
    } elseif (isset($_GET['fecha']) && validar_fecha($_GET['fecha'])) {
        $where = 'WHERE r.fecha_reserva = CAST(:f AS date)';
        $params = array(':f' => $_GET['fecha']);
    }
    responder(q(SELECT_RESERVA . " $where ORDER BY r.fecha_reserva, r.hora_reserva, r.id_reserva", $params)->fetchAll());
}

// ---------------------------------------------------------------- POST
if ($metodo === 'POST') {
    $b = cuerpo();
    $nombre = texto($b, 'nombre_cliente', 100);
    if ($nombre === '') { fallar('Escribe el nombre del cliente.', 422); }
    $fecha = texto($b, 'fecha_reserva', 10);
    $hora = texto($b, 'hora_reserva', 8);
    if (!validar_fecha($fecha)) { fallar('La fecha no es válida.', 422); }
    if (!validar_hora($hora)) { fallar('La hora no es válida.', 422); }
    $personas = param_int($b, 'num_personas', false);
    $personas = $personas === null ? 2 : $personas;
    if ($personas < 1 || $personas > 100) { fallar('El número de personas no es válido.', 422); }
    $idMesa = param_int($b, 'id_mesa', false);
    if ($idMesa !== null) {
        $ok = q("SELECT 1 FROM public.mesas WHERE id_mesa = :m", array(':m' => $idMesa))->fetchColumn();
        if (!$ok) { fallar('La mesa no existe.', 422); }
    }
    $estado = strtolower(texto($b, 'estado', 20));
    if ($estado === '') { $estado = 'programada'; }
    if (!in_array($estado, ESTADOS_RESERVA, true)) { fallar('Estado de reserva no válido.', 422); }
    revisar_choque($idMesa, $fecha, $hora, 0);

    $nuevo = q("INSERT INTO public.reservas
                  (id_mesa, nombre_cliente, telefono, fecha_reserva, hora_reserva, num_personas,
                   tipo_evento, alergias_notas, estado)
                VALUES (:m, :n, :t, CAST(:f AS date), CAST(:h AS time), :p, :e, :a, :s)
                RETURNING id_reserva",
        array(':m' => $idMesa, ':n' => $nombre, ':t' => texto($b, 'telefono', 20), ':f' => $fecha, ':h' => $hora,
              ':p' => $personas, ':e' => texto($b, 'tipo_evento', 50) ?: 'Normal',
              ':a' => texto($b, 'alergias_notas', 500), ':s' => $estado))->fetchColumn();
    responder(q(SELECT_RESERVA . ' WHERE r.id_reserva = :id', array(':id' => $nuevo))->fetch(), 201);
}

// ---------------------------------------------------------------- PUT
if ($metodo === 'PUT') {
    if (!$id) { fallar('Falta el id de la reserva.', 422); }
    $b = cuerpo();
    $actual = q(SELECT_RESERVA . ' WHERE r.id_reserva = :id', array(':id' => $id))->fetch();
    if (!$actual) { fallar('Reserva no encontrada.', 404); }

    if (isset($b['nombre_cliente']) && trim((string)$b['nombre_cliente']) === '') { fallar('Escribe el nombre del cliente.', 422); }
    if (isset($b['fecha_reserva']) && !validar_fecha((string)$b['fecha_reserva'])) { fallar('La fecha no es válida.', 422); }
    if (isset($b['hora_reserva']) && !validar_hora((string)$b['hora_reserva'])) { fallar('La hora no es válida.', 422); }
    if (isset($b['num_personas']) && ((int)$b['num_personas'] < 1 || (int)$b['num_personas'] > 100)) {
        fallar('El número de personas no es válido.', 422);
    }
    if (isset($b['estado'])) {
        $b['estado'] = strtolower(trim((string)$b['estado']));
        if (!in_array($b['estado'], ESTADOS_RESERVA, true)) { fallar('Estado de reserva no válido.', 422); }
    }

    $nuevoEstado = isset($b['estado']) ? $b['estado'] : $actual['estado'];
    if (!in_array($nuevoEstado, array('cancelada', 'completada'), true)) {
        $mesa = array_key_exists('id_mesa', $b) ? ($b['id_mesa'] === null ? null : (int)$b['id_mesa']) : ($actual['id_mesa'] === null ? null : (int)$actual['id_mesa']);
        $fecha = isset($b['fecha_reserva']) ? (string)$b['fecha_reserva'] : $actual['fecha'];
        $hora = isset($b['hora_reserva']) ? (string)$b['hora_reserva'] : $actual['hora'];
        revisar_choque($mesa, $fecha, $hora, $id);
    }
    actualizar_campos('reservas', 'id_reserva', $id,
        array('id_mesa' => 'int', 'nombre_cliente' => 'str', 'telefono' => 'str', 'fecha_reserva' => 'date',
              'hora_reserva' => 'time', 'num_personas' => 'int', 'tipo_evento' => 'str',
              'alergias_notas' => 'str', 'estado' => 'str'), $b);
    responder(q(SELECT_RESERVA . ' WHERE r.id_reserva = :id', array(':id' => $id))->fetch());
}

// ---------------------------------------------------------------- DELETE
if ($metodo === 'DELETE') {
    if (!$id) { fallar('Falta el id de la reserva.', 422); }
    $st = q("DELETE FROM public.reservas WHERE id_reserva = :id", array(':id' => $id));
    if ($st->rowCount() === 0) { fallar('Reserva no encontrada.', 404); }
    responder(array('id' => $id));
}

fallar('Método no permitido.', 405);
