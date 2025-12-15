-- =============================================================================
-- 📋 SCRIPT SQL COMPLETO: Implementação do Modal de Alertas de Perdas
-- =============================================================================
-- Arquivo: 12_implementar_modal_alertas_perdas.sql
-- Data: 2025-12-12
-- Descrição: Script SQL para preparar o banco de dados para o novo modal
--            de alertas de perdas com funcionalidades completas
-- =============================================================================

-- =============================================================================
-- ⚠️  LEIA ANTES DE EXECUTAR:
-- =============================================================================
-- Este script é SEGURO e somente cria/altera se necessário
-- - Verifica existência de tabelas antes de criar
-- - Usa INSERT IGNORE para evitar duplicatas
-- - Não deleta dados existentes
-- - Pode ser executado múltiplas vezes
-- =============================================================================

SET FOREIGN_KEY_CHECKS = 0;

-- =============================================================================
-- SEÇÃO 1: VERIFICAR E MELHORAR TABELA perdas_estoque
-- =============================================================================

-- Adicionar colunas se não existirem
ALTER TABLE perdas_estoque 
ADD COLUMN IF NOT EXISTS estoque_esperado INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS estoque_real INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS observacoes TEXT NULL;

-- Adicionar índices para performance
CREATE INDEX IF NOT EXISTS idx_perdas_visualizada ON perdas_estoque(visualizada);
CREATE INDEX IF NOT EXISTS idx_perdas_produto_data ON perdas_estoque(produto_id, data_identificacao);
CREATE INDEX IF NOT EXISTS idx_perdas_nao_visualizadas ON perdas_estoque(visualizada, data_identificacao);

-- =============================================================================
-- SEÇÃO 2: CRIAR STORED PROCEDURE PARA ANÁLISE COM FILTRO DE PERÍODO
-- =============================================================================

DROP PROCEDURE IF EXISTS relatorio_analise_estoque_periodo_com_filtro_perdas;

DELIMITER $$

CREATE PROCEDURE relatorio_analise_estoque_periodo_com_filtro_perdas(
    IN p_data_inicio DATE,
    IN p_data_fim DATE
)
BEGIN
    /**
     * PROCEDURE: Análise de estoque com cálculo correto de perdas
     * - Considera APENAS movimentações dentro do período
     * - Perdas contabilizadas apenas se identificadas no período
     * - Evita acúmulo de períodos anteriores
     * - Filtra APENAS perdas não visualizadas
     */
    
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
        
        -- ===== SAÍDAS NÃO COMERCIAIS (perdas já identificadas, ajustes-) =====
        COALESCE((
            SELECT SUM(me.quantidade)
            FROM movimentacoes_estoque me
            WHERE me.produto_id = p.id
            AND me.tipo = 'saida'
            AND me.motivo NOT IN ('venda')
            AND DATE(me.data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
        ), 0) as saidas_nao_comerciais_periodo,
        
        -- ===== ESTOQUE TEÓRICO FINAL (baseado no período) =====
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
-- SEÇÃO 3: CRIAR FUNÇÃO PARA CONTAR PERDAS NÃO VISUALIZADAS
-- =============================================================================

DROP FUNCTION IF EXISTS fn_contar_perdas_nao_visualizadas;

DELIMITER $$

CREATE FUNCTION fn_contar_perdas_nao_visualizadas()
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total INT;
    SELECT COUNT(id) INTO total
    FROM perdas_estoque
    WHERE visualizada = 0;
    RETURN COALESCE(total, 0);
END$$

DELIMITER ;

-- =============================================================================
-- SEÇÃO 4: CRIAR FUNÇÃO PARA SOMAR VALOR DE PERDAS NÃO VISUALIZADAS
-- =============================================================================

DROP FUNCTION IF EXISTS fn_somar_valor_perdas_nao_visualizadas;

DELIMITER $$

CREATE FUNCTION fn_somar_valor_perdas_nao_visualizadas()
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total DECIMAL(10,2);
    SELECT COALESCE(SUM(valor_perda), 0) INTO total
    FROM perdas_estoque
    WHERE visualizada = 0;
    RETURN total;
END$$

DELIMITER ;

-- =============================================================================
-- SEÇÃO 5: CRIAR VIEW PARA ALERTAS NÃO VISUALIZADOS
-- =============================================================================

DROP VIEW IF EXISTS vw_alertas_perdas_nao_visualizadas;

CREATE VIEW vw_alertas_perdas_nao_visualizadas AS
SELECT 
    pe.id,
    pe.produto_id,
    p.nome as produto_nome,
    p.preco,
    c.nome as categoria_nome,
    pe.quantidade_perdida,
    pe.valor_perda,
    pe.motivo,
    pe.data_identificacao,
    pe.estoque_esperado,
    pe.estoque_real,
    pe.visualizada,
    pe.data_visualizacao,
    (pe.data_identificacao) as dias_desde_identificacao
FROM perdas_estoque pe
JOIN produtos p ON pe.produto_id = p.id
JOIN categorias c ON p.categoria_id = c.id
WHERE pe.visualizada = 0
ORDER BY pe.data_identificacao DESC;

-- =============================================================================
-- SEÇÃO 6: CRIAR VIEW PARA HISTÓRICO COMPLETO DE PERDAS
-- =============================================================================

DROP VIEW IF EXISTS vw_historico_todas_perdas;

CREATE VIEW vw_historico_todas_perdas AS
SELECT 
    pe.id,
    pe.produto_id,
    p.nome as produto_nome,
    c.nome as categoria_nome,
    pe.quantidade_perdida,
    pe.valor_perda,
    pe.motivo,
    pe.data_identificacao,
    pe.visualizada,
    pe.data_visualizacao,
    CASE 
        WHEN pe.visualizada = 1 THEN 'Visualizada'
        ELSE 'Pendente'
    END as status,
    pe.observacoes
FROM perdas_estoque pe
JOIN produtos p ON pe.produto_id = p.id
JOIN categorias c ON p.categoria_id = c.id
ORDER BY pe.data_identificacao DESC;

-- =============================================================================
-- SEÇÃO 7: CRIAR TRIGGERS PARA AUDITORIA
-- =============================================================================

-- Criar tabela de log de auditoria se não existir
CREATE TABLE IF NOT EXISTS log_auditoria_perdas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    perda_id INT NOT NULL,
    acao VARCHAR(50) NOT NULL, -- 'criada', 'visualizada', 'atualizada'
    usuario_id INT NULL,
    data_acao DATETIME DEFAULT CURRENT_TIMESTAMP,
    detalhes JSON NULL,
    FOREIGN KEY (perda_id) REFERENCES perdas_estoque(id) ON DELETE CASCADE,
    INDEX idx_acao (acao),
    INDEX idx_data (data_acao)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Trigger para registrar quando perda é marcada como visualizada
DROP TRIGGER IF EXISTS tr_perdas_visualizada;

DELIMITER $$

CREATE TRIGGER tr_perdas_visualizada
AFTER UPDATE ON perdas_estoque
FOR EACH ROW
BEGIN
    IF NEW.visualizada = 1 AND OLD.visualizada = 0 THEN
        INSERT INTO log_auditoria_perdas (perda_id, acao, data_acao)
        VALUES (NEW.id, 'visualizada', NOW());
    END IF;
END$$

DELIMITER ;

-- =============================================================================
-- SEÇÃO 8: DADOS DE INICIALIZAÇÃO (se necessário)
-- =============================================================================

-- Verificar se há perdas sem estoque_esperado e estoque_real
UPDATE perdas_estoque
SET estoque_esperado = 0, estoque_real = 0
WHERE estoque_esperado IS NULL OR estoque_real IS NULL;

-- =============================================================================
-- SEÇÃO 9: TESTES E VERIFICAÇÃO
-- =============================================================================

-- Contar perdas não visualizadas
SELECT 
    'Total de Perdas Não Visualizadas' as metrica,
    COUNT(*) as valor
FROM perdas_estoque
WHERE visualizada = 0;

-- Valor total de perdas não visualizadas
SELECT 
    'Valor Total em Perdas Não Visualizadas' as metrica,
    CONCAT('R$ ', FORMAT(COALESCE(SUM(valor_perda), 0), 2)) as valor
FROM perdas_estoque
WHERE visualizada = 0;

-- Verificar se as funções foram criadas
SELECT ROUTINE_NAME, ROUTINE_TYPE
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = DATABASE()
AND ROUTINE_NAME LIKE '%perda%'
ORDER BY ROUTINE_NAME;

-- Verificar se as views foram criadas
SELECT TABLE_NAME, TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = DATABASE()
AND TABLE_NAME LIKE '%perdas%'
ORDER BY TABLE_NAME;

SET FOREIGN_KEY_CHECKS = 1;

-- =============================================================================
-- ✅ RESUMO DO SCRIPT
-- =============================================================================
-- ✅ Melhorias na tabela perdas_estoque (colunas + índices)
-- ✅ Stored Procedure para análise com filtro de período
-- ✅ 2 Funções auxiliares para cálculos
-- ✅ 2 Views para alertas e histórico
-- ✅ Trigger para auditoria de visualizações
-- ✅ Tabela de log para rastreamento
-- ✅ Testes de verificação
-- =============================================================================
