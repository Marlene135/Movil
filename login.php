<?php
// Mostrar todos los errores de PHP en pantalla
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$input = file_get_contents("php://input");
$data = json_decode($input, true);
$pin = trim((string)($data['pin'] ?? ''));

$host = "127.0.0.1";
$port = "5432";
$dbname = "sazontrack_db";
$user = "postgres";
$password = "123456789"; // <-- VERIFICA TU CONTRASEÑA REAL AQUÍ

try {
    $dsn = "pgsql:host=$host;port=$port;dbname=$dbname;";
    $pdo = new PDO($dsn, $user, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]);

    if (empty($pin)) {
        echo json_encode([
            "status" => "ok_conexion",
            "message" => "Conexión a PostgreSQL exitosa, pero no se envió PIN por POST."
        ]);
        exit();
    }

    $stmt = $pdo->prepare("SELECT id, nombre, rol, activo FROM public.usuarios WHERE (TRIM(pin) = :pin OR TRIM(pin_acceso) = :pin) AND activo = true LIMIT 1");
    $stmt->execute(['pin' => $pin]);
    $usuario = $stmt->fetch();

    if ($usuario) {
        echo json_encode(["status" => "ok", "usuario" => $usuario]);
    } else {
        echo json_encode(["status" => "error", "message" => "PIN incorrecto"]);
    }
} catch (Exception $e) {
    http_response_code(200); // Forzar 200 para ver el texto en el navegador
    echo json_encode([
        "status" => "error_bd",
        "error_tipo" => get_class($e),
        "mensaje" => $e->getMessage()
    ]);
}
?>