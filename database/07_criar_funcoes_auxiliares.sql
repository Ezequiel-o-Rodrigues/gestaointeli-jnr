-- =============================================================================
-- 📋 SCRIPT 7: CRIAR FUNÇÕES AUXILIARES
-- =============================================================================
-- Arquivo: 07_criar_funcoes_auxiliares.sql
-- Descrição: Funções para cálculos de estoque e perdas
-- Tempo estimado: 2-5 segundos
-- =============================================================================

-- =============================================================================
-- 7.1 FUNÇÃO: ESTOQUE ACUMULADO ATÉ UMA DATA
-- =============================================================================

DROP FUNCTION IF EXISTS fn_estoque_acumulado;

DELIMITER $$

CREATE FUNCTION fn_estoque_acumulado(
    p_produto_id INT,
    p_data_fim DATE
) 
RETURNS INT
READS SQL DATA
DETERMINISTIC
BEGIN
    -- =====================================================================
    -- Calcula o estoque teórico acumulado até uma data específica
    -- Considera TODAS as movimentações (entradas - saídas)
    -- =====================================================================
    
    DECLARE v_estoque INT;
    
    SELECT COALESCE(SUM(
        CASE 
            WHEN tipo = 'entrada' THEN quantidade
            WHEN tipo = 'saida' THEN -quantidade
            ELSE 0
        END
    ), 0) INTO v_estoque
    FROM movimentacoes_estoque
    WHERE produto_id = p_produto_id
    AND DATE(data_movimentacao) <= p_data_fim;
    
    RETURN COALESCE(v_estoque, 0);
END$$

DELIMITER ;

-- =============================================================================
-- 7.2 FUNÇÃO: CALCULAR PERDA DE UM PRODUTO
-- =============================================================================

DROP FUNCTION IF EXISTS fn_calcular_perda;

DELIMITER $$

CREATE FUNCTION fn_calcular_perda(
    p_produto_id INT,
    p_data_fim DATE
)
RETURNS INT
READS SQL DATA
DETERMINISTIC
BEGIN
    -- =====================================================================
    -- Calcula a perda (diferença) entre estoque teórico e real
    -- Resultado é sempre >= 0 (GREATEST retorna máximo entre dois valores)
    -- =====================================================================
    
    DECLARE v_estoque_teorico INT;
    DECLARE v_estoque_real INT;
    DECLARE v_perda INT;
    
    -- Obter estoque teórico acumulado
    SET v_estoque_teorico = fn_estoque_acumulado(p_produto_id, p_data_fim);
    
    -- Obter estoque real
    SELECT estoque_atual INTO v_estoque_real FROM produtos WHERE id = p_produto_id;
    
    -- Calcular perda (nunca negativa)
    SET v_perda = GREATEST(v_estoque_teorico - v_estoque_real, 0);
    
    RETURN v_perda;
END$$

DELIMITER ;

-- =============================================================================
-- 7.3 TESTANDO FUNÇÕES
-- =============================================================================

-- Testar fn_estoque_acumulado com um produto
SELECT 
    p.id,
    p.nome,
    fn_estoque_acumulado(p.id, CURDATE()) as estoque_acumulado,
    p.estoque_atual as estoque_real
FROM produtos p
LIMIT 1;

-- Testar fn_calcular_perda
SELECT 
    p.id,
    p.nome,
    fn_estoque_acumulado(p.id, CURDATE()) as teorico,
    p.estoque_atual as `real`,
    fn_calcular_perda(p.id, CURDATE()) as perda
FROM produtos p
WHERE fn_calcular_perda(p.id, CURDATE()) > 0
ORDER BY perda DESC
LIMIT 10;

-- Verificar se funções foram criadas
SHOW CREATE FUNCTION fn_estoque_acumulado;
SHOW CREATE FUNCTION fn_calcular_perda;

-- =============================================================================
-- FIM DO SCRIPT
-- =============================================================================
