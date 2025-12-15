-- =============================================================================
-- 📋 SCRIPT 6: CRIAR STORED PROCEDURE CORRIGIDA
-- =============================================================================
-- Arquivo: 06_criar_stored_procedure_corrigida.sql
-- Descrição: Procedure com lógica corrigida de cálculo de perdas
-- Tempo estimado: 2-5 segundos
-- =============================================================================

-- =============================================================================
-- 6.1 DROPAR PROCEDURE ANTIGA (se existir)
-- =============================================================================

DROP PROCEDURE IF EXISTS relatorio_analise_estoque_periodo_corrigido;

-- =============================================================================
-- 6.2 CRIAR NOVA PROCEDURE COM LÓGICA CORRIGIDA
-- =============================================================================

DELIMITER $$

CREATE PROCEDURE relatorio_analise_estoque_periodo_corrigido(
    IN p_data_inicio DATE,
    IN p_data_fim DATE
)
BEGIN
    -- =====================================================================
    -- PROCEDURE: Análise de estoque com cálculo correto de perdas
    -- Considera TODAS as movimentações com seus motivos específicos
    -- Evita duplicação de contabilizações
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
        ), 0) as vendas_periodo,
        
        -- ===== SAÍDAS NÃO COMERCIAIS (perdas já identificadas, ajustes-) =====
        COALESCE((
            SELECT SUM(me.quantidade)
            FROM movimentacoes_estoque me
            WHERE me.produto_id = p.id
            AND me.tipo = 'saida'
            AND me.motivo NOT IN ('venda')
            AND DATE(me.data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
        ), 0) as saidas_nao_comerciais_periodo,
        
        -- ===== ESTOQUE TEÓRICO FINAL =====
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
                AND DATE(me.data_movimentacao) <= p_data_fim
            ), 0)
        ) as estoque_teorico_final,
        
        -- ===== DIFERENÇA (PERDA NÃO IDENTIFICADA) =====
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
                AND DATE(me.data_movimentacao) <= p_data_fim
            ), 0) - p.estoque_atual
        ) as diferenca_estoque,
        
        -- ===== APENAS PERDAS NÃO IDENTIFICADAS (diferença > 0) =====
        GREATEST(
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
                    AND DATE(me.data_movimentacao) <= p_data_fim
                ), 0) - p.estoque_atual
            ),
            0
        ) as perdas_nao_identificadas,
        
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
    ORDER BY perdas_nao_identificadas DESC, p.nome ASC;
    
END$$

DELIMITER ;

-- =============================================================================
-- 6.3 TESTAR PROCEDURE
-- =============================================================================

-- Testar com período recente
CALL relatorio_analise_estoque_periodo_corrigido('2025-11-01', '2025-12-11');

-- Verificar se procedure foi criada
SHOW CREATE PROCEDURE relatorio_analise_estoque_periodo_corrigido;

-- =============================================================================
-- FIM DO SCRIPT
-- =============================================================================
