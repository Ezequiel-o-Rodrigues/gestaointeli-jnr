-- =============================================================================
-- 📋 SCRIPT 4: MIGRAR DADOS EXISTENTES - PARTE 2 (ENTRADAS)
-- =============================================================================
-- Arquivo: 04_migrar_dados_entradas.sql
-- Descrição: Classifica entradas com motivo padrão 'compra'
-- Tempo estimado: 5-10 segundos
-- =============================================================================

-- =============================================================================
-- 4.1 ATUALIZAR ENTRADAS COM MOTIVO 'COMPRA'
-- =============================================================================
-- Lógica: Todas as entradas sem motivo são classificadas como 'compra'
-- (assumindo que são compras de fornecedores)

UPDATE movimentacoes_estoque me
INNER JOIN tipos_ajuste_estoque tae ON tae.codigo = 'COMP'
SET 
    me.motivo = 'compra',
    me.tipo_ajuste_id = tae.id
WHERE me.tipo = 'entrada'
AND (me.motivo IS NULL OR me.motivo = '' OR me.motivo = 'venda');

-- =============================================================================
-- 4.2 VALIDAR ATUALIZAÇÃO
-- =============================================================================

-- Contar entradas reclassificadas
SELECT COUNT(*) as total_compras
FROM movimentacoes_estoque
WHERE tipo = 'entrada'
AND motivo = 'compra';

-- Ver exemplos
SELECT me.id, me.produto_id, me.quantidade, me.motivo, me.data_movimentacao, me.observacao
FROM movimentacoes_estoque me
WHERE me.tipo = 'entrada'
AND me.motivo = 'compra'
ORDER BY me.data_movimentacao DESC
LIMIT 20;

-- Verificar entradas sem motivo (se houver)
SELECT COUNT(*) as entradas_sem_motivo
FROM movimentacoes_estoque
WHERE tipo = 'entrada'
AND (motivo IS NULL OR motivo = '');

-- =============================================================================
-- RESUMO PÓS-MIGRAÇÃO
-- =============================================================================

SELECT 
    'Entradas com motivo' as categoria,
    COUNT(*) as total
FROM movimentacoes_estoque
WHERE tipo = 'entrada'
AND motivo IS NOT NULL
UNION ALL
SELECT 
    'Saídas com motivo',
    COUNT(*)
FROM movimentacoes_estoque
WHERE tipo = 'saida'
AND motivo IS NOT NULL
UNION ALL
SELECT
    'Total com tipo_ajuste_id',
    COUNT(*)
FROM movimentacoes_estoque
WHERE tipo_ajuste_id IS NOT NULL;

-- =============================================================================
-- FIM DO SCRIPT
-- =============================================================================
