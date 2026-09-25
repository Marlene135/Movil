<?php
// Permitir cualquier origen
if (isset($_SERVER['HTTP_ORIGIN'])) {
    header("Access-Control-Allow-Origin: {$_SERVER['HTTP_ORIGIN']}");
    header('Access-Control-Allow-Credentials: true');
    header('Access-Control-Max-Age: 86400');
}

// Atender peticiones preflight de CORS (OPTIONS)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    if (isset($_SERVER['HTTP_ACCESS_CONTROL_REQUEST_METHOD'])) {
        header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
    }
    if (isset($_SERVER['HTTP_ACCESS_CONTROL_REQUEST_HEADERS'])) {
        header("Access-Control-Allow-Headers: {$_SERVER['HTTP_ACCESS_CONTROL_REQUEST_HEADERS']}");
    }
    http_response_code(200);
    exit(0);
}

header("Content-Type: application/json; charset=UTF-8");

$input = file_get_contents("php://input");
$data = json_decode($input, true);
$pin = $data['pin'] ?? '';

// Conexión PostgreSQL
$host = "127.0.0.1";
$port = "5432";
$dbname = "sazontrack_db";
$user = "postgres";
$password = "tu_contraseña_aqui"; // Tu contraseña de postgres

try {
    $dsn = "pgsql:host=$host;port=$port;dbname=$dbname;";
    $pdo = new PDO($dsn, $user, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]);

    $stmt = $pdo->prepare("SELECT id, nombre, rol, activo FROM usuarios WHERE pin = :pin AND activo = true LIMIT 1");
    $stmt->execute(['pin' => $pin]);
    $usuario = $stmt->fetch();

    if ($usuario) {
        echo json_encode(["status" => "ok", "usuario" => $usuario]);
    } else {
        echo json_encode(["status" => "error", "message" => "PIN incorrecto"]);
    }
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
}