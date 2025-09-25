<?php
require_once '../config/database.php';

header('Content-Type: application/json');

try {
    $database = new Database();
    $db = $database->getConnection();
    
    $query = "INSERT INTO comandas (status, valor_total) VALUES ('aberta', 0)";
    $stmt = $db->prepare($query);
    $stmt->execute();
    
    $comanda_id = $db->lastInsertId();
    
    echo json_encode([
        'success' => true,
        'comanda_id' => $comanda_id,
        'message' => 'Comanda criada com sucesso'
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Erro ao criar comanda: ' . $e->getMessage()
    ]);
}
?>