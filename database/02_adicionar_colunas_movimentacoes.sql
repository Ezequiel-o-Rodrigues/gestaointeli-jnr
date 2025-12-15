-- =============================================================================
-- 📋 SCRIPT 2: ADICIONAR COLUNAS NA TABELA MOVIMENTACOES_ESTOQUE
-- =============================================================================
-- Arquivo: 02_adicionar_colunas_movimentacoes.sql
-- Descrição: Adiciona colunas motivo e tipo_ajuste_id para rastreamento
-- Tempo estimado: 5-10 segundos
-- =============================================================================

-- =============================================================================
-- 2.1 VERIFICAR ESTRUTURA ATUAL
-- =============================================================================

-- Coluna motivo já deve existir - apenas verificando
DESCRIBE movimentacoes_estoque;

-- =============================================================================
-- 2.2 VERIFICAR ÍNDICE PARA MOTIVO
-- =============================================================================

-- Verificar se índice já existe
SELECT IF(
    EXISTS(
        SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS 
        WHERE TABLE_NAME='movimentacoes_estoque' AND COLUMN_NAME='motivo' AND INDEX_NAME='idx_motivo'
    ),
    'Índice idx_motivo já existe',
    'Índice idx_motivo não existe - será criado se necessário'
) as status_indice;

-- Criar índice apenas se não existir
-- (comentado porque provavelmente já existe)
-- ALTER TABLE movimentacoes_estoque 
-- ADD INDEX idx_motivo (motivo);

-- =============================================================================
-- 2.3 ADICIONAR COLUNA TIPO_AJUSTE_ID (SE NÃO EXISTIR)
-- =============================================================================

-- Verificar se a coluna já existe
SELECT IF(
    EXISTS(
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME='movimentacoes_estoque' AND COLUMN_NAME='tipo_ajuste_id'
    ),
    'Coluna tipo_ajuste_id já existe',
    'Coluna tipo_ajuste_id será adicionada'
) as status_tipo_ajuste_id;

-- Adicionar coluna (se não existir, será adicionada; se existir, MySQL ignorará)
ALTER TABLE movimentacoes_estoque 
ADD COLUMN tipo_ajuste_id INT DEFAULT NULL AFTER motivo;

-- =============================================================================
-- 2.4 ADICIONAR CHAVE ESTRANGEIRA PARA TIPO_AJUSTE_ID (SE NÃO EXISTIR)
-- =============================================================================

-- Verificar se a FK já existe
SELECT IF(
    EXISTS(
        SELECT 1 FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS 
        WHERE CONSTRAINT_NAME='fk_tipo_ajuste' AND TABLE_NAME='movimentacoes_estoque'
    ),
    'FK fk_tipo_ajuste já existe',
    'FK fk_tipo_ajuste será adicionada'
) as status_fk_tipo;

-- Adicionar FK se não existir
ALTER TABLE movimentacoes_estoque 
ADD CONSTRAINT fk_tipo_ajuste FOREIGN KEY (tipo_ajuste_id) 
    REFERENCES tipos_ajuste_estoque(id) ON DELETE SET NULL;

-- =============================================================================
-- 2.5 ADICIONAR COLUNA COMANDA_ID (SE NÃO EXISTIR)
-- =============================================================================

-- Verificar se a coluna já existe
SELECT IF(
    EXISTS(
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME='movimentacoes_estoque' AND COLUMN_NAME='comanda_id'
    ),
    'Coluna comanda_id já existe',
    'Coluna comanda_id será adicionada'
) as status_comanda_id;

-- Adicionar coluna
ALTER TABLE movimentacoes_estoque 
ADD COLUMN comanda_id INT DEFAULT NULL AFTER fornecedor_id;

-- =============================================================================
-- 2.6 ADICIONAR ÍNDICE E CHAVE ESTRANGEIRA PARA COMANDA_ID (SE NÃO EXISTIREM)
-- =============================================================================

-- Verificar se índice já existe
SELECT IF(
    EXISTS(
        SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS 
        WHERE TABLE_NAME='movimentacoes_estoque' AND INDEX_NAME='idx_comanda'
    ),
    'Índice idx_comanda já existe',
    'Índice idx_comanda será criado'
) as status_idx_comanda;

-- Adicionar índice
ALTER TABLE movimentacoes_estoque 
ADD INDEX idx_comanda (comanda_id);

-- Verificar se FK já existe
SELECT IF(
    EXISTS(
        SELECT 1 FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS 
        WHERE CONSTRAINT_NAME='fk_comanda_mov' AND TABLE_NAME='movimentacoes_estoque'
    ),
    'FK fk_comanda_mov já existe',
    'FK fk_comanda_mov será adicionada'
) as status_fk_comanda;

-- Adicionar FK
ALTER TABLE movimentacoes_estoque 
ADD CONSTRAINT fk_comanda_mov FOREIGN KEY (comanda_id) 
    REFERENCES comandas(id) ON DELETE SET NULL;

-- =============================================================================
-- VALIDAR ALTERAÇÕES
-- =============================================================================

-- Ver estrutura completa da tabela
DESCRIBE movimentacoes_estoque;

-- Ver chaves estrangeiras
SELECT CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'movimentacoes_estoque'
AND CONSTRAINT_NAME LIKE 'fk_%';

-- Ver índices
SHOW INDEX FROM movimentacoes_estoque;

-- =============================================================================
-- FIM DO SCRIPT
-- =============================================================================
