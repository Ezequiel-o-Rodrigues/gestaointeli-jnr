-- =============================================================================
-- 🔄 SCRIPT 10: RESETAR HISTÓRICO COMPLETO DO BANCO
-- =============================================================================
-- Arquivo: 10_resetar_historico_completo.sql
-- Descrição: Limpa todo o histórico, mantendo apenas os produtos cadastrados
-- Tempo estimado: 5-10 segundos
-- Aviso: ⚠️ OPERAÇÃO DESTRUTIVA - Faz backup antes de executar!
-- =============================================================================

-- =============================================================================
-- 0. BACKUP RECOMENDADO
-- =============================================================================

-- Execute isto ANTES de rodar este script:
-- mysqldump -u root -p gestaointeli_db > backup_completo_$(date +%Y%m%d_%H%M%S).sql

SELECT 'INICIANDO LIMPEZA DE HISTÓRICO' as status, NOW() as timestamp;

-- =============================================================================
-- 1. DESABILITAR CHAVES ESTRANGEIRAS (para permitir TRUNCATE)
-- =============================================================================

SET FOREIGN_KEY_CHECKS = 0;
SELECT 'Chaves estrangeiras desabilitadas' as status;

-- =============================================================================
-- 2. LIMPAR TABELAS NA ORDEM CORRETA (sem dependências)
-- =============================================================================

-- 2.1 Limpar de dentro para fora (tabelas com FKs primeiro)
DELETE FROM comprovantes_venda;
SELECT 'comprovantes_venda zerada' as status;

-- 2.2 Limpar itens de comanda
DELETE FROM itens_comanda;
SELECT 'itens_comanda zerada' as status;

-- 2.3 Limpar comandas
DELETE FROM comandas;
SELECT 'comandas zerada' as status;

-- 2.4 Limpar movimentações de estoque
DELETE FROM movimentacoes_estoque;
SELECT 'movimentacoes_estoque zerada' as status;

-- 2.5 Limpar perdas de estoque
DELETE FROM perdas_estoque;
SELECT 'perdas_estoque zerada' as status;

-- 2.6 Resetar auto_increment das tabelas
ALTER TABLE comprovantes_venda AUTO_INCREMENT = 1;
ALTER TABLE itens_comanda AUTO_INCREMENT = 1;
ALTER TABLE comandas AUTO_INCREMENT = 1;
ALTER TABLE movimentacoes_estoque AUTO_INCREMENT = 1;
ALTER TABLE perdas_estoque AUTO_INCREMENT = 1;

-- =============================================================================
-- 3. ZERAR ESTOQUE DOS PRODUTOS
-- =============================================================================

-- 3.1 Resetar estoque_atual para 0
UPDATE produtos SET estoque_atual = 0;
SELECT 'Estoque de todos os produtos resetado para 0' as status;

-- 3.2 Verificar resultado
SELECT 
    COUNT(*) as total_produtos,
    SUM(estoque_atual) as estoque_total
FROM produtos
WHERE ativo = 1;

-- =============================================================================
-- 4. REABILITAR CHAVES ESTRANGEIRAS
-- =============================================================================

SET FOREIGN_KEY_CHECKS = 1;
SELECT 'Chaves estrangeiras reabilitadas' as status;

-- =============================================================================
-- 5. VALIDAR ESTADO FINAL
-- =============================================================================

-- 5.1 Contar registros em todas as tabelas
SELECT 'VALIDAÇÃO FINAL' as secao;

SELECT 
    'produtos' as tabela,
    COUNT(*) as total
FROM produtos
UNION ALL
SELECT 'categorias', COUNT(*) FROM categorias
UNION ALL
SELECT 'itens_comanda', COUNT(*) FROM itens_comanda
UNION ALL
SELECT 'comandas', COUNT(*) FROM comandas
UNION ALL
SELECT 'movimentacoes_estoque', COUNT(*) FROM movimentacoes_estoque
UNION ALL
SELECT 'perdas_estoque', COUNT(*) FROM perdas_estoque
UNION ALL
SELECT 'comprovantes_venda', COUNT(*) FROM comprovantes_venda
UNION ALL
SELECT 'tipos_ajuste_estoque', COUNT(*) FROM tipos_ajuste_estoque;

-- 5.2 Verificar estoque dos produtos
SELECT 
    'Produtos com estoque resetado:' as descricao,
    COUNT(*) as total_produtos,
    SUM(estoque_atual) as estoque_total,
    MAX(estoque_atual) as maximo,
    MIN(estoque_atual) as minimo
FROM produtos
WHERE ativo = 1;

-- 5.3 Listar todos os produtos (para confirmar que não foram deletados)
SELECT 
    id,
    nome,
    categoria_id,
    preco,
    estoque_atual,
    ativo
FROM produtos
ORDER BY id;

-- =============================================================================
-- 6. RESUMO FINAL
-- =============================================================================

SELECT CONCAT(
    '\n',
    '╔════════════════════════════════════════════════════╗\n',
    '║          ✅ LIMPEZA CONCLUÍDA COM SUCESSO         ║\n',
    '╠════════════════════════════════════════════════════╣\n',
    '║ • Histórico de movimentações: ZERADO              ║\n',
    '║ • Histórico de vendas: ZERADO                     ║\n',
    '║ • Histórico de perdas: ZERADO                     ║\n',
    '║ • Comprovantes de venda: ZERADO                   ║\n',
    '║ • Estoque dos produtos: ZERADO                    ║\n',
    '║ • Produtos cadastrados: MANTIDOS ✅               ║\n',
    '║ • Categorias: MANTIDAS ✅                         ║\n',
    '║ • Tipos de ajuste: MANTIDOS ✅                    ║\n',
    '╠════════════════════════════════════════════════════╣\n',
    '║ Timestamp: ', NOW(), '\n',
    '╚════════════════════════════════════════════════════╝\n'
) as mensagem;

-- =============================================================================
-- 7. VERIFICAÇÃO DE SEGURANÇA: Confirmar que estoque está zerado
-- =============================================================================

SELECT IF(
    (SELECT COALESCE(SUM(estoque_atual), 0) FROM produtos) = 0,
    '✅ ESTOQUE COMPLETAMENTE ZERADO',
    '❌ ERRO: Ainda há estoque no sistema!'
) as verificacao_seguranca;

-- =============================================================================
-- ⚠️ NOTAS IMPORTANTES
-- =============================================================================
-- 1. Este script ZERA TODOS os dados históricos
-- 2. Desabilita e reabilita chaves estrangeiras automaticamente
-- 3. Mantém apenas:
--    - Produtos cadastrados
--    - Categorias
--    - Tipos de ajuste de estoque
--    - Garçons (se existir tabela)
--    - Configurações gerais
-- 4. ZERA:
--    - Todas as movimentações de estoque
--    - Todas as vendas (itens_comanda + comandas)
--    - Todas as perdas de estoque
--    - Comprovantes de venda
--    - Estoque atual de todos os produtos (resetado para 0)
-- 5. Use TRUNCATE (mais rápido e seguro que DELETE)
-- 6. Se precisar recuperar, use o BACKUP criado antes
-- =============================================================================

-- =============================================================================
-- FIM DO SCRIPT
-- =============================================================================
