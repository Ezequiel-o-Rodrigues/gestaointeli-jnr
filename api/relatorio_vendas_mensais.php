<?php
require_once '../config/database.php';
require_once '../includes/functions.php';

header('Content-Type: application/json');

$database = new Database();
$db = $database->getConnection();

$ano = $_GET['ano'] ?? date('Y');

try {
    $query = "SELECT * FROM view_vendas_mensais WHERE ano = :ano ORDER BY mes";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':ano', $ano);
    $stmt->execute();
    
    $vendas = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Preparar dados para gráfico
    $labels = [];
    $valores = [];
    $comandas = [];
    
    foreach($vendas as $venda) {
        $labels[] = DateTime::createFromFormat('!m', $venda['mes'])->format('M');
        $valores[] = (float)$venda['valor_total_vendas'];
        $comandas[] = (int)$venda['total_comandas'];
    }
    
    echo json_encode([
        'success' => true,
        'data' => $vendas,
        'grafico' => [
            'labels' => $labels,
            'valores' => $valores,
            'comandas' => $comandas
        ]
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Erro ao carregar vendas mensais: ' . $e->getMessage()
    ]);
}
?>