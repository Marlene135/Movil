<?php
/**
 * login.php - Valida el PIN y entrega un token de sesión.
 * Respuesta correcta: {"status":"ok","usuario":{id,nombre,rol,activo},"token":"..."}
 * Se mantiene en la raíz (/KDS/login.php) para no romper la URL que ya usaba la app.
 */
require __DIR__ . '/api/config.php';

try {
    $data = cuerpo();
    $pin = trim((string)(isset($data['pin']) ? $data['pin'] : ''));
    $pdo = db();

    if ($pin === '') {
        // Sin PIN: solo comprueba que la conexión a PostgreSQL funciona (útil para diagnóstico)
        responder(array('mensaje' => 'Conexión a PostgreSQL exitosa, pero no se envió PIN por POST.'));
    }

    $st = $pdo->prepare("SELECT id, nombre, rol, activo
                           FROM public.usuarios
                          WHERE (TRIM(pin) = :pin OR TRIM(pin_acceso) = :pin) AND activo = true
                          ORDER BY id
                          LIMIT 1");
    $st->execute(array(':pin' => $pin));
    $usuario = $st->fetch();

    if (!$usuario) {
        fallar('PIN incorrecto o usuario inactivo.', 401);
    }

    // Limpia sesiones vencidas y crea una nueva
    $pdo->exec("DELETE FROM public.api_tokens WHERE expira_en < CURRENT_TIMESTAMP");
    $token = bin2hex(random_bytes(32));
    $horas = (int)kds_config('token_horas');
    $pdo->prepare("INSERT INTO public.api_tokens (token_hash, id_usuario, expira_en)
                   VALUES (:h, :u, CURRENT_TIMESTAMP + (CAST(:hrs AS integer) * INTERVAL '1 hour'))")
        ->execute(array(':h' => hash('sha256', $token), ':u' => $usuario['id'], ':hrs' => $horas));

    // Respuesta compatible con la versión anterior (status + usuario) más el token
    http_response_code(200);
    echo json_encode(array('status' => 'ok', 'usuario' => $usuario, 'token' => $token),
                     JSON_UNESCAPED_UNICODE);
} catch (ApiError $e) {
    http_response_code($e->http);
    echo json_encode(array('status' => 'error', 'message' => $e->getMessage()), JSON_UNESCAPED_UNICODE);
}
