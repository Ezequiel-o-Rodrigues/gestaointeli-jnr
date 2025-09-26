<?php
require_once '../config/database.php';

header('Content-Type: application/json');

if (!isset($_GET['categoria_id'])) {
    echo json_encode([]);
    exit;
}

try {
    $database = new Database();
    $db = $database->getConnection();
    
    $query = "SELECT * FROM produtos WHERE categoria_id = ? AND ativo = 1 ORDER BY nome";
    $stmt = $db->prepare($query);
    $stmt->execute([$_GET['categoria_id']]);
    
    $produtos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode($produtos);
    
} catch (Exception $e) {
    echo json_encode([]);
}
?>