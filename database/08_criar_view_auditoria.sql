-- =============================================================================
-- 📋 SCRIPT 8: CRIAR VIEW DE AUDITORIA
-- =============================================================================
-- Arquivo: 08_criar_view_auditoria.sql
-- Descrição: View consolidada para análise de perdas
-- Tempo estimado: 1-2 segundos
-- =============================================================================

-- =============================================================================
-- 8.1 DROPAR VIEW ANTIGA (se existir)
-- =============================================================================

DROP VIEW IF EXISTS vw_analise_perdas_corrigida;

-- =============================================================================
-- 8.2 CRIAR VIEW DE ANÁLISE
-- =============================================================================

CREATE VIEW vw_analise_perdas_corrigida AS
SELECT 
    p.id as produto_id,
    p.nome as produto_nome,
    cat.nome as categoria,
    p.preco,
    p.estoque_atual as estoque_real,
    
    -- Acumulado até hoje
    fn_estoque_acumulado(p.id, CURDATE()) as estoque_teorico,
    fn_calcular_perda(p.id, CURDATE()) as perda_atual,
    (fn_calcular_perda(p.id, CURDATE()) * p.preco) as valor_perda_atual,
    
    -- Movimentação mais recente
    (SELECT DATE(MAX(data_movimentacao)) 
     FROM movimentacoes_estoque 
     WHERE produto_id = p.id) as ultima_movimentacao,
    
    -- Contadores de atividade
    (SELECT COUNT(*) 
     FROM movimentacoes_estoque 
     WHERE produto_id = p.id AND tipo = 'entrada') as total_entradas,
    (SELECT COUNT(*) 
     FROM movimentacoes_estoque 
     WHERE produto_id = p.id AND tipo = 'saida') as total_saidas,
    (SELECT COUNT(*) 
     FROM itens_comanda 
     WHERE produto_id = p.id) as total_vendas,
    
    -- Data de cadastro
    p.created_at as data_cadastro,
    p.updated_at as data_atualizacao
    
FROM produtos p
INNER JOIN categorias cat ON p.categoria_id = cat.id
WHERE p.ativo = 1
ORDER BY fn_calcular_perda(p.id, CURDATE()) DESC;

-- =============================================================================
-- 8.3 TESTANDO VIEW
-- =============================================================================

-- Contar produtos com perda
SELECT COUNT(*) as produtos_com_perda
FROM vw_analise_perdas_corrigida
WHERE perda_atual > 0;

-- Ver top 10 produtos com maior perda
SELECT 
    produto_id,
    produto_nome,
    categoria,
    estoque_teorico,
    estoque_real,
    perda_atual,
    valor_perda_atual,
    total_entradas,
    total_saidas,
    total_vendas
FROM vw_analise_perdas_corrigida
WHERE perda_atual > 0
LIMIT 10;

-- Total de perdas
SELECT 
    COUNT(*) as total_produtos_com_perda,
    SUM(perda_atual) as total_quantidade_perdida,
    SUM(valor_perda_atual) as total_valor_perdido
FROM vw_analise_perdas_corrigida
WHERE perda_atual > 0;

-- Verificar view
SHOW CREATE VIEW vw_analise_perdas_corrigida;

-- =============================================================================
-- FIM DO SCRIPT
-- =============================================================================
