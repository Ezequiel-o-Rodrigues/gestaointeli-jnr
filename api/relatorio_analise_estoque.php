<?php
require_once '../config/database.php';
require_once '../includes/functions.php';

header('Content-Type: application/json');

$database = new Database();
$db = $database->getConnection();

$data_inicio = $_GET['data_inicio'] ?? date('Y-m-01'); // Primeiro dia do mês atual
$data_fim = $_GET['data_fim'] ?? date('Y-m-d');

try {
    // Verificar se a stored procedure existe
    $check_procedure = "SHOW PROCEDURE STATUS LIKE 'relatorio_analise_estoque_periodo'";
    $stmt_check = $db->prepare($check_procedure);
    $stmt_check->execute();
    
    if ($stmt_check->rowCount() > 0) {
        // Usar a stored procedure se existir
        $query = "CALL relatorio_analise_estoque_periodo(:data_inicio, :data_fim)";
    } else {
        // Usar query direta como fallback
        $query = "
        SELECT 
            p.id,
            p.nome,
            cat.nome as categoria,
            p.preco,
            
            -- Estoque inicial (todas as entradas antes do período)
            COALESCE((
                SELECT SUM(me.quantidade) 
                FROM movimentacoes_estoque me 
                WHERE me.produto_id = p.id 
                AND me.tipo = 'entrada' 
                AND DATE(me.data_movimentacao) < :data_inicio
            ), 0) as estoque_inicial,
            
            -- Entradas durante o período
            COALESCE((
                SELECT SUM(me.quantidade) 
                FROM movimentacoes_estoque me 
                WHERE me.produto_id = p.id 
                AND me.tipo = 'entrada' 
                AND DATE(me.data_movimentacao) BETWEEN :data_inicio AND :data_fim
            ), 0) as entradas_periodo,
            
            -- Saídas por vendas durante o período
            COALESCE((
                SELECT SUM(ic.quantidade) 
                FROM itens_comanda ic 
                JOIN comandas c ON ic.comanda_id = c.id 
                WHERE ic.produto_id = p.id 
                AND c.status = 'fechada'
                AND DATE(c.data_venda) BETWEEN :data_inicio AND :data_fim
            ), 0) as vendidas_periodo,
            
            -- Faturamento do produto no período
            COALESCE((
                SELECT SUM(ic.subtotal) 
                FROM itens_comanda ic 
                JOIN comandas c ON ic.comanda_id = c.id 
                WHERE ic.produto_id = p.id 
                AND c.status = 'fechada'
                AND DATE(c.data_venda) BETWEEN :data_inicio AND :data_fim
            ), 0) as faturamento_periodo,
            
            -- Estoque teórico final
            (COALESCE((
                SELECT SUM(me.quantidade) 
                FROM movimentacoes_estoque me 
                WHERE me.produto_id = p.id 
                AND me.tipo = 'entrada' 
                AND DATE(me.data_movimentacao) < :data_inicio
            ), 0) + 
            COALESCE((
                SELECT SUM(me.quantidade) 
                FROM movimentacoes_estoque me 
                WHERE me.produto_id = p.id 
                AND me.tipo = 'entrada' 
                AND DATE(me.data_movimentacao) BETWEEN :data_inicio AND :data_fim
            ), 0)) - 
            COALESCE((
                SELECT SUM(ic.quantidade) 
                FROM itens_comanda ic 
                JOIN comandas c ON ic.comanda_id = c.id 
                WHERE ic.produto_id = p.id 
                AND c.status = 'fechada'
                AND DATE(c.data_venda) BETWEEN :data_inicio AND :data_fim
            ), 0) as estoque_teorico_final,
            
            -- Estoque real atual
            p.estoque_atual as estoque_real_atual,
            
            -- Diferença (perdas)
            ((COALESCE((
                SELECT SUM(me.quantidade) 
                FROM movimentacoes_estoque me 
                WHERE me.produto_id = p.id 
                AND me.tipo = 'entrada' 
                AND DATE(me.data_movimentacao) < :data_inicio
            ), 0) + 
            COALESCE((
                SELECT SUM(me.quantidade) 
                FROM movimentacoes_estoque me 
                WHERE me.produto_id = p.id 
                AND me.tipo = 'entrada' 
                AND DATE(me.data_movimentacao) BETWEEN :data_inicio AND :data_fim
            ), 0)) - 
            COALESCE((
                SELECT SUM(ic.quantidade) 
                FROM itens_comanda ic 
                JOIN comandas c ON ic.comanda_id = c.id 
                WHERE ic.produto_id = p.id 
                AND c.status = 'fechada'
                AND DATE(c.data_venda) BETWEEN :data_inicio AND :data_fim
            ), 0)) - p.estoque_atual as perdas_quantidade,
            
            -- Valor das perdas
            (((COALESCE((
                SELECT SUM(me.quantidade) 
                FROM movimentacoes_estoque me 
                WHERE me.produto_id = p.id 
                AND me.tipo = 'entrada' 
                AND DATE(me.data_movimentacao) < :data_inicio
            ), 0) + 
            COALESCE((
                SELECT SUM(me.quantidade) 
                FROM movimentacoes_estoque me 
                WHERE me.produto_id = p.id 
                AND me.tipo = 'entrada' 
                AND DATE(me.data_movimentacao) BETWEEN :data_inicio AND :data_fim
            ), 0)) - 
            COALESCE((
                SELECT SUM(ic.quantidade) 
                FROM itens_comanda ic 
                JOIN comandas c ON ic.comanda_id = c.id 
                WHERE ic.produto_id = p.id 
                AND c.status = 'fechada'
                AND DATE(c.data_venda) BETWEEN :data_inicio AND :data_fim
            ), 0)) - p.estoque_atual) * p.preco as perdas_valor
            
        FROM produtos p
        JOIN categorias cat ON p.categoria_id = cat.id
        WHERE p.ativo = 1
        ORDER BY perdas_valor DESC, perdas_quantidade DESC";
    }

    $stmt = $db->prepare($query);
    $stmt->bindParam(':data_inicio', $data_inicio);
    $stmt->bindParam(':data_fim', $data_fim);
    $stmt->execute();
    
    $resultados = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Calcular totais
    $totais = [
        'total_perdas_quantidade' => 0,
        'total_perdas_valor' => 0,
        'total_faturamento' => 0,
        'total_produtos_com_perda' => 0,
        'total_entradas_periodo' => 0,
        'total_vendidas_periodo' => 0
    ];
    
    foreach ($resultados as $item) {
        $totais['total_perdas_quantidade'] += $item['perdas_quantidade'];
        $totais['total_perdas_valor'] += $item['perdas_valor'];
        $totais['total_faturamento'] += $item['faturamento_periodo'];
        $totais['total_entradas_periodo'] += $item['entradas_periodo'];
        $totais['total_vendidas_periodo'] += $item['vendidas_periodo'];
        if ($item['perdas_quantidade'] > 0) {
            $totais['total_produtos_com_perda']++;
        }
    }
    
    echo json_encode([
        'success' => true,
        'data' => $resultados,
        'totais' => $totais,
        'periodo' => [
            'data_inicio' => $data_inicio,
            'data_fim' => $data_fim
        ],
        'usando_procedure' => ($stmt_check->rowCount() > 0)
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Erro ao gerar relatório de análise de estoque: ' . $e->getMessage(),
        'data' => [],
        'totais' => []
    ]);
}
?>