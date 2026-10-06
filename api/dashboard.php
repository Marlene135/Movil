<?php
require __DIR__ . '/config.php';
$u = usuario_actual();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    fallar('Método no permitido.', 405);
}

// Platillos en cuentas abiertas, por estado
$estados = array(
    'PENDIENTE'      => array('platillos' => 0, 'comandas' => 0),
    'EN_PREPARACION' => array('platillos' => 0, 'comandas' => 0),
    'LISTO'          => array('platillos' => 0, 'comandas' => 0),
);
$filas = q("SELECT d.estado, COALESCE(SUM(d.cantidad), 0) AS platillos, COUNT(DISTINCT d.id_orden) AS comandas
              FROM public.orden_detalle d
              JOIN public.ordenes o ON o.id_orden = d.id_orden
             WHERE upper(o.estado) = 'ABIERTA' AND d.estado IN ('PENDIENTE', 'EN_PREPARACION', 'LISTO')
             GROUP BY d.estado")->fetchAll();
foreach ($filas as $f) {
    $estados[$f['estado']] = array('platillos' => (int)$f['platillos'], 'comandas' => (int)$f['comandas']);
}

// Mesas por estado
$mesas = array('total' => 0, 'disponibles' => 0, 'ocupadas' => 0, 'por_limpiar' => 0, 'reservadas' => 0);
$filas = q("SELECT CASE WHEN lower(COALESCE(estado, 'disponible')) = 'libre' THEN 'disponible'
                        ELSE lower(COALESCE(estado, 'disponible')) END AS estado, COUNT(*) AS n
              FROM public.mesas GROUP BY 1")->fetchAll();
foreach ($filas as $f) {
    $n = (int)$f['n'];
    $mesas['total'] += $n;
    if ($f['estado'] === 'disponible') { $mesas['disponibles'] += $n; }
    elseif ($f['estado'] === 'ocupada') { $mesas['ocupadas'] += $n; }
    elseif ($f['estado'] === 'por_limpiar') { $mesas['por_limpiar'] += $n; }
    elseif ($f['estado'] === 'reservada') { $mesas['reservadas'] += $n; }
}

$reservasHoy = (int)q("SELECT COUNT(*) FROM public.reservas
                        WHERE fecha_reserva = CURRENT_DATE AND lower(estado) NOT IN ('cancelada', 'completada')")->fetchColumn();
$ventasHoy = round((float)q("SELECT COALESCE(SUM(total), 0) FROM public.ordenes
                              WHERE upper(estado) = 'PAGADA' AND cerrado_en::date = CURRENT_DATE")->fetchColumn(), 2);
$abiertas = (int)q("SELECT COUNT(*) FROM public.ordenes WHERE upper(estado) = 'ABIERTA'")->fetchColumn();
$prod = q("SELECT COUNT(*) AS total, COUNT(*) FILTER (WHERE COALESCE(disponible, 1) <> 0) AS disponibles
             FROM public.productos WHERE COALESCE(activo, true) AND COALESCE(activo_pos, true)")->fetch();

responder(array(
    'pendientes'     => $estados['PENDIENTE'],
    'preparacion'    => $estados['EN_PREPARACION'],
    'listos'         => $estados['LISTO'],
    'mesas'          => $mesas,
    'reservas_hoy'   => $reservasHoy,
    'ventas_hoy'     => $ventasHoy,
    'ordenes_abiertas' => $abiertas,
    'productos'      => array('total' => (int)$prod['total'], 'disponibles' => (int)$prod['disponibles']),
));
