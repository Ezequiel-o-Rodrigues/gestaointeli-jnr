<?php
/**
 * API: Modal de Histórico de Perdas - VERSÃO FUNCIONAL
 * Arquivo: api/modal_historico_perdas.php
 * 
 * Retorna perdas não visualizadas e completas para o modal
 * Com separação clara entre alertas e histórico
 */

header('Content-Type: application/json; charset=utf-8');

try {
    // =====================================================================
    // 1. VALIDAÇÃO
    // =====================================================================
    
    $data_inicio = isset($_GET['data_inicio']) ? $_GET['data_inicio'] : null;
    $data_fim = isset($_GET['data_fim']) ? $_GET['data_fim'] : null;
    $produto_id = isset($_GET['produto_id']) ? intval($_GET['produto_id']) : null;
    
    // Se não tiver datas, usar o mês atual
    if (!$data_inicio || !$data_fim) {
        $data_inicio = date('Y-m-01'); // Primeiro dia do mês
        $data_fim = date('Y-m-t');     // Último dia do mês
    }
    
    require_once '../../includes/conexao.php';
    
    // =====================================================================
    // 2. OBTER PERDAS NÃO VISUALIZADAS (ALERTAS)
    // =====================================================================
    
    $sql_alertas = "
        SELECT 
            pe.id,
            pe.produto_id,
            p.nome AS produto_nome,
            cat.nome AS categoria_nome,
            pe.quantidade_perdida,
            pe.valor_perda,
            pe.data_identificacao,
            pe.visualizada,
            pe.data_visualizacao,
            pe.motivo,
            pe.observacoes,
            'alerta' AS tipo
        FROM perdas_estoque pe
        JOIN produtos p ON pe.produto_id = p.id
        LEFT JOIN categorias cat ON p.categoria_id = cat.id
        WHERE pe.visualizada = 0
        AND DATE(pe.data_identificacao) BETWEEN ? AND ?
    ";
    
    $params_alertas = [$data_inicio, $data_fim];
    
    if ($produto_id) {
        $sql_alertas .= " AND pe.produto_id = ?";
        $params_alertas[] = $produto_id;
    }
    
    $sql_alertas .= " ORDER BY pe.data_identificacao DESC";
    
    $stmt = $pdo->prepare($sql_alertas);
    $stmt->execute($params_alertas);
    $alertas = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // =====================================================================
    // 3. OBTER HISTÓRICO COMPLETO (TODAS AS PERDAS)
    // =====================================================================
    
    $sql_historico = "
        SELECT 
            pe.id,
            pe.produto_id,
            p.nome AS produto_nome,
            cat.nome AS categoria_nome,
            pe.quantidade_perdida,
            pe.valor_perda,
            pe.data_identificacao,
            pe.visualizada,
            pe.data_visualizacao,
            pe.motivo,
            pe.observacoes,
            CASE 
                WHEN pe.visualizada = 1 THEN 'visualizada'
                ELSE 'pendente'
            END AS status,
            'historico' AS tipo
        FROM perdas_estoque pe
        JOIN produtos p ON pe.produto_id = p.id
        LEFT JOIN categorias cat ON p.categoria_id = cat.id
        WHERE DATE(pe.data_identificacao) BETWEEN ? AND ?
    ";
    
    $params_historico = [$data_inicio, $data_fim];
    
    if ($produto_id) {
        $sql_historico .= " AND pe.produto_id = ?";
        $params_historico[] = $produto_id;
    }
    
    $sql_historico .= " ORDER BY pe.data_identificacao DESC";
    
    $stmt = $pdo->prepare($sql_historico);
    $stmt->execute($params_historico);
    $historico = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // =====================================================================
    // 4. PROCESSAR DADOS
    // =====================================================================
    
    // Converter para números
    foreach ($alertas as &$alerta) {
        $alerta['quantidade_perdida'] = intval($alerta['quantidade_perdida']);
        $alerta['valor_perda'] = floatval($alerta['valor_perda']);
        $alerta['produto_id'] = intval($alerta['produto_id']);
    }
    
    foreach ($historico as &$item) {
        $item['quantidade_perdida'] = intval($item['quantidade_perdida']);
        $item['valor_perda'] = floatval($item['valor_perda']);
        $item['produto_id'] = intval($item['produto_id']);
        $item['visualizada'] = intval($item['visualizada']);
    }
    
    // =====================================================================
    // 5. CALCULAR TOTAIS
    // =====================================================================
    
    $total_alertas = count($alertas);
    $total_historico = count($historico);
    
    $valor_total_alertas = array_sum(array_column($alertas, 'valor_perda'));
    $valor_total_historico = array_sum(array_column($historico, 'valor_perda'));
    
    // =====================================================================
    // 6. MONTAR RESPOSTA
    // =====================================================================
    
    $resposta = [
        'success' => true,
        'message' => 'Dados do modal carregados com sucesso',
        'periodo' => [
            'data_inicio' => $data_inicio,
            'data_fim' => $data_fim
        ],
        'resumo' => [
            'total_alertas' => $total_alertas,
            'total_historico' => $total_historico,
            'valor_total_alertas' => round($valor_total_alertas, 2),
            'valor_total_historico' => round($valor_total_historico, 2),
            'valor_total_geral' => round($valor_total_alertas + $valor_total_historico, 2)
        ],
        'alertas' => [
            'count' => $total_alertas,
            'valor_total' => round($valor_total_alertas, 2),
            'data' => $alertas
        ],
        'historico' => [
            'count' => $total_historico,
            'valor_total' => round($valor_total_historico, 2),
            'data' => $historico
        ],
        'timestamp' => date('Y-m-d H:i:s')
    ];
    
    echo json_encode($resposta, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erro no banco de dados',
        'error' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'timestamp' => date('Y-m-d H:i:s')
    ], JSON_UNESCAPED_UNICODE);
}
?>
