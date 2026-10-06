<?php
require __DIR__ . '/config.php';
require __DIR__ . '/ordenes_lib.php';
$u = usuario_actual();
$pdo = db();
$metodo = $_SERVER['REQUEST_METHOD'];
$accion = isset($_GET['accion']) ? $_GET['accion'] : '';

const METODOS_PAGO = array('EFECTIVO', 'TARJETA_CREDITO', 'TARJETA_DEBITO', 'TRANSFERENCIA');

// ---------------------------------------------------------------- GET
// ?id_mesa=N  -> orden abierta de la mesa (o null) con sus platillos
// ?id_orden=N -> una orden concreta
if ($metodo === 'GET') {
    if (isset($_GET['id_mesa'])) {
        $o = orden_abierta_mesa($pdo, (int)$_GET['id_mesa']);
        responder($o ? cargar_orden($pdo, (int)$o['id_orden']) : null);
    }
    if (isset($_GET['id_orden'])) {
        $o = cargar_orden($pdo, (int)$_GET['id_orden']);
        if (!$o) { fallar('Orden no encontrada.', 404); }
        responder($o);
    }
    fallar('Indica id_mesa o id_orden.', 422);
}

if ($metodo !== 'POST') {
    fallar('Método no permitido.', 405);
}
$b = cuerpo();

// ------------------------------------------- POST ?accion=abrir
// Asigna la mesa a un grupo de comensales: abre la cuenta y marca la mesa como ocupada.
if ($accion === 'abrir') {
    $idMesa = param_int($b, 'id_mesa');
    $com = max(1, (int)(isset($b['comensales']) ? $b['comensales'] : 1));
    $idOrden = en_transaccion(function ($pdo) use ($idMesa, $com, $u) {
        $ok = $pdo->prepare("SELECT 1 FROM public.mesas WHERE id_mesa = :m FOR UPDATE");
        $ok->execute(array(':m' => $idMesa));
        if (!$ok->fetchColumn()) { fallar('La mesa no existe.', 404); }
        $o = orden_abierta_mesa($pdo, $idMesa, true);
        if ($o) {
            $pdo->prepare("UPDATE public.ordenes SET comensales = :c WHERE id_orden = :id")
                ->execute(array(':c' => $com, ':id' => $o['id_orden']));
            $idOrden = (int)$o['id_orden'];
        } else {
            $idOrden = crear_orden($pdo, $idMesa, (int)$u['id'], $com);
        }
        $pdo->prepare("UPDATE public.mesas SET estado = 'ocupada' WHERE id_mesa = :m")
            ->execute(array(':m' => $idMesa));
        return $idOrden;
    });
    responder(cargar_orden($pdo, $idOrden), 201);
}

