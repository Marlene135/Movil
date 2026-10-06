<?php
require __DIR__ . '/config.php';
$u = usuario_actual();
$metodo = $_SERVER['REQUEST_METHOD'];
$id = isset($_GET['id']) ? (int)$_GET['id'] : 0;

const SELECT_PRODUCTO = "SELECT p.id_producto AS id, p.nombre, COALESCE(p.descripcion, '') AS descripcion,
        p.precio, p.id_categoria, c.nombre AS categoria, COALESCE(c.estacion, 'cocina') AS estacion,
        (COALESCE(p.activo, true) AND COALESCE(p.activo_pos, true)) AS activo,
        (COALESCE(p.disponible, 1) <> 0) AS disponible,
        COALESCE(p.tiempo_preparacion_min, 15) AS tiempo_preparacion_min,
        COALESCE(p.costo, 0) AS costo
   FROM public.productos p
   LEFT JOIN public.categorias c ON c.id_categoria = p.id_categoria";

if ($metodo === 'GET') {
    // ?todos=1 incluye los desactivados (pantalla de administración)
    $where = (isset($_GET['todos']) && $_GET['todos'] === '1')
        ? '' : 'WHERE COALESCE(p.activo, true) = true AND COALESCE(p.activo_pos, true) = true';
    responder(q(SELECT_PRODUCTO . " $where ORDER BY COALESCE(c.orden, 0), c.nombre, COALESCE(p.orden, 0), p.nombre")->fetchAll());
}

exigir_admin();
$b = cuerpo();

if ($metodo === 'POST') {
    $nombre = texto($b, 'nombre', 100);
    if ($nombre === '') { fallar('Escribe el nombre del producto.', 422); }
    if (!isset($b['precio']) || !is_numeric($b['precio']) || (float)$b['precio'] < 0) {
        fallar('Escribe un precio válido.', 422);
    }
    $cat = param_int($b, 'id_categoria', false);
    if ($cat !== null) {
        $ok = q("SELECT 1 FROM public.categorias WHERE id_categoria = :c", array(':c' => $cat))->fetchColumn();
        if (!$ok) { fallar('La categoría no existe.', 422); }
    }
    $disp = (!isset($b['disponible']) || pgbool($b['disponible']) === 't') ? 1 : 0;
    $nuevoId = q("INSERT INTO public.productos
                    (id_categoria, nombre, precio, descripcion, activo, activo_pos, disponible,
                     tiempo_preparacion_min, tiempo_estimado_min, costo)
                  VALUES (:c, :n, :p, :d, true, true, :disp, :t, :t2, :costo)
                  RETURNING id_producto",
        array(':c' => $cat, ':n' => $nombre, ':p' => round((float)$b['precio'], 2),
              ':d' => texto($b, 'descripcion', 500), ':disp' => $disp,
              ':t' => max(1, (int)(isset($b['tiempo_preparacion_min']) ? $b['tiempo_preparacion_min'] : 15)),
              ':t2' => max(1, (int)(isset($b['tiempo_preparacion_min']) ? $b['tiempo_preparacion_min'] : 15)),
              ':costo' => round((float)(isset($b['costo']) ? $b['costo'] : 0), 2)))->fetchColumn();
    responder(q(SELECT_PRODUCTO . ' WHERE p.id_producto = :id', array(':id' => $nuevoId))->fetch(), 201);
}

if ($metodo === 'PUT') {
    if (!$id) { fallar('Falta el id del producto.', 422); }
    if (isset($b['nombre']) && trim((string)$b['nombre']) === '') { fallar('El nombre no puede estar vacío.', 422); }
    if (isset($b['precio']) && (!is_numeric($b['precio']) || (float)$b['precio'] < 0)) {
        fallar('Escribe un precio válido.', 422);
    }
    if (array_key_exists('activo', $b)) { $b['activo_pos'] = $b['activo']; }
    if (array_key_exists('disponible', $b)) { $b['disponible'] = pgbool($b['disponible']) === 't' ? 1 : 0; }
    $n = actualizar_campos('productos', 'id_producto', $id,
        array('nombre' => 'str', 'descripcion' => 'str', 'precio' => 'num', 'id_categoria' => 'int',
              'activo' => 'bool', 'activo_pos' => 'bool', 'disponible' => 'int',
              'tiempo_preparacion_min' => 'int', 'costo' => 'num'), $b);
    if ($n === 0) { fallar('Producto no encontrado.', 404); }
    responder(q(SELECT_PRODUCTO . ' WHERE p.id_producto = :id', array(':id' => $id))->fetch());
}

if ($metodo === 'DELETE') {   // desactivar (se conserva el historial de ventas)
    if (!$id) { fallar('Falta el id del producto.', 422); }
    q("UPDATE public.productos SET activo = false, activo_pos = false WHERE id_producto = :id", array(':id' => $id));
    responder(array('id' => $id));
}

fallar('Método no permitido.', 405);
