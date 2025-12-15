<?php
/**
 * API: Relatório de Análise de Estoque com Filtro de Perdas por Período
 * Arquivo: api/relatorio_analise_estoque_periodo_perdas.php
 * 
 * Responsabilidades:
 * - Retorna análise de estoque por período
 * - Contabiliza APENAS perdas identificadas no período (não visualizadas)
 * - Evita acúmulo de períodos anteriores
 * - Integra-se com modal de alertas e relatórios
 * 
 * @author Sistema de Gestão
 * @date 2025-12-12
 */

require_once '../config/database.php';

header('Content-Type: application/json');

try {
    $database = new Database();
    $db = $database->getConnection();
    
    // Receber parâmetros
    $data_inicio = $_GET['data_inicio'] ?? date('Y-m-01');
    $data_fim = $_GET['data_fim'] ?? date('Y-m-d');
    $categoria_id = $_GET['categoria_id'] ?? null;
    $tipo_filtro = $_GET['tipo_filtro'] ?? 'todos'; // todos, com_perda, sem_perda
    $valor_minimo = floatval($_GET['valor_minimo'] ?? 0);
    
    // Validar datas
    if (!strtotime($data_inicio) || !strtotime($data_fim)) {
        throw new Exception('Datas inválidas fornecidas');
    }
    
    if ($data_inicio > $data_fim) {
        throw new Exception('Data de início não pode ser maior que data de fim');
    }
    
    // Chamar stored procedure
    $query = "CALL relatorio_analise_estoque_periodo_com_filtro_perdas(?, ?)";
    $stmt = $db->prepare($query);
    $stmt->execute([$data_inicio, $data_fim]);
    $dados = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Fechar o resultado anterior (necessário com stored procedures)
    while ($stmt->nextRowset());
    
    // Aplicar filtros pós-processamento
    $dados_filtrados = [];
    $totais = [
        'total_produtos' => 0,
        'total_produtos_com_perda' => 0,
        'total_perdas_quantidade' => 0,
        'total_perdas_valor' => 0.0,
        'total_faturamento' => 0.0
    ];
    
    foreach ($dados as $linha) {
        $tem_perda = floatval($linha['perdas_valor']) > 0;
        
        // Filtro por categoria
        if ($categoria_id && $linha['categoria'] != $categoria_id) {
            continue;
        }
        
        // Filtro por tipo (com perda, sem perda)
        if ($tipo_filtro === 'com_perda' && !$tem_perda) {
            continue;
        } elseif ($tipo_filtro === 'sem_perda' && $tem_perda) {
            continue;
        }
        
        // Filtro por valor mínimo de perda
        if (floatval($linha['perdas_valor']) < $valor_minimo) {
            continue;
        }
        
        // Adicionar aos dados filtrados
        $dados_filtrados[] = $linha;
        
        // Atualizar totalizadores
        $totais['total_produtos']++;
        if ($tem_perda) {
            $totais['total_produtos_com_perda']++;
            $totais['total_perdas_quantidade'] += intval($linha['perdas_quantidade']);
            $totais['total_perdas_valor'] += floatval($linha['perdas_valor']);
        }
        $totais['total_faturamento'] += floatval($linha['faturamento_periodo']);
    }
    
    // Resposta estruturada
    echo json_encode([
        'success' => true,
        'data' => $dados_filtrados,
        'totais' => $totais,
        'periodo' => [
            'data_inicio' => $data_inicio,
            'data_fim' => $data_fim,
            'dias_analisados' => (strtotime($data_fim) - strtotime($data_inicio)) / 86400 + 1
        ],
        'filtros_aplicados' => [
            'categoria_id' => $categoria_id,
            'tipo_filtro' => $tipo_filtro,
            'valor_minimo' => $valor_minimo
        ],
        'timestamp' => date('Y-m-d H:i:s')
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'error_code' => 'RELATORIO_ERROR',
        'timestamp' => date('Y-m-d H:i:s')
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
}
?>
