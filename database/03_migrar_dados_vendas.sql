-- =============================================================================
-- 📋 SCRIPT 3: MIGRAR DADOS EXISTENTES - PARTE 1 (VENDAS)
-- =============================================================================
-- Arquivo: 03_migrar_dados_vendas.sql
-- Descrição: Identifica e classifica saídas que são vendas reais
-- Tempo estimado: 10-30 segundos (depende do volume)
-- =============================================================================

-- =============================================================================
-- 3.1 ATUALIZAR SAÍDAS QUE SÃO VENDAS REAIS
-- =============================================================================
-- Lógica: Encontra saídas que correspondem a itens vendidos em comandas fechadas
-- e marca com motivo='venda' + tipo_ajuste_id correspondente

UPDATE movimentacoes_estoque me
INNER JOIN itens_comanda ic ON ic.produto_id = me.produto_id
INNER JOIN comandas c ON ic.comanda_id = c.id
INNER JOIN tipos_ajuste_estoque tae ON tae.codigo = 'VEND'
SET 
    me.motivo = 'venda',
    me.comanda_id = c.id,
    me.tipo_ajuste_id = tae.id,
    me.observacao = CONCAT(
        COALESCE(me.observacao, ''), 
        ' [Sincronizado com Comanda #', c.id, ']'
    )
WHERE me.tipo = 'saida'
AND (me.motivo IS NULL OR me.motivo = '')
AND c.status = 'fechada'
AND me.data_movimentacao >= c.created_at
AND me.data_movimentacao <= IFNULL(c.data_finalizacao, NOW())
LIMIT 10000;

-- =============================================================================
-- 3.2 VALIDAR ATUALIZAÇÃO
-- =============================================================================

-- Contar saídas reclassificadas como venda
SELECT COUNT(*) as total_vendas
FROM movimentacoes_estoque
WHERE tipo = 'saida'
AND motivo = 'venda';

-- Ver exemplos de saídas reclassificadas
SELECT me.id, me.produto_id, me.quantidade, me.motivo, me.comanda_id, me.data_movimentacao
FROM movimentacoes_estoque me
WHERE me.tipo = 'saida'
AND me.motivo = 'venda'
LIMIT 20;

-- Verificar se há discrepâncias (saídas sem motivo = 'venda')
SELECT COUNT(*) as total_sem_motivo
FROM movimentacoes_estoque
WHERE tipo = 'saida'
AND (motivo IS NULL OR motivo = '');

-- =============================================================================
-- FIM DO SCRIPT
-- =============================================================================
