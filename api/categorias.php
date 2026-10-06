<?php
require __DIR__ . '/config.php';
$u = usuario_actual();
$metodo = $_SERVER['REQUEST_METHOD'];
$id = isset($_GET['id']) ? (int)$_GET['id'] : 0;

const ESTACIONES = array('cocina', 'barra');

if ($metodo === 'GET') {
    $where = (isset($_GET['todas']) && $_GET['todas'] === '1')
        ? '' : 'WHERE COALESCE(activa, true) = true AND COALESCE(activo, true) = true';
    responder(q("SELECT id_categoria AS id, nombre, COALESCE(estacion, 'cocina') AS estacion,
                        icono, COALESCE(orden, 0) AS orden,
                        (COALESCE(activa, true) AND COALESCE(activo, true)) AS activa
                   FROM public.categorias $where
                  ORDER BY COALESCE(orden, 0), nombre, id_categoria")->fetchAll());
}

exigir_admin();
$b = cuerpo();

if ($metodo === 'POST') {
    $nombre = texto($b, 'nombre', 50);
    if ($nombre === '') { fallar('Escribe el nombre de la categoría.', 422); }
    $est = strtolower(texto($b, 'estacion', 20));
    if (!in_array($est, ESTACIONES, true)) { $est = 'cocina'; }
    $nuevo = q("INSERT INTO public.categorias (nombre, estacion, activo, activa)
                VALUES (:n, :e, true, true)
                RETURNING id_categoria AS id, nombre, estacion, true AS activa",
               array(':n' => $nombre, ':e' => $est))->fetch();
    responder($nuevo, 201);
}

if ($metodo === 'PUT') {
    if (!$id) { fallar('Falta el id de la categoría.', 422); }
    if (isset($b['estacion']) && !in_array(strtolower((string)$b['estacion']), ESTACIONES, true)) {
        fallar('La estación debe ser cocina o barra.', 422);
    }
    if (isset($b['nombre']) && trim((string)$b['nombre']) === '') {
        fallar('El nombre no puede estar vacío.', 422);
    }
    if (array_key_exists('activa', $b)) {   // mantener sincronizadas las dos columnas booleanas
        $b['activo'] = $b['activa'];
    }
    $n = actualizar_campos('categorias', 'id_categoria', $id,
        array('nombre' => 'str', 'estacion' => 'str', 'icono' => 'str', 'orden' => 'int',
              'activa' => 'bool', 'activo' => 'bool'), $b);
    if ($n === 0) { fallar('Categoría no encontrada.', 404); }
    responder(array('id' => $id));
}

if ($metodo === 'DELETE') {   // "eliminar" = ocultar (no se pierde el historial)
    if (!$id) { fallar('Falta el id de la categoría.', 422); }
    q("UPDATE public.categorias SET activa = false, activo = false WHERE id_categoria = :id", array(':id' => $id));
    responder(array('id' => $id));
}

fallar('Método no permitido.', 405);
