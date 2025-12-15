<?php
/**
 * Executar script SQL de correção de perdas
 * Arquivo: api/executar_correcao_perdas.php
 */

require_once '../config/database.php';

header('Content-Type: application/json');

try {
    $database = new Database();
    $db = $database->getConnection();
    
    $resultado = [
        'timestamp' => date('Y-m-d H:i:s'),
        'executacoes' => []
    ];
    
    // 1. Dropar função antiga
    try {
        $db->exec("DROP FUNCTION IF EXISTS fn_perdas_periodo");
        $resultado['executacoes'][] = ['passo' => 'Drop fn_perdas_periodo', 'status' => 'OK'];
    } catch (Exception $e) {
        // Ignorar erro se função não existir
    }
    
    // 2. Criar nova função (sem DELIMITER)
    $sql_funcao = "
    CREATE FUNCTION fn_perdas_periodo(
        p_produto_id INT,
        p_data_inicio DATE,
        p_data_fim DATE
    ) RETURNS INT DETERMINISTIC READS SQL DATA
    BEGIN
        DECLARE v_estoque_inicial INT DEFAULT 0;
        DECLARE v_entradas INT DEFAULT 0;
        DECLARE v_saidas INT DEFAULT 0;
        DECLARE v_estoque_disponivel INT;
        DECLARE v_estoque_real INT;
        DECLARE v_perda INT;
        
        SELECT fn_estoque_teorico_ate_data(p_produto_id, DATE_SUB(p_data_inicio, INTERVAL 1 DAY)) 
        INTO v_estoque_inicial;
        
        SELECT COALESCE(SUM(quantidade), 0) INTO v_entradas
        FROM movimentacoes_estoque
        WHERE produto_id = p_produto_id
        AND DATE(data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
        AND tipo = 'entrada';
        
        SELECT COALESCE(SUM(ic.quantidade), 0) INTO v_saidas
        FROM itens_comanda ic
        JOIN comandas c ON ic.comanda_id = c.id
        WHERE ic.produto_id = p_produto_id
        AND DATE(c.data_venda) BETWEEN p_data_inicio AND p_data_fim;
        
        SET v_estoque_disponivel = v_estoque_inicial + v_entradas;
        
        SELECT COALESCE(estoque_atual, 0) INTO v_estoque_real
        FROM produtos WHERE id = p_produto_id;
        
        SET v_perda = GREATEST(0, v_estoque_disponivel - v_saidas - v_estoque_real);
        
        RETURN v_perda;
    END
    ";
    
    $db->exec($sql_funcao);
    $resultado['executacoes'][] = ['passo' => 'Create fn_perdas_periodo', 'status' => 'OK'];
    
    // 3. Dropar procedure antiga
    try {
        $db->exec("DROP PROCEDURE IF EXISTS relatorio_perdas_periodo_correto");
        $resultado['executacoes'][] = ['passo' => 'Drop relatorio_perdas_periodo_correto', 'status' => 'OK'];
    } catch (Exception $e) {
        // Ignorar erro
    }
    
    // 4. Criar nova procedure
    $sql_procedure = "
    CREATE PROCEDURE relatorio_perdas_periodo_correto(
        IN p_data_inicio DATE,
        IN p_data_fim DATE
    )
    BEGIN
        SELECT 
            p.id,
            p.nome,
            cat.nome AS categoria,
            p.preco,
            
            COALESCE(
                fn_estoque_teorico_ate_data(p.id, DATE_SUB(p_data_inicio, INTERVAL 1 DAY)),
                0
            ) AS estoque_inicial,
            
            COALESCE(
                (SELECT SUM(quantidade) FROM movimentacoes_estoque 
                 WHERE produto_id = p.id 
                 AND DATE(data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
                 AND tipo = 'entrada'),
                0
            ) AS entradas_periodo,
            
            COALESCE(
                (SELECT SUM(ic.quantidade) FROM itens_comanda ic
                 JOIN comandas c ON ic.comanda_id = c.id
                 WHERE ic.produto_id = p.id
                 AND DATE(c.data_venda) BETWEEN p_data_inicio AND p_data_fim),
                0
            ) AS saidas_periodo,
            
            (
                COALESCE(
                    fn_estoque_teorico_ate_data(p.id, DATE_SUB(p_data_inicio, INTERVAL 1 DAY)),
                    0
                )
                +
                COALESCE(
                    (SELECT SUM(quantidade) FROM movimentacoes_estoque 
                     WHERE produto_id = p.id 
                     AND DATE(data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
                     AND tipo = 'entrada'),
                    0
                )
                -
                COALESCE(
                    (SELECT SUM(ic.quantidade) FROM itens_comanda ic
                     JOIN comandas c ON ic.comanda_id = c.id
                     WHERE ic.produto_id = p.id
                     AND DATE(c.data_venda) BETWEEN p_data_inicio AND p_data_fim),
                    0
                )
            ) AS estoque_teorico_final,
            
            COALESCE(p.estoque_atual, 0) AS estoque_real_final,
            
            GREATEST(0,
                (
                    COALESCE(
                        fn_estoque_teorico_ate_data(p.id, DATE_SUB(p_data_inicio, INTERVAL 1 DAY)),
                        0
                    )
                    +
                    COALESCE(
                        (SELECT SUM(quantidade) FROM movimentacoes_estoque 
                         WHERE produto_id = p.id 
                         AND DATE(data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
                         AND tipo = 'entrada'),
                        0
                    )
                    -
                    COALESCE(
                        (SELECT SUM(ic.quantidade) FROM itens_comanda ic
                         JOIN comandas c ON ic.comanda_id = c.id
                         WHERE ic.produto_id = p.id
                         AND DATE(c.data_venda) BETWEEN p_data_inicio AND p_data_fim),
                        0
                    )
                )
                -
                COALESCE(p.estoque_atual, 0)
            ) AS perdas_quantidade,
            
            ROUND(
                GREATEST(0,
                    (
                        COALESCE(
                            fn_estoque_teorico_ate_data(p.id, DATE_SUB(p_data_inicio, INTERVAL 1 DAY)),
                            0
                        )
                        +
                        COALESCE(
                            (SELECT SUM(quantidade) FROM movimentacoes_estoque 
                             WHERE produto_id = p.id 
                             AND DATE(data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
                             AND tipo = 'entrada'),
                            0
                        )
                        -
                        COALESCE(
                            (SELECT SUM(ic.quantidade) FROM itens_comanda ic
                             JOIN comandas c ON ic.comanda_id = c.id
                             WHERE ic.produto_id = p.id
                             AND DATE(c.data_venda) BETWEEN p_data_inicio AND p_data_fim),
                            0
                        )
                    )
                    -
                    COALESCE(p.estoque_atual, 0)
                ) * COALESCE(p.preco, 0),
                2
            ) AS perdas_valor
            
        FROM produtos p
        LEFT JOIN categorias cat ON p.categoria_id = cat.id
        WHERE p.ativo = 1
        ORDER BY perdas_quantidade DESC, p.nome ASC;
    END
    ";
    
    $db->exec($sql_procedure);
    $resultado['executacoes'][] = ['passo' => 'Create relatorio_perdas_periodo_correto', 'status' => 'OK'];
    
    $resultado['status'] = 'SUCESSO';
    $resultado['mensagem'] = 'Todas as correções aplicadas com sucesso!';
    
    echo json_encode($resultado, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'ERRO',
        'message' => $e->getMessage(),
        'timestamp' => date('Y-m-d H:i:s')
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
}
?>
