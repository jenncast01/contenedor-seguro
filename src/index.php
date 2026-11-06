<?php
$output = "";
$error = "";
if (isset($_GET['host'])) {
    $host = $_GET['host'];
    // MITIGADO: Validacion estricta de IP (impide Command Injection con ; | && $())
    if (filter_var($host, FILTER_VALIDATE_IP)) {
        $output = shell_exec("ping -c 1 " . escapeshellarg($host) . " 2>&1");
    } else {
        http_response_code(400);
        $error = "Alerta de Seguridad: Direccion IP invalida. Intento de inyeccion de comandos bloqueado.";
    }
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Panel de Diagnostico - Servidor Actualizado (Seguro)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f0fff4; color: #333; }
        .box { background: white; padding: 20px; border: 1px solid #9ae6b4; border-radius: 8px; max-width: 700px; }
        pre { background: #1a202c; color: #68d391; padding: 15px; border-radius: 5px; overflow-x: auto; }
        .alert { background: #fed7d7; color: #9b2c2c; padding: 12px; border-radius: 5px; margin-top: 15px; }
        input[type=text] { width: 65%; padding: 8px; }
        button { padding: 8px 16px; background: #38a169; color: white; border: none; border-radius: 4px; cursor: pointer; }
    </style>
</head>
<body>
    <div class="box">
        <h2>Panel de Red - Servidor Endurecido (Ubuntu 24.04)</h2>
        <p>Herramienta de diagnostico Ping (Protegida contra Inyeccion de Comandos):</p>
        <form method="GET">
            <input type="text" name="host" placeholder="Solo direcciones IP validas (ej: 127.0.0.1)" value="<?php echo isset($_GET['host']) ? htmlspecialchars($_GET['host']) : '127.0.0.1'; ?>">
            <button type="submit">Verificar</button>
        </form>
        <?php if ($error): ?>
            <div class="alert"><strong>Bloqueado:</strong> <?php echo htmlspecialchars($error); ?></div>
        <?php endif; ?>
        <?php if ($output): ?>
            <h3>Resultado del comando:</h3>
            <pre><?php echo htmlspecialchars($output); ?></pre>
        <?php endif; ?>
    </div>
</body>
</html>
