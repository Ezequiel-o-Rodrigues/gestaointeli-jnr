<?php
/**
 * Arquivo: api/relatorio_analise_estoque_novo.php
 * Descrição: API que fornece dados de análise de estoque COM SNAPSHOTS DIÁRIOS (CORRIGIDO)
 * Data: 14 de Dezembro de 2025
 */

require_once '../config/database.php';

header('Content-Type: application/json');

try {
    $database = new Database();
    $db = $database->getConnection();

    $data_inicio = $_GET['data_inicio'] ?? date('Y-m-01');
    $data_fim = $_GET['data_fim'] ?? date('Y-m-d');

    // Validar datas
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $data_inicio) || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $data_fim)) {
        throw new Exception('Formato de data inválido. Use YYYY-MM-DD');
    }

    // Chamar a stored procedure CORRIGIDA com snapshots
    $stmt = $db->prepare("CALL relatorio_perdas_periodo_correto(:data_inicio, :data_fim)");
    $stmt->bindParam(':data_inicio', $data_inicio);
    $stmt->bindParam(':data_fim', $data_fim);
    $stmt->execute();
    
    $dados = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Calcular totais
    $totais = [
        'total_produtos_com_perda' => 0,
        'total_perdas_quantidade' => 0,
        'total_perdas_valor' => 0,
        'total_faturamento' => 0
    ];

    foreach ($dados as $item) {
        if ($item['perdas_quantidade'] > 0) {
            $totais['total_produtos_com_perda']++;
            $totais['total_perdas_quantidade'] += $item['perdas_quantidade'];
            $totais['total_perdas_valor'] += $item['perdas_valor'];
        }
        // Calcular faturamento do período
        $faturamento = ($item['saidas_periodo'] * $item['preco']) ?? 0;
        $totais['total_faturamento'] += $faturamento;
    }

    // Mapear nomes de colunas da procedure para o JavaScript
    $dados_mapeados = array_map(function($item) {
        return [
            'id' => $item['id'] ?? null,
            'nome' => $item['nome'] ?? 'Produto Desconhecido',
            'categoria' => $item['categoria'] ?? 'Sem Categoria',
            'estoque_inicial' => (int)($item['estoque_inicial'] ?? 0),
            'entradas_periodo' => (int)($item['entradas_periodo'] ?? 0),
            'vendidas_periodo' => (int)($item['saidas_periodo'] ?? 0),
            'estoque_teorico_final' => (int)($item['estoque_teorico_final'] ?? 0),
            'estoque_real_atual' => (int)($item['estoque_real_final'] ?? 0),
            'perdas_quantidade' => (int)($item['perdas_quantidade'] ?? 0),
            'perdas_valor' => (float)($item['perdas_valor'] ?? 0),
            'faturamento_periodo' => ((int)($item['saidas_periodo'] ?? 0) * (float)($item['preco'] ?? 0))
        ];
    }, $dados);

    echo json_encode([
        'success' => true,
        'data' => $dados_mapeados,
        'totais' => $totais,
        'periodo' => [
            'data_inicio' => $data_inicio,
            'data_fim' => $data_fim
        ],
        'metodo' => 'relatorio_perdas_periodo_correto',
        'descricao' => 'Relatório usando snapshots diários para cálculos precisos'
    ]);

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Erro ao gerar relatório: ' . $e->getMessage(),
        'trace' => $e->getTraceAsString()
    ]);
}
?>
