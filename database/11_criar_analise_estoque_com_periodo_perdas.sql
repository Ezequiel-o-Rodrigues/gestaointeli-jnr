-- =============================================================================
-- 📋 STORED PROCEDURE: Análise de Estoque com Filtro de Perdas por Período
-- =============================================================================
-- Arquivo: 11_criar_analise_estoque_com_periodo_perdas.sql
-- Descrição: Procedure que retorna análise considerando APENAS perdas do período
-- Data: 2025-12-12
-- =============================================================================

-- =============================================================================
-- 11.1 DROPAR PROCEDURE ANTIGA (se existir)
-- =============================================================================

DROP PROCEDURE IF EXISTS relatorio_analise_estoque_periodo_com_filtro_perdas;

-- =============================================================================
-- 11.2 CRIAR NOVA PROCEDURE COM FILTRO DE PERDAS POR PERÍODO
-- =============================================================================

DELIMITER $$

CREATE PROCEDURE relatorio_analise_estoque_periodo_com_filtro_perdas(
    IN p_data_inicio DATE,
    IN p_data_fim DATE
)
BEGIN
    -- =====================================================================
    -- PROCEDURE: Análise de estoque com cálculo correto de perdas
    -- - Considera APENAS movimentações dentro do período
    -- - Perdas contabilizadas apenas se identificadas no período
    -- - Evita acúmulo de períodos anteriores
    -- =====================================================================
    
    SELECT 
        p.id,
        p.nome,
        p.preco,
        cat.nome as categoria,
        p.estoque_atual as estoque_real_atual,
        
        -- ===== ESTOQUE INICIAL (acumulado antes do período) =====
        COALESCE((
            SELECT SUM(
                CASE 
                    WHEN me.tipo = 'entrada' THEN me.quantidade
                    WHEN me.tipo = 'saida' THEN -me.quantidade
                    ELSE 0
                END
            )
            FROM movimentacoes_estoque me
            WHERE me.produto_id = p.id
            AND DATE(me.data_movimentacao) < p_data_inicio
        ), 0) as estoque_inicial,
        
        -- ===== ENTRADAS DURANTE O PERÍODO =====
        COALESCE((
            SELECT SUM(me.quantidade)
            FROM movimentacoes_estoque me
            WHERE me.produto_id = p.id
            AND me.tipo = 'entrada'
            AND DATE(me.data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
        ), 0) as entradas_periodo,
        
        -- ===== VENDAS REAIS (itens_comanda = fonte de verdade) =====
        COALESCE((
            SELECT SUM(ic.quantidade)
            FROM itens_comanda ic
            INNER JOIN comandas c ON ic.comanda_id = c.id
            WHERE ic.produto_id = p.id
            AND c.status = 'fechada'
            AND DATE(c.data_venda) BETWEEN p_data_inicio AND p_data_fim
        ), 0) as vendidas_periodo,
        
        -- ===== SAÍDAS NÃO COMERCIAIS (perdas identificadas, ajustes-) =====
        COALESCE((
            SELECT SUM(me.quantidade)
            FROM movimentacoes_estoque me
            WHERE me.produto_id = p.id
            AND me.tipo = 'saida'
            AND me.motivo NOT IN ('venda')
            AND DATE(me.data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
        ), 0) as saidas_nao_comerciais_periodo,
        
        -- ===== ESTOQUE TEÓRICO FINAL (apenas baseado no período) =====
        (
            COALESCE((
                SELECT SUM(
                    CASE 
                        WHEN me.tipo = 'entrada' THEN me.quantidade
                        WHEN me.tipo = 'saida' THEN -me.quantidade
                        ELSE 0
                    END
                )
                FROM movimentacoes_estoque me
                WHERE me.produto_id = p.id
                AND DATE(me.data_movimentacao) < p_data_inicio
            ), 0)
            +
            COALESCE((
                SELECT SUM(me.quantidade)
                FROM movimentacoes_estoque me
                WHERE me.produto_id = p.id
                AND me.tipo = 'entrada'
                AND DATE(me.data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
            ), 0)
            -
            COALESCE((
                SELECT SUM(ic.quantidade)
                FROM itens_comanda ic
                INNER JOIN comandas c ON ic.comanda_id = c.id
                WHERE ic.produto_id = p.id
                AND c.status = 'fechada'
                AND DATE(c.data_venda) BETWEEN p_data_inicio AND p_data_fim
            ), 0)
        ) as estoque_teorico_final,
        
        -- ===== PERDAS IDENTIFICADAS NO PERÍODO (APENAS NÃO VISUALIZADAS) =====
        COALESCE((
            SELECT SUM(quantidade_perdida)
            FROM perdas_estoque
            WHERE produto_id = p.id
            AND visualizada = 0
            AND DATE(data_identificacao) BETWEEN p_data_inicio AND p_data_fim
        ), 0) as perdas_quantidade,
        
        -- ===== VALOR DAS PERDAS IDENTIFICADAS NO PERÍODO =====
        COALESCE((
            SELECT SUM(valor_perda)
            FROM perdas_estoque
            WHERE produto_id = p.id
            AND visualizada = 0
            AND DATE(data_identificacao) BETWEEN p_data_inicio AND p_data_fim
        ), 0) as perdas_valor,
        
        -- ===== FATURAMENTO DO PERÍODO =====
        COALESCE((
            SELECT SUM(ic.subtotal)
            FROM itens_comanda ic
            INNER JOIN comandas c ON ic.comanda_id = c.id
            WHERE ic.produto_id = p.id
            AND c.status = 'fechada'
            AND DATE(c.data_venda) BETWEEN p_data_inicio AND p_data_fim
        ), 0) as faturamento_periodo
        
    FROM produtos p
    INNER JOIN categorias cat ON p.categoria_id = cat.id
    WHERE p.ativo = 1
    ORDER BY perdas_quantidade DESC, p.nome ASC;
    
END$$

DELIMITER ;

-- =============================================================================
-- 11.3 VERIFICAÇÃO (comentado para não executar automaticamente)
-- =============================================================================

-- Exemplo de uso (descomente para testar):
-- CALL relatorio_analise_estoque_periodo_com_filtro_perdas('2025-12-01', '2025-12-12');

-- Mostrar definição da procedure:
-- SHOW CREATE PROCEDURE relatorio_analise_estoque_periodo_com_filtro_perdas;

-- =============================================================================
