<?php
require_once '../config/database.php';
require_once '../includes/functions.php';

header('Content-Type: application/json');

$database = new Database();
$db = $database->getConnection();

$data_inicio = $_GET['data_inicio'] ?? date('Y-m-d', strtotime('-30 days'));
$data_fim = $_GET['data_fim'] ?? date('Y-m-d');
$tipo_periodo = $_GET['tipo'] ?? 'diario'; // diario, semanal, mensal

try {
    switch($tipo_periodo) {
        case 'diario':
            $query = "SELECT * FROM view_vendas_periodo_detalhado 
                     WHERE data_venda BETWEEN :data_inicio AND :data_fim 
                     ORDER BY data_venda";
            break;
            
        case 'semanal':
            $query = "SELECT 
                         CONCAT('Semana ', semana, ' - ', YEAR(data_venda)) as periodo,
                         SUM(total_comandas) as total_comandas,
                         SUM(valor_total_vendas) as valor_total_vendas,
                         SUM(total_gorjetas) as total_gorjetas,
                         AVG(ticket_medio) as ticket_medio
                      FROM view_vendas_periodo_detalhado 
                      WHERE data_venda BETWEEN :data_inicio AND :data_fim 
                      GROUP BY semana, YEAR(data_venda)
                      ORDER BY YEAR(data_venda) DESC, semana DESC";
            break;
            
        case 'mensal':
            $query = "SELECT * FROM view_vendas_mensais 
                     WHERE CONCAT(ano, '-', LPAD(mes, 2, '0')) BETWEEN :data_inicio AND :data_fim 
                     ORDER BY ano DESC, mes DESC";
            break;
    }
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':data_inicio', $data_inicio);
    $stmt->bindParam(':data_fim', $data_fim);
    $stmt->execute();
    
    $resultados = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode([
        'success' => true,
        'data' => $resultados,
        'periodo' => $tipo_periodo
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Erro ao gerar relatório: ' . $e->getMessage()
    ]);
}
?>