<?php
require __DIR__ . '/config.php';
require __DIR__ . '/ordenes_lib.php';
$u = usuario_actual();
$pdo = db();
$metodo = $_SERVER['REQUEST_METHOD'];
$id = isset($_GET['id']) ? (int)$_GET['id'] : 0;
$accion = isset($_GET['accion']) ? $_GET['accion'] : '';

const ESTADOS_MESA = array('disponible', 'ocupada', 'por_limpiar', 'reservada');

const SELECT_MESA = "SELECT m.id_mesa AS id,
        COALESCE(m.numero_mesa, m.numero) AS numero,
        COALESCE(m.capacidad, 4) AS capacidad,
        CASE WHEN lower(COALESCE(m.estado, 'disponible')) = 'libre' THEN 'disponible'
             ELSE lower(COALESCE(m.estado, 'disponible')) END AS estado,
        COALESCE(m.id_area, m.area_id) AS id_area,
        a.nombre AS area,
        COALESCE(m.pos_x, 0) AS pos_x, COALESCE(m.pos_y, 0) AS pos_y,
        m.grupo_union,
        o.id_orden, COALESCE(o.total, 0) AS total_actual, o.comensales,
        us.nombre AS mesero
   FROM public.mesas m
   LEFT JOIN public.areas a ON a.id_area = COALESCE(m.id_area, m.area_id)
   LEFT JOIN LATERAL (
        SELECT * FROM public.ordenes x
         WHERE x.id_mesa = m.id_mesa AND upper(x.estado) = 'ABIERTA'
         ORDER BY x.id_orden DESC LIMIT 1) o ON true
   LEFT JOIN public.usuarios us ON us.id = o.id_usuario";

function mesa_por_id($id)
{
    return q(SELECT_MESA . ' WHERE m.id_mesa = :id', array(':id' => $id))->fetch();
}

// ---------------------------------------------------------------- GET
if ($metodo === 'GET') {
    responder(q(SELECT_MESA . ' ORDER BY COALESCE(m.id_area, m.area_id), m.id_mesa')->fetchAll());
}

// ------------------------------------------- POST ?accion=layout
// Guarda posiciones y uniones de varias mesas: {"mesas":[{"id":1,"pos_x":10,"pos_y":20,"grupo_union":null}]}
if ($metodo === 'POST' && $accion === 'layout') {
    $lista = isset(cuerpo()['mesas']) ? cuerpo()['mesas'] : array();
    if (!is_array($lista) || count($lista) === 0) {
        fallar('No hay mesas que guardar.', 422);
    }
    en_transaccion(function ($pdo) use ($lista) {
        $st = $pdo->prepare("UPDATE public.mesas
                                SET pos_x = :x, pos_y = :y, grupo_union = CAST(:g AS integer)
                              WHERE id_mesa = :id");
        foreach ($lista as $m) {
            $st->execute(array(
                ':x'  => (int)round((float)(isset($m['pos_x']) ? $m['pos_x'] : 0)),
                ':y'  => (int)round((float)(isset($m['pos_y']) ? $m['pos_y'] : 0)),
                ':g'  => (isset($m['grupo_union']) && $m['grupo_union'] !== null) ? (int)$m['grupo_union'] : null,
                ':id' => (int)(isset($m['id']) ? $m['id'] : 0),
            ));
        }
    });
    responder(true);
}

// ---------------------------------------------------------------- POST (crear)
if ($metodo === 'POST') {
    exigir_admin();
    $b = cuerpo();
    $numero = texto($b, 'numero', 20);
    if ($numero === '') { fallar('Escribe el número o nombre de la mesa.', 422); }
    $cap = param_int($b, 'capacidad', false);
    $cap = $cap === null ? 4 : max(1, $cap);
    $area = param_int($b, 'id_area', false);
    if ($area !== null) {
        $ok = q("SELECT 1 FROM public.areas WHERE id_area = :a", array(':a' => $area))->fetchColumn();
        if (!$ok) { fallar('El área no existe.', 422); }
    }
    $dup = q("SELECT 1 FROM public.mesas
               WHERE lower(COALESCE(numero_mesa, numero)) = lower(:n)
                 AND COALESCE(id_area, area_id, 0) = :a",
             array(':n' => $numero, ':a' => $area === null ? 0 : $area))->fetchColumn();
    if ($dup) { fallar('Ya existe una mesa con ese número en esa área.', 409); }
    $nuevo = q("INSERT INTO public.mesas (id_area, numero_mesa, numero, capacidad, estado, pos_x, pos_y)
                VALUES (:a, :n, :n2, :c, 'disponible', 0, 0) RETURNING id_mesa",
               array(':a' => $area, ':n' => $numero, ':n2' => $numero, ':c' => $cap))->fetchColumn();
    responder(mesa_por_id($nuevo), 201);
}

// ---------------------------------------------------------------- PUT (editar)
if ($metodo === 'PUT') {
    if (!$id) { fallar('Falta el id de la mesa.', 422); }
    $b = cuerpo();
    $estructura = array('numero', 'capacidad', 'id_area');
    foreach ($estructura as $k) {
        if (array_key_exists($k, $b)) { exigir_admin(); break; }
    }
    if (isset($b['numero'])) {
        $b['numero'] = texto($b, 'numero', 20);
        if ($b['numero'] === '') { fallar('El número de mesa no puede estar vacío.', 422); }
        $b['numero_mesa'] = $b['numero'];
    }
    if (isset($b['capacidad']) && (int)$b['capacidad'] < 1) { fallar('La capacidad mínima es 1.', 422); }

    $estadoNuevo = null;
    if (isset($b['estado'])) {
        $estadoNuevo = strtolower(trim((string)$b['estado']));
        if (!in_array($estadoNuevo, ESTADOS_MESA, true)) { fallar('Estado de mesa no válido.', 422); }
        $b['estado'] = $estadoNuevo;
    }
    en_transaccion(function ($pdo) use ($id, $b, $estadoNuevo) {
        if ($estadoNuevo !== null && $estadoNuevo !== 'ocupada') {
            liberar_mesa($pdo, $id, $estadoNuevo);   // 409 si hay cuenta con consumo
        }
        $campos = array('numero_mesa' => 'str', 'numero' => 'str', 'capacidad' => 'int', 'id_area' => 'int',
                        'estado' => 'str', 'pos_x' => 'int', 'pos_y' => 'int', 'grupo_union' => 'int');
        $n = actualizar_campos('mesas', 'id_mesa', $id, $campos, $b);
        if ($n === 0) { fallar('Mesa no encontrada.', 404); }
    });
    responder(mesa_por_id($id));
}

// ---------------------------------------------------------------- DELETE
if ($metodo === 'DELETE') {
    exigir_admin();
    if (!$id) { fallar('Falta el id de la mesa.', 422); }
    if (orden_abierta_mesa($pdo, $id)) {
        fallar('La mesa tiene una cuenta abierta; no se puede eliminar.', 409);
    }
    try {
        $pdo->prepare("DELETE FROM public.mesas WHERE id_mesa = :id")->execute(array(':id' => $id));
    } catch (PDOException $e) {
        if ((string)$e->getCode() === '23503') {
            fallar('La mesa tiene historial de órdenes y no se puede eliminar.', 409);
        }
        throw $e;
    }
    responder(array('id' => $id));
}

fallar('Método no permitido.', 405);
