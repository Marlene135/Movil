<?php
require __DIR__ . '/config.php';
$u = usuario_actual();
$metodo = $_SERVER['REQUEST_METHOD'];
$id = isset($_GET['id']) ? (int)$_GET['id'] : 0;

if ($metodo === 'GET') {
    responder(q("SELECT id_area AS id, nombre FROM public.areas ORDER BY id_area")->fetchAll());
}

exigir_admin();

if ($metodo === 'POST') {
    $nombre = texto(cuerpo(), 'nombre', 50);
    if ($nombre === '') {
        fallar('Escribe el nombre del área.', 422);
    }
    $dup = q("SELECT 1 FROM public.areas WHERE lower(nombre) = lower(:n)", array(':n' => $nombre))->fetchColumn();
    if ($dup) {
        fallar('Ya existe un área con ese nombre.', 409);
    }
    $nuevo = q("INSERT INTO public.areas (nombre) VALUES (:n) RETURNING id_area AS id, nombre",
               array(':n' => $nombre))->fetch();
    responder($nuevo, 201);
}

if ($metodo === 'PUT') {
    if (!$id) { fallar('Falta el id del área.', 422); }
    $nombre = texto(cuerpo(), 'nombre', 50);
    if ($nombre === '') { fallar('Escribe el nombre del área.', 422); }
    $st = q("UPDATE public.areas SET nombre = :n WHERE id_area = :id", array(':n' => $nombre, ':id' => $id));
    if ($st->rowCount() === 0) { fallar('Área no encontrada.', 404); }
    responder(array('id' => $id, 'nombre' => $nombre));
}

if ($metodo === 'DELETE') {
    if (!$id) { fallar('Falta el id del área.', 422); }
    $n = q("SELECT COUNT(*) FROM public.mesas WHERE id_area = :id", array(':id' => $id))->fetchColumn();
    if ((int)$n > 0) {
        fallar('El área tiene mesas asignadas. Muévelas a otra área antes de eliminarla.', 409);
    }
    q("DELETE FROM public.areas WHERE id_area = :id", array(':id' => $id));
    responder(array('id' => $id));
}

fallar('Método no permitido.', 405);
