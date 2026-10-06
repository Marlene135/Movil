<?php
/** Funciones compartidas para trabajar con órdenes. Requiere config.php. */

/** Orden ABIERTA de una mesa (o false). */
function orden_abierta_mesa($pdo, $idMesa, $bloquear = false)
{
    $sql = "SELECT * FROM public.ordenes
             WHERE id_mesa = :m AND upper(estado) = 'ABIERTA'
             ORDER BY id_orden DESC LIMIT 1" . ($bloquear ? ' FOR UPDATE' : '');
    $st = $pdo->prepare($sql);
    $st->execute(array(':m' => $idMesa));
    return $st->fetch();
}

/** Recalcula subtotal/total a partir de los platillos no cancelados. */
function recalcular_orden($pdo, $idOrden)
{
    $st = $pdo->prepare(
        "UPDATE public.ordenes o
            SET subtotal = s.t, total = GREATEST(s.t - o.descuento, 0)
           FROM (SELECT COALESCE(SUM(cantidad * precio_unitario), 0) AS t
                   FROM public.orden_detalle
                  WHERE id_orden = :id AND estado <> 'CANCELADO') s
          WHERE o.id_orden = :id2");
    $st->execute(array(':id' => $idOrden, ':id2' => $idOrden));
}

function items_orden($pdo, $idOrden)
{
    $st = $pdo->prepare(
        "SELECT id_detalle, id_producto, nombre_producto AS nombre, cantidad,
                precio_unitario AS precio, notas, estado, estacion, enviado_en
           FROM public.orden_detalle
          WHERE id_orden = :id AND estado <> 'CANCELADO'
          ORDER BY id_detalle");
    $st->execute(array(':id' => $idOrden));
    return $st->fetchAll();
}

/** Orden + sus platillos, lista para la app. */
function cargar_orden($pdo, $idOrden)
{
    $st = $pdo->prepare(
        "SELECT id_orden, folio, id_mesa, id_usuario, subtotal, descuento, total,
                estado, comensales, creado_en
           FROM public.ordenes WHERE id_orden = :id");
    $st->execute(array(':id' => $idOrden));
    $o = $st->fetch();
    if (!$o) {
        return null;
    }
    $o['items'] = items_orden($pdo, $idOrden);
    return $o;
}

/** Crea una orden vacía para la mesa y devuelve su id. */
function crear_orden($pdo, $idMesa, $idUsuario, $comensales)
{
    $id = (int)$pdo->query("SELECT nextval(pg_get_serial_sequence('public.ordenes','id_orden'))")->fetchColumn();
    $folio = sprintf('ORD-%s-%03d', date('Y'), $id);
    $turno = turno_abierto($pdo, $idUsuario, false);
    $st = $pdo->prepare(
        "INSERT INTO public.ordenes
            (id_orden, folio, id_mesa, id_usuario, id_turno, subtotal, descuento, total, estado, comensales)
         VALUES (:id, :f, :m, :u, :t, 0, 0, 0, 'ABIERTA', :c)");
    $st->execute(array(
        ':id' => $id, ':f' => $folio, ':m' => $idMesa, ':u' => $idUsuario,
        ':t' => $turno, ':c' => max(1, (int)$comensales),
    ));
    return $id;
}

/**
 * Turno de caja abierto: primero el del usuario, luego cualquiera abierto.
 * Si $crear es true y no hay ninguno, abre uno nuevo (fondo 0).
 */
function turno_abierto($pdo, $idUsuario, $crear)
{
    $st = $pdo->prepare("SELECT id_turno FROM public.turnos_caja
                          WHERE lower(estado) = 'abierto' AND id_empleado = :u
                          ORDER BY id_turno DESC LIMIT 1");
    $st->execute(array(':u' => $idUsuario));
    $id = $st->fetchColumn();
    if ($id) {
        return (int)$id;
    }
    $id = $pdo->query("SELECT id_turno FROM public.turnos_caja
                        WHERE lower(estado) = 'abierto'
                        ORDER BY id_turno DESC LIMIT 1")->fetchColumn();
    if ($id) {
        return (int)$id;
    }
    if (!$crear) {
        return null;
    }
    $st = $pdo->prepare("INSERT INTO public.turnos_caja (id_empleado, fondo_inicial, estado)
                         VALUES (:u, 0, 'abierto') RETURNING id_turno");
    $st->execute(array(':u' => $idUsuario));
    return (int)$st->fetchColumn();
}

/**
 * Libera una mesa. Si tiene una cuenta abierta con consumo lanza 409;
 * si la orden está vacía, la cancela.
 */
function liberar_mesa($pdo, $idMesa, $estadoNuevo)
{
    $o = orden_abierta_mesa($pdo, $idMesa, true);
    if ($o) {
        $n = $pdo->prepare("SELECT COUNT(*) FROM public.orden_detalle
                             WHERE id_orden = :id AND estado <> 'CANCELADO'");
        $n->execute(array(':id' => $o['id_orden']));
        if ((int)$n->fetchColumn() > 0) {
            fallar('La mesa tiene una cuenta abierta. Cóbrala o cancélala primero.', 409);
        }
        $pdo->prepare("UPDATE public.ordenes SET estado = 'CANCELADA', cerrado_en = CURRENT_TIMESTAMP
                        WHERE id_orden = :id")->execute(array(':id' => $o['id_orden']));
    }
    $pdo->prepare("UPDATE public.mesas SET estado = :e, grupo_union = NULL WHERE id_mesa = :m")
        ->execute(array(':e' => $estadoNuevo, ':m' => $idMesa));
}