// ------------------------------------------- POST ?accion=enviar
// Envía una comanda a cocina/barra: {"id_mesa":1,"comensales":2,"items":[{"id_producto":1,"cantidad":2,"notas":""}]}
if ($accion === 'enviar') {
    $idMesa = param_int($b, 'id_mesa');
    $items = isset($b['items']) ? $b['items'] : array();
    if (!is_array($items) || count($items) === 0) { fallar('La comanda no tiene productos.', 422); }

    $idOrden = en_transaccion(function ($pdo) use ($idMesa, $items, $b, $u) {
        $ok = $pdo->prepare("SELECT 1 FROM public.mesas WHERE id_mesa = :m FOR UPDATE");
        $ok->execute(array(':m' => $idMesa));
        if (!$ok->fetchColumn()) { fallar('La mesa no existe.', 404); }

        $o = orden_abierta_mesa($pdo, $idMesa, true);
        $idOrden = $o ? (int)$o['id_orden']
                      : crear_orden($pdo, $idMesa, (int)$u['id'], isset($b['comensales']) ? $b['comensales'] : 1);

        $prod = $pdo->prepare(
            "SELECT p.id_producto, p.nombre, p.precio,
                    (COALESCE(p.activo, true) AND COALESCE(p.activo_pos, true)
                     AND COALESCE(p.disponible, 1) <> 0) AS vendible,
                    COALESCE(c.estacion, 'cocina') AS estacion
               FROM public.productos p
               LEFT JOIN public.categorias c ON c.id_categoria = p.id_categoria
              WHERE p.id_producto = :id");
        $ins = $pdo->prepare(
            "INSERT INTO public.orden_detalle
                (id_orden, id_producto, nombre_producto, cantidad, precio_unitario, notas, estacion, estado)
             VALUES (:o, :p, :n, :c, :pr, :no, :e, 'PENDIENTE')");

        foreach ($items as $it) {
            $idProd = param_int($it, 'id_producto');
            $cant = (int)(isset($it['cantidad']) ? $it['cantidad'] : 1);
            if ($cant < 1 || $cant > 99) { fallar('La cantidad debe estar entre 1 y 99.', 422); }
            $prod->execute(array(':id' => $idProd));
            $p = $prod->fetch();
            if (!$p) { fallar('Un producto de la comanda ya no existe.', 422); }
            $vendible = in_array($p['vendible'], array(true, 't', '1', 1), true);
            if (!$vendible) { fallar('"' . $p['nombre'] . '" no está disponible.', 422); }
            $ins->execute(array(
                ':o' => $idOrden, ':p' => $idProd, ':n' => $p['nombre'], ':c' => $cant,
                ':pr' => $p['precio'], ':no' => texto($it, 'notas', 200), ':e' => $p['estacion'],
            ));
        }
        recalcular_orden($pdo, $idOrden);
        $pdo->prepare("UPDATE public.mesas SET estado = 'ocupada' WHERE id_mesa = :m")
            ->execute(array(':m' => $idMesa));
        return $idOrden;
    });
    responder(cargar_orden($pdo, $idOrden), 201);
}

// ------------------------------------------- POST ?accion=cancelar_item
if ($accion === 'cancelar_item') {
    $idDet = param_int($b, 'id_detalle');
    $idOrden = en_transaccion(function ($pdo) use ($idDet, $u) {
        $st = $pdo->prepare("SELECT d.id_orden, d.estado, o.estado AS estado_orden
                               FROM public.orden_detalle d JOIN public.ordenes o ON o.id_orden = d.id_orden
                              WHERE d.id_detalle = :id FOR UPDATE OF d");
        $st->execute(array(':id' => $idDet));
        $d = $st->fetch();
        if (!$d) { fallar('El platillo no existe.', 404); }
        if (strtoupper($d['estado_orden']) !== 'ABIERTA') { fallar('La cuenta ya está cerrada.', 409); }
        if ($d['estado'] !== 'PENDIENTE' && !es_caja($u)) {
            fallar('El platillo ya está en preparación; solo caja o administración puede cancelarlo.', 403);
        }
        $pdo->prepare("UPDATE public.orden_detalle SET estado = 'CANCELADO' WHERE id_detalle = :id")
            ->execute(array(':id' => $idDet));
        recalcular_orden($pdo, (int)$d['id_orden']);
        return (int)$d['id_orden'];
    });
    responder(cargar_orden($pdo, $idOrden));
}

// ------------------------------------------- POST ?accion=cancelar_orden
if ($accion === 'cancelar_orden') {
    $idOrden = param_int($b, 'id_orden');
    en_transaccion(function ($pdo) use ($idOrden, $u) {
        $st = $pdo->prepare("SELECT id_orden, id_mesa, estado FROM public.ordenes WHERE id_orden = :id FOR UPDATE");
        $st->execute(array(':id' => $idOrden));
        $o = $st->fetch();
        if (!$o) { fallar('La orden no existe.', 404); }
        if (strtoupper($o['estado']) !== 'ABIERTA') { fallar('La cuenta ya está cerrada.', 409); }
        $n = $pdo->prepare("SELECT COUNT(*) FROM public.orden_detalle WHERE id_orden = :id AND estado <> 'CANCELADO'");
        $n->execute(array(':id' => $idOrden));
        if ((int)$n->fetchColumn() > 0 && !es_caja($u)) {
            fallar('Solo caja o administración puede cancelar una cuenta con consumo.', 403);
        }
        $pdo->prepare("UPDATE public.orden_detalle SET estado = 'CANCELADO' WHERE id_orden = :id AND estado <> 'CANCELADO'")
            ->execute(array(':id' => $idOrden));
        $pdo->prepare("UPDATE public.ordenes SET estado = 'CANCELADA', subtotal = 0, total = 0, cerrado_en = CURRENT_TIMESTAMP
                        WHERE id_orden = :id")->execute(array(':id' => $idOrden));
        if ($o['id_mesa']) {
            $pdo->prepare("UPDATE public.mesas SET estado = 'disponible', grupo_union = NULL WHERE id_mesa = :m")
                ->execute(array(':m' => $o['id_mesa']));
        }
    });
    responder(array('id_orden' => $idOrden));
}

// ------------------------------------------- POST ?accion=pagar
// {"ids_orden":[1,2],"metodo_pago":"EFECTIVO","monto_recibido":500,"propina":20}
// Varias órdenes = mesas unidas que pagan juntas.
if ($accion === 'pagar') {
    $ids = isset($b['ids_orden']) && is_array($b['ids_orden']) ? array_values(array_unique(array_map('intval', $b['ids_orden']))) : array();
    if (count($ids) === 0) { fallar('No hay cuentas por cobrar.', 422); }
    $metodoPago = strtoupper(trim((string)(isset($b['metodo_pago']) ? $b['metodo_pago'] : '')));
    if (!in_array($metodoPago, METODOS_PAGO, true)) { fallar('Método de pago no válido.', 422); }
    $propina = round(max(0, (float)(isset($b['propina']) ? $b['propina'] : 0)), 2);

    $resultado = en_transaccion(function ($pdo) use ($ids, $metodoPago, $propina, $b, $u) {
        $turno = turno_abierto($pdo, (int)$u['id'], true);
        $ordenes = array();
        $totalGlobal = 0.0;
        foreach ($ids as $idOrden) {
            $st = $pdo->prepare("SELECT id_orden, id_mesa, estado FROM public.ordenes WHERE id_orden = :id FOR UPDATE");
            $st->execute(array(':id' => $idOrden));
            $o = $st->fetch();
            if (!$o) { fallar("La orden $idOrden no existe.", 404); }
            if (strtoupper($o['estado']) !== 'ABIERTA') { fallar('Una de las cuentas ya fue cobrada o cancelada.', 409); }
            recalcular_orden($pdo, $idOrden);
            $t = $pdo->prepare("SELECT folio, total FROM public.ordenes WHERE id_orden = :id");
            $t->execute(array(':id' => $idOrden));
            $fila = $t->fetch();
            $o['total'] = round((float)$fila['total'], 2);
            $o['folio'] = $fila['folio'];
            $totalGlobal += $o['total'];
            $ordenes[] = $o;
        }
        $totalGlobal = round($totalGlobal, 2);
        if ($totalGlobal <= 0) { fallar('La cuenta no tiene consumo. Usa "Liberar mesa" o cancela la cuenta.', 422); }

        $recibido = ($metodoPago === 'EFECTIVO')
            ? round((float)(isset($b['monto_recibido']) ? $b['monto_recibido'] : 0), 2)
            : $totalGlobal;
        if ($recibido + 0.001 < $totalGlobal) { fallar('El monto recibido es menor al total de la cuenta.', 422); }
        $cambio = round($recibido - $totalGlobal, 2);

        $pago = $pdo->prepare(
            "INSERT INTO public.pagos (id_orden, id_turno, metodo_pago, monto, monto_recibido, cambio, propina, referencia)
             VALUES (:o, :t, :m, :monto, :rec, :cam, :prop, :ref)");
        $cierre = $pdo->prepare("UPDATE public.ordenes SET estado = 'PAGADA', cerrado_en = CURRENT_TIMESTAMP,
                                        id_turno = COALESCE(id_turno, :t) WHERE id_orden = :id");
        $entrega = $pdo->prepare("UPDATE public.orden_detalle SET estado = 'ENTREGADO',
                                         entregado_en = COALESCE(entregado_en, CURRENT_TIMESTAMP)
                                   WHERE id_orden = :id AND estado NOT IN ('CANCELADO', 'ENTREGADO')");
        $grupoSel = $pdo->prepare("SELECT grupo_union FROM public.mesas WHERE id_mesa = :m");
        $libera = $pdo->prepare("UPDATE public.mesas SET estado = 'disponible', grupo_union = NULL
                                  WHERE id_mesa = :m OR (CAST(:g AS integer) IS NOT NULL AND grupo_union = CAST(:g2 AS integer))");

        $ultimo = count($ordenes) - 1;
        foreach ($ordenes as $i => $o) {
            $esUltimo = ($i === $ultimo);
            $pago->execute(array(
                ':o' => $o['id_orden'], ':t' => $turno, ':m' => $metodoPago, ':monto' => $o['total'],
                ':rec' => $esUltimo ? round($o['total'] + $cambio, 2) : $o['total'],
                ':cam' => $esUltimo ? $cambio : 0,
                ':prop' => ($i === 0) ? $propina : 0,
                ':ref' => isset($b['referencia']) ? texto($b, 'referencia', 100) : null,
            ));
            $cierre->execute(array(':t' => $turno, ':id' => $o['id_orden']));
            $entrega->execute(array(':id' => $o['id_orden']));
            if ($o['id_mesa']) {
                $grupoSel->execute(array(':m' => $o['id_mesa']));
                $g = $grupoSel->fetchColumn();
                $g = ($g === false || $g === null) ? null : (int)$g;
                $libera->execute(array(':m' => $o['id_mesa'], ':g' => $g, ':g2' => $g));
            }
        }
        return array('total' => $totalGlobal, 'cambio' => $cambio, 'propina' => $propina,
                     'folios' => array_map(function ($o) { return $o['folio']; }, $ordenes));
    });
    responder($resultado);
}

fallar('Acción no válida.', 400);
