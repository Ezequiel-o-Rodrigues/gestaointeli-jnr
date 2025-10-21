<?php
// ✅ CORRIGIDO
require_once __DIR__ . '/../config/paths.php';
require_once PathConfig::config('database.php');

header('Content-Type: application/json; charset=utf-8');

$data = json_decode(file_get_contents('php://input'), true);

try {
    $database = new Database();
    $db = $database->getConnection();
    
    // Usar a estrutura correta da tabela
    $query = "UPDATE comandas SET status = 'fechada', data_venda = NOW() WHERE id = ?";
    $stmt = $db->prepare($query);
    $stmt->execute([$data['comanda_id']]);
    
    echo json_encode([
        'success' => true,
        'message' => 'Comanda finalizada com sucesso'
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erro: ' . $e->getMessage()
    ]);
}
?>