<?php
require __DIR__ . '/config.php';
require __DIR__ . '/ordenes_lib.php';
$u = usuario_actual();
$pdo = db();
$metodo = $_SERVER['REQUEST_METHOD'];

// ---------------------------------------------------------------- GET
// ?estacion=cocina|barra  (sin parámetro = todas). Solo platillos activos de cuentas abiertas.
if ($metodo === 'GET') {
    $params = array();
    $filtro = '';
    if (isset($_GET['estacion']) && in_array($_GET['estacion'], array('cocina', 'barra'), true)) {
        $filtro = ' AND d.estacion = :e';
        $params[':e'] = $_GET['estacion'];
    }
    responder(q(
        "SELECT d.id_detalle, d.id_orden, o.folio,
                COALESCE(m.numero_mesa, m.numero, '-') AS mesa,
                d.nombre_producto AS nombre, d.cantidad, d.notas, d.estado, d.estacion, d.enviado_en,
                GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - COALESCE(d.enviado_en, o.creado_en))) / 60))::int AS minutos
           FROM public.orden_detalle d
           JOIN public.ordenes o ON o.id_orden = d.id_orden
           LEFT JOIN public.mesas m ON m.id_mesa = o.id_mesa
          WHERE upper(o.estado) = 'ABIERTA'
            AND d.estado IN ('PENDIENTE', 'EN_PREPARACION', 'LISTO') $filtro
          ORDER BY COALESCE(d.enviado_en, o.creado_en), d.id_detalle", $params)->fetchAll());
}

// ------------------------------------------- POST ?accion=estado
// {"ids":[5,6],"estado":"EN_PREPARACION"}
if ($metodo === 'POST' && isset($_GET['accion']) && $_GET['accion'] === 'estado') {
    $b = cuerpo();
    $ids = isset($b['ids']) && is_array($b['ids']) ? array_values(array_unique(array_map('intval', $b['ids']))) : array();
    $estado = strtoupper(trim((string)(isset($b['estado']) ? $b['estado'] : '')));
    if (count($ids) === 0) { fallar('No hay platillos seleccionados.', 422); }
    if (!in_array($estado, array('PENDIENTE', 'EN_PREPARACION', 'LISTO', 'ENTREGADO'), true)) {
        fallar('Estado no válido.', 422);
    }
    $extra = '';
    if ($estado === 'EN_PREPARACION') {
        $extra = ', iniciado_en = COALESCE(iniciado_en, CURRENT_TIMESTAMP), listo_en = NULL, entregado_en = NULL';
    } elseif ($estado === 'LISTO') {
        $extra = ', iniciado_en = COALESCE(iniciado_en, CURRENT_TIMESTAMP), listo_en = CURRENT_TIMESTAMP, entregado_en = NULL';
    } elseif ($estado === 'ENTREGADO') {
        $extra = ', listo_en = COALESCE(listo_en, CURRENT_TIMESTAMP), entregado_en = CURRENT_TIMESTAMP';
    } else {
        $extra = ', iniciado_en = NULL, listo_en = NULL, entregado_en = NULL';
    }
    $marcas = implode(',', array_fill(0, count($ids), '?'));
    $st = $pdo->prepare(
        "UPDATE public.orden_detalle SET estado = ? $extra
          WHERE id_detalle IN ($marcas) AND estado <> 'CANCELADO'
            AND id_orden IN (SELECT id_orden FROM public.ordenes WHERE upper(estado) = 'ABIERTA')");
    $st->execute(array_merge(array($estado), $ids));
    responder(array('actualizados' => $st->rowCount()));
}

fallar('Método no permitido.', 405);
