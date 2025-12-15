-- =============================================================================
-- 📋 SCRIPT 5: MIGRAR DADOS EXISTENTES - PARTE 3 (OUTRAS SAÍDAS)
-- =============================================================================
-- Arquivo: 05_migrar_dados_outras_saidas.sql
-- Descrição: Classifica saídas que não são vendas (perdas, ajustes, etc)
-- Tempo estimado: 5-10 segundos
-- =============================================================================

-- =============================================================================
-- 5.1 CLASSIFICAR SAÍDAS POR OBSERVAÇÃO
-- =============================================================================
-- Lógica: Analisa campo observacao para inferir o motivo

UPDATE movimentacoes_estoque me
INNER JOIN tipos_ajuste_estoque tae ON (
    CASE 
        WHEN me.observacao LIKE '%Devolução%' OR me.observacao LIKE '%devol%' 
            THEN tae.codigo = 'DEVOL'
        WHEN me.observacao LIKE '%Ajuste%' OR me.observacao LIKE '%ajuste%'
            THEN tae.codigo = 'ADJ-'
        WHEN me.observacao LIKE '%Perda%' OR me.observacao LIKE '%perda%'
            THEN tae.codigo = 'PERD'
        WHEN me.observacao LIKE '%Transferência%' OR me.observacao LIKE '%transfer%'
            THEN tae.codigo = 'TRANSF'
        WHEN me.observacao LIKE '%Consumo%' OR me.observacao LIKE '%consumo%'
            THEN tae.codigo = 'CONS'
        WHEN me.observacao LIKE '%Descarte%' OR me.observacao LIKE '%descarte%'
            THEN tae.codigo = 'DESC'
        ELSE tae.codigo = 'ADJ-'  -- Default para desconhecidas
    END
)
SET 
    me.motivo = CASE 
        WHEN me.observacao LIKE '%Devolução%' OR me.observacao LIKE '%devol%' 
            THEN 'devolucao'
        WHEN me.observacao LIKE '%Ajuste%' OR me.observacao LIKE '%ajuste%'
            THEN 'ajuste'
        WHEN me.observacao LIKE '%Perda%' OR me.observacao LIKE '%perda%'
            THEN 'perda_identificada'
        WHEN me.observacao LIKE '%Transferência%' OR me.observacao LIKE '%transfer%'
            THEN 'transferencia'
        WHEN me.observacao LIKE '%Consumo%' OR me.observacao LIKE '%consumo%'
            THEN 'consumo_interno'
        WHEN me.observacao LIKE '%Descarte%' OR me.observacao LIKE '%descarte%'
            THEN 'descarte'
        ELSE 'ajuste'
    END,
    me.tipo_ajuste_id = tae.id
WHERE me.tipo = 'saida'
AND (me.motivo IS NULL OR me.motivo = '')
AND me.observacao NOT LIKE '%Venda%';

-- =============================================================================
-- 5.2 CLASSIFICAR RESTANTES COMO AJUSTE (PADRÃO)
-- =============================================================================

UPDATE movimentacoes_estoque me
INNER JOIN tipos_ajuste_estoque tae ON tae.codigo = 'ADJ-'
SET 
    me.motivo = 'ajuste',
    me.tipo_ajuste_id = tae.id
WHERE me.tipo = 'saida'
AND (me.motivo IS NULL OR me.motivo = '')
AND me.tipo_ajuste_id IS NULL;

-- =============================================================================
-- 5.3 VALIDAR ATUALIZAÇÃO
-- =============================================================================

-- Distribuição de motivos
SELECT 
    motivo,
    COUNT(*) as total,
    ROUND(COUNT(*) * 100 / (SELECT COUNT(*) FROM movimentacoes_estoque WHERE tipo = 'saida'), 2) as percentual
FROM movimentacoes_estoque
WHERE tipo = 'saida'
AND motivo IS NOT NULL
GROUP BY motivo
ORDER BY total DESC;

-- Ver exemplos de cada motivo
SELECT motivo, id, produto_id, quantidade, observacao, data_movimentacao
FROM movimentacoes_estoque
WHERE tipo = 'saida'
AND motivo = 'perda_identificada'
LIMIT 10;

-- Verificar se todas saídas têm motivo agora
SELECT COUNT(*) as total_sem_motivo
FROM movimentacoes_estoque
WHERE tipo = 'saida'
AND (motivo IS NULL OR motivo = '');

-- =============================================================================
-- FIM DO SCRIPT
-- =============================================================================
