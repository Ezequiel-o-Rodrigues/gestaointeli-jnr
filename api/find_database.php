<?php
echo "=== PROCURANDO DATABASE.PHP ===\n";

$paths = [
    __DIR__ . '/../../config/database.php',
    __DIR__ . '/../../../config/database.php', 
    __DIR__ . '/../../../../config/database.php',
    __DIR__ . '/../config/database.php',
    __DIR__ . '/config/database.php',
    'C:/xampp/htdocs/config/database.php'
];

foreach ($paths as $path) {
    echo "Verificando: $path -> ";
    if (file_exists($path)) {
        echo "ENCONTRADO!\n";
        // Testar se funciona
        try {
            require_once $path;
            $database = new Database();
            $db = $database->getConnection();
            echo "✅ Conexão funcionou!\n";
        } catch (Exception $e) {
            echo "❌ Erro na conexão: " . $e->getMessage() . "\n";
        }
        break;
    } else {
        echo "Não encontrado\n";
    }
}

// Listar diretórios
echo "\n=== ESTRUTURA DE DIRETÓRIOS ===\n";
function listDir($dir, $level = 0) {
    if (!is_dir($dir)) return;
    $items = scandir($dir);
    foreach ($items as $item) {
        if ($item == '.' || $item == '..') continue;
        $path = $dir . '/' . $item;
        echo str_repeat('  ', $level) . $item . "\n";
        if (is_dir($path) && $level < 3) {
            listDir($path, $level + 1);
        }
    }
}

listDir('C:/xampp/htdocs/gestaointeli-jnr');
?>