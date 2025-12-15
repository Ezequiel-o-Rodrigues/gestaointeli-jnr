<?php
/**
 * API: Carregar Perdas Não Visualizadas para Modal
 * Arquivo: api/perdas_nao_visualizadas.php
 * 
 * Responsabilidades:
 * - Retorna APENAS perdas não visualizadas (visualizada = 0)
 * - Ordenação por data mais recente
 * - Informações detalhadas para exibição no modal
 * - Previne duplicação ao marcar como visualizada
 * 
 * @author Sistema de Gestão
 * @date 2025-12-12
 */

require_once '../config/database.php';

header('Content-Type: application/json');

try {
    $database = new Database();
    $db = $database->getConnection();
    
    // Parâmetros opcionais de filtro
    $data_inicio = $_GET['data_inicio'] ?? null;
    $data_fim = $_GET['data_fim'] ?? null;
    
    // Query base: APENAS perdas NÃO visualizadas
    $query = "
        SELECT 
            pe.id,
            pe.produto_id,
            p.nome as produto_nome,
            p.preco,
            c.nome as categoria_nome,
            pe.quantidade_perdida,
            pe.valor_perda,
            pe.motivo,
            pe.data_identificacao,
            pe.estoque_esperado,
            pe.estoque_real,
            pe.visualizada,
            pe.data_visualizacao,
            pe.observacoes
        FROM perdas_estoque pe
        JOIN produtos p ON pe.produto_id = p.id
        JOIN categorias c ON p.categoria_id = c.id
        WHERE pe.visualizada = 0
    ";
    
    // Adicionar filtros de período se fornecidos
    $params = [];
    if ($data_inicio && $data_fim) {
        $query .= " AND DATE(pe.data_identificacao) BETWEEN ? AND ?";
        $params[] = $data_inicio;
        $params[] = $data_fim;
    }
    
    // Ordenar por data mais recente
    $query .= " ORDER BY pe.data_identificacao DESC";
    
    $stmt = $db->prepare($query);
    
    if (!empty($params)) {
        $stmt->execute($params);
    } else {
        $stmt->execute();
    }
    
    $perdas = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Calcular totalizadores
    $total_perdas = count($perdas);
    $total_quantidade = 0;
    $total_valor = 0;
    
    foreach ($perdas as $perda) {
        $total_quantidade += intval($perda['quantidade_perdida']);
        $total_valor += floatval($perda['valor_perda']);
    }
    
    // Resposta estruturada
    echo json_encode([
        'success' => true,
        'data' => $perdas,
        'total_perdas' => $total_perdas,
        'resumo' => [
            'total_quantidade_perdida' => $total_quantidade,
            'total_valor_perdido' => round($total_valor, 2)
        ],
        'filtros' => [
            'data_inicio' => $data_inicio,
            'data_fim' => $data_fim,
            'apenas_nao_visualizadas' => true
        ],
        'timestamp' => date('Y-m-d H:i:s')
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'error_code' => 'PERDAS_LOAD_ERROR',
        'timestamp' => date('Y-m-d H:i:s')
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
}
?>
