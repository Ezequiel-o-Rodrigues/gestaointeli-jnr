<?php
require_once '../config/database.php';

header('Content-Type: application/json');

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
    echo json_encode(['itens' => [], 'error' => $e->getMessage()]);
}
?>