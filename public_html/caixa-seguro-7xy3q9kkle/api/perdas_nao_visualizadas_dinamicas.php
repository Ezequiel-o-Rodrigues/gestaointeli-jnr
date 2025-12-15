<?php
/**
 * API: Perdas Não Visualizadas (Dinâmicas)
 * Retorna perdas do período atual que NÃO foram marcadas como visualizadas
 * Arquivo: api/perdas_nao_visualizadas_dinamicas.php
 */

require_once '../config/database.php';

header('Content-Type: application/json');

try {
    $database = new Database();
    $db = $database->getConnection();
    
    // Parâmetros - usar período atual (hoje)
    $data_hoje = date('Y-m-d');
    $data_inicio_mes = date('Y-m-01');
    
    // Parâmetro opcional para filtrar por período
    $periodo = $_GET['periodo'] ?? 'mes'; // 'hoje' ou 'mes'
    
    if ($periodo === 'hoje') {
        $data_inicio = $data_hoje;
        $data_fim = $data_hoje;
    } else {
        // Por padrão, usar o mês atual
        $data_inicio = $data_inicio_mes;
        $data_fim = $data_hoje;
    }
    
    // PASSO 1: Chamar stored procedure para calcular perdas do período
    $stmt = $db->prepare("CALL relatorio_perdas_periodo_correto(:data_inicio, :data_fim)");
    $stmt->bindParam(':data_inicio', $data_inicio);
    $stmt->bindParam(':data_fim', $data_fim);
    $stmt->execute();
    
    $perdas_raw = $stmt->fetchAll(PDO::FETCH_ASSOC);
    $stmt = null; // Fechar statement
    
    // PASSO 2: Filtrar apenas produtos com perdas
    $perdas = array_filter($perdas_raw, function($item) {
        return intval($item['perdas_quantidade']) > 0;
    });
    
    $perdas = array_values($perdas);
    
    // PASSO 3: Preparar IDs dos produtos para verificação em batch
    $produto_ids = array_column($perdas, 'id');
    $visualizadas_map = array();
    
    if (!empty($produto_ids)) {
        // Buscar todas as perdas que foram marcadas como visualizadas
        $placeholders = implode(',', array_fill(0, count($produto_ids), '?'));
        $stmt_check = $db->prepare("
            SELECT id, produto_id, visualizada
            FROM perdas_estoque 
            WHERE produto_id IN ($placeholders)
            AND visualizada = 1
            AND DATE(data_identificacao) = ?
        ");
        
        $params = array_merge($produto_ids, [$data_fim]);
        $stmt_check->execute($params);
        
        $resultados_visualizadas = $stmt_check->fetchAll(PDO::FETCH_ASSOC);
        $stmt_check = null;
        
        // Mapear IDs de perdas visualizadas
        foreach ($resultados_visualizadas as $row) {
            $visualizadas_map[$row['produto_id']] = true;
        }
    }
    
    // PASSO 4: Filtrar apenas perdas NÃO visualizadas
    $perdas_nao_visualizadas = array();
    
    foreach ($perdas as $item) {
        $produto_id = $item['id'] ?? null;
        
        // Se NÃO está em visualizadas_map, está não visualizada
        if (!isset($visualizadas_map[$produto_id])) {
            $perdas_nao_visualizadas[] = [
                'produto_id' => $produto_id,
                'produto_nome' => $item['nome'] ?? 'Desconhecido',
                'categoria_nome' => $item['categoria'] ?? 'Sem categoria',
                'quantidade_perdida' => intval($item['perdas_quantidade']) ?? 0,
                'valor_perda' => floatval($item['perdas_valor']) ?? 0,
                'data_periodo' => $data_fim,
                'estoque_inicial' => intval($item['estoque_inicial']) ?? 0,
                'entradas_periodo' => intval($item['entradas_periodo']) ?? 0,
                'saidas_periodo' => intval($item['saidas_periodo']) ?? 0,
                'estoque_teorico_final' => intval($item['estoque_teorico_final']) ?? 0,
                'estoque_real_final' => intval($item['estoque_real_final']) ?? 0
            ];
        }
    }
    
    // Calcular totalizadores
    $total_quantidade = array_sum(array_column($perdas_nao_visualizadas, 'quantidade_perdida'));
    $total_valor = array_sum(array_column($perdas_nao_visualizadas, 'valor_perda'));
    
    echo json_encode([
        'success' => true,
        'data' => $perdas_nao_visualizadas,
        'total' => count($perdas_nao_visualizadas),
        'total_quantidade' => $total_quantidade,
        'total_valor' => round($total_valor, 2),
        'periodo' => [
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
