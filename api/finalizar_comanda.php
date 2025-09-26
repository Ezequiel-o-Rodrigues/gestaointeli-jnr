<?php
require_once '../config/database.php';

header('Content-Type: application/json');

$data = json_decode(file_get_contents('php://input'), true);

try {
    $database = new Database();
    $db = $database->getConnection();
    
    // Usar a procedure do banco ou atualizar manualmente
    $query = "UPDATE comandas SET status = 'fechada', data_venda = NOW() WHERE id = ?";
    $stmt = $db->prepare($query);
    $stmt->execute([$data['comanda_id']]);
    
    echo json_encode([
        'success' => true,
        'message' => 'Comanda finalizada com sucesso'
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Erro: ' . $e->getMessage()
    ]);
}
?>