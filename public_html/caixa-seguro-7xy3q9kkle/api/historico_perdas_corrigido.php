<?php
/**
 * API: Histórico de Perdas (CORRIGIDA)
 * Calcula perdas dinamicamente baseado na stored procedure
 * Arquivo: api/historico_perdas_corrigido.php
 */

require_once '../config/database.php';

header('Content-Type: application/json');

try {
    $database = new Database();
    $db = $database->getConnection();
    
    // Parâmetros de filtro
    $data_inicio = $_GET['data_inicio'] ?? date('Y-m-01');
    $data_fim = $_GET['data_fim'] ?? date('Y-m-d');
    
    // PASSO 1: Chamar a stored procedure para calcular perdas
    $stmt = $db->prepare("CALL relatorio_perdas_periodo_correto(:data_inicio, :data_fim)");
    $stmt->bindParam(':data_inicio', $data_inicio);
    $stmt->bindParam(':data_fim', $data_fim);
    $stmt->execute();
    
    $perdas_raw = $stmt->fetchAll(PDO::FETCH_ASSOC);
    $stmt = null; // IMPORTANTE: Fechar o statement antes de fazer outras queries
    
    // PASSO 2: Filtrar apenas produtos com perdas
    $perdas = array_filter($perdas_raw, function($item) {
        return intval($item['perdas_quantidade']) > 0;
    });
    
    // Recalcular índices para manter compatibilidade
    $perdas = array_values($perdas);
    
    // PASSO 3: Preparar IDs dos produtos para verificação em batch
    $produto_ids = array_column($perdas, 'id');
    $visualizadas_map = array();
    
    if (!empty($produto_ids)) {
        // Buscar todas as perdas visualizadas em UMA query
        $placeholders = implode(',', array_fill(0, count($produto_ids), '?'));
        $stmt_check = $db->prepare("
            SELECT id, produto_id, visualizada
            FROM perdas_estoque 
            WHERE produto_id IN ($placeholders)
            AND DATE(data_identificacao) = ?
        ");
        
        $params = array_merge($produto_ids, [$data_fim]);
        $stmt_check->execute($params);
        
        $resultados = $stmt_check->fetchAll(PDO::FETCH_ASSOC);
        
        // Mapear para lookup rápido
        foreach ($resultados as $row) {
            $visualizadas_map[$row['produto_id']] = [
                'id' => $row['id'],
                'visualizada' => (bool)$row['visualizada']
            ];
        }
        
        $stmt_check = null; // Fechar statement
    }
    
    // PASSO 4: Mapear campos para compatibilidade
    $perdas_formatadas = array();
    foreach ($perdas as $item) {
        $produto_id = $item['id'] ?? null;
        
        // Buscar dados de visualização do mapa
        $visualizada = false;
        $id_perda = null;
        if (isset($visualizadas_map[$produto_id])) {
            $id_perda = $visualizadas_map[$produto_id]['id'];
            $visualizada = $visualizadas_map[$produto_id]['visualizada'];
        }
        
        $perdas_formatadas[] = [
            'id' => $id_perda,
            'produto_id' => $produto_id,
            'produto_nome' => $item['nome'] ?? 'Desconhecido',
            'categoria_nome' => $item['categoria'] ?? 'Sem categoria',
            'quantidade_perdida' => intval($item['perdas_quantidade']) ?? 0,
            'valor_perda' => floatval($item['perdas_valor']) ?? 0,
            'motivo' => 'Divergência de estoque no período',
            'data_identificacao' => $data_fim,
            'visualizada' => $visualizada,
            'observacoes' => "Período: " . $data_inicio . " a " . $data_fim,
            // Campos adicionais úteis
            'estoque_inicial' => intval($item['estoque_inicial']) ?? 0,
            'entradas_periodo' => intval($item['entradas_periodo']) ?? 0,
            'saidas_periodo' => intval($item['saidas_periodo']) ?? 0,
            'estoque_teorico_final' => intval($item['estoque_teorico_final']) ?? 0,
            'estoque_real_final' => intval($item['estoque_real_final']) ?? 0
        ];
    }
    
    // Calcular totalizadores
    $total_quantidade = array_sum(array_column($perdas_formatadas, 'quantidade_perdida'));
    $total_valor = array_sum(array_column($perdas_formatadas, 'valor_perda'));
    
    echo json_encode([
        'success' => true,
        'data' => $perdas_formatadas,
        'total' => count($perdas_formatadas),
        'resumo' => [
            'total_perdas' => count($perdas_formatadas),
            'total_quantidade_perdida' => $total_quantidade,
            'total_valor_perdido' => round($total_valor, 2)
        ],
        'filtros' => [
            'data_inicio' => $data_inicio,
            'data_fim' => $data_fim
        ],
        'timestamp' => date('Y-m-d H:i:s')
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'timestamp' => date('Y-m-d H:i:s')
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
}
?>
