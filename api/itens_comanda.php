<?php
// ✅ CORRIGIDO
require_once __DIR__ . '/../config/paths.php';
require_once PathConfig::config('database.php');

header('Content-Type: application/json; charset=utf-8');

if (!isset($_GET['comanda_id'])) {
    echo json_encode(['itens' => []]);
    exit;
}

try {
    $database = new Database();
    $db = $database->getConnection();
    
    $query = "SELECT ic.*, p.nome 
              FROM itens_comanda ic 
              JOIN produtos p ON ic.produto_id = p.id 
              WHERE ic.comanda_id = ?";
    $stmt = $db->prepare($query);
    $stmt->execute([$_GET['comanda_id']]);
    
    $itens = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['itens' => $itens]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['itens' => [], 'error' => $e->getMessage()]);
}
?>