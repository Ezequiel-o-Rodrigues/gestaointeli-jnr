<?php
/**
 * API: Relatório de Análise de Estoque - VERSÃO CORRIGIDA
 * Arquivo: api/relatorio_analise_estoque_corrigido.php
 * 
 * Características:
 * 1. Usa estoque inicial do fechamento do dia anterior (não acumula)
 * 2. Isola completamente dados do período selecionado
 * 3. Cálculos precisos de perdas por período
 * 4. Atualiza tabela fechamento_diario_estoque automaticamente
 */

header('Content-Type: application/json; charset=utf-8');

try {
    // =====================================================================
    // 1. VALIDAÇÃO DOS PARÂMETROS
    // =====================================================================
    
    $data_inicio = isset($_GET['data_inicio']) ? $_GET['data_inicio'] : null;
    $data_fim = isset($_GET['data_fim']) ? $_GET['data_fim'] : null;
    
    if (!$data_inicio || !$data_fim) {
        throw new Exception('Datas de início e fim são obrigatórias');
    }
    
    // Validar formato de data
    if (!strtotime($data_inicio) || !strtotime($data_fim)) {
        throw new Exception('Formato de data inválido. Use YYYY-MM-DD');
    }
    
    if ($data_inicio > $data_fim) {
        throw new Exception('Data de início não pode ser maior que data de fim');
    }
    
    // =====================================================================
    // 2. CONEXÃO COM BANCO DE DADOS
    // =====================================================================
    
    require_once '../../includes/conexao.php';
    
    // =====================================================================
    // 3. GERAR FECHAMENTO DIÁRIO (se necessário)
    // =====================================================================
    
    // Garantir que o fechamento do dia anterior existe
    $data_anterior = date('Y-m-d', strtotime($data_inicio . ' -1 day'));
    
    // Chamar procedure para gerar fechamento automático
    $stmt = $pdo->prepare("CALL gerar_fechamento_diario_automatico(?)");
    $stmt->execute([$data_anterior]);
    
    // =====================================================================
    // 4. CHAMAR PROCEDURE CORRIGIDA
    // =====================================================================
    
    $stmt = $pdo->prepare("CALL relatorio_analise_estoque_periodo_corrigido(?, ?)");
    $stmt->execute([$data_inicio, $data_fim]);
    
    $dados = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Fechar cursor (necessário com multiple result sets)
    while ($stmt->nextRowset()) {
        // Limpar resultado sets
    }
    
    // =====================================================================
    // 5. PROCESSAR DADOS E CALCULAR TOTAIS
    // =====================================================================
    
    $totais = [
        'total_produtos_analisados' => 0,
        'total_produtos_com_perda' => 0,
        'total_entradas' => 0,
        'total_vendidas' => 0,
        'total_perdas_quantidade' => 0,
        'total_perdas_valor' => 0.00,
        'total_faturamento' => 0.00,
        'estoque_inicial_total' => 0,
        'estoque_teorico_total' => 0,
        'estoque_real_total' => 0
    ];
    
    foreach ($dados as &$item) {
        // Converter valores para números
        $item['estoque_inicial'] = intval($item['estoque_inicial']);
        $item['entradas_periodo'] = intval($item['entradas_periodo']);
        $item['vendidas_periodo'] = intval($item['vendidas_periodo']);
        $item['outras_saidas_periodo'] = intval($item['outras_saidas_periodo']);
        $item['estoque_teorico_final'] = intval($item['estoque_teorico_final']);
        $item['estoque_real_atual'] = intval($item['estoque_real_atual']);
        $item['perdas_quantidade'] = intval($item['perdas_quantidade']);
        $item['perdas_valor'] = floatval($item['perdas_valor']);
        $item['faturamento_periodo'] = floatval($item['faturamento_periodo']);
        
        // Calcular totais
        $totais['total_produtos_analisados']++;
        
        if ($item['perdas_quantidade'] > 0) {
            $totais['total_produtos_com_perda']++;
        }
        
        $totais['total_entradas'] += $item['entradas_periodo'];
        $totais['total_vendidas'] += $item['vendidas_periodo'];
        $totais['total_perdas_quantidade'] += $item['perdas_quantidade'];
        $totais['total_perdas_valor'] += $item['perdas_valor'];
        $totais['total_faturamento'] += $item['faturamento_periodo'];
        $totais['estoque_inicial_total'] += $item['estoque_inicial'];
        $totais['estoque_teorico_total'] += $item['estoque_teorico_final'];
        $totais['estoque_real_total'] += $item['estoque_real_atual'];
    }
    
    // =====================================================================
    // 6. PREPARAR RESPOSTA
    // =====================================================================
    
    $resposta = [
        'success' => true,
        'message' => 'Relatório gerado com sucesso (versão corrigida)',
        'periodo' => [
            'data_inicio' => $data_inicio,
            'data_fim' => $data_fim,
            'dias_totais' => (strtotime($data_fim) - strtotime($data_inicio)) / 86400 + 1
        ],
        'totais' => $totais,
        'data' => $dados,
        'timestamp' => date('Y-m-d H:i:s'),
        'versao' => '2.0 - Corrigida'
    ];
    
    // =====================================================================
    // 7. RETORNAR RESPOSTA
    // =====================================================================
    
    echo json_encode($resposta, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erro no banco de dados',
        'error' => $e->getMessage(),
        'debug' => [
            'file' => $e->getFile(),
            'line' => $e->getLine()
        ]
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
