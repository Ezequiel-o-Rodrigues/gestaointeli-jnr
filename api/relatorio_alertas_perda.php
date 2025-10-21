<?php
require_once '../config/database.php';
require_once '../includes/functions.php';

header('Content-Type: application/json');

$database = new Database();
$db = $database->getConnection();

try {
    $query = "SELECT * FROM view_alertas_perda_estoque WHERE diferenca_estoque > 0 ORDER BY diferenca_estoque DESC";
    
    $stmt = $db->prepare($query);
    $stmt->execute();
    $alertas = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode([
        'success' => true,
        'data' => $alertas,
        'total_alertas' => count($alertas)
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Erro ao carregar alertas: ' . $e->getMessage()
    ]);
}
?>