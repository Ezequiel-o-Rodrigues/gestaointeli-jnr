<?php
header('Content-Type: application/json');
require_once '../config/database.php';

$data = json_decode(file_get_contents('php://input'), true);

try {
    $comanda_id = $data['comanda_id'] ?? null;
    
    if (!$comanda_id) {
        throw new Exception('Comanda ID não informado');
    }
    
    // Usar procedure que valida e baixa estoque
    $stmt = $pdo->prepare("CALL finalizar_comanda_com_estoque(?)");
    $stmt->execute([$comanda_id]);
    
    echo json_encode([
        'success' => true,
        'message' => 'Comanda finalizada e estoque baixado com sucesso'
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>