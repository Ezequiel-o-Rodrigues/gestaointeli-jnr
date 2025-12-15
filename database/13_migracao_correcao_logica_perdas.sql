-- ============================================================================
-- SCRIPT DE MIGRAÇÃO E CORREÇÃO DA LÓGICA DE CÁLCULO DE PERDAS
-- Data: 14 de Dezembro de 2025
-- Objetivo: Corrigir cálculos cumulativos por lógica periódica
-- ============================================================================

-- ============================================================================
-- PARTE 1: CRIAR TABELA DE FECHAMENTO DIÁRIO
-- ============================================================================

CREATE TABLE IF NOT EXISTS fechamento_diario_estoque (
    id INT PRIMARY KEY AUTO_INCREMENT,
    produto_id INT NOT NULL,
    data_fechamento DATE NOT NULL,
    estoque_real INT NOT NULL DEFAULT 0,
    estoque_teorico INT NOT NULL DEFAULT 0,
    diferenca INT NOT NULL DEFAULT 0,
    entradas_dia INT DEFAULT 0,
    vendas_dia INT DEFAULT 0,
    outras_saidas INT DEFAULT 0,
    status VARCHAR(20) DEFAULT 'pendente',
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_produto_data (produto_id, data_fechamento),
    FOREIGN KEY (produto_id) REFERENCES produtos(id) ON DELETE CASCADE,
    INDEX idx_data_fechamento (data_fechamento),
    INDEX idx_status (status),
    INDEX idx_produto_data (produto_id, data_fechamento)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- PARTE 2: ADICIONAR COLUNA DE PERÍODO À TABELA DE PERDAS
-- ============================================================================

ALTER TABLE perdas_estoque 
ADD COLUMN IF NOT EXISTS periodo_referencia DATE NULL AFTER data_identificacao,
ADD COLUMN IF NOT EXISTS estoque_inicial_periodo INT DEFAULT 0 AFTER periodo_referencia,
ADD COLUMN IF NOT EXISTS entradas_periodo INT DEFAULT 0 AFTER estoque_inicial_periodo,
ADD COLUMN IF NOT EXISTS vendas_periodo INT DEFAULT 0 AFTER entradas_periodo,
ADD INDEX IF NOT EXISTS idx_periodo_referencia (periodo_referencia),
ADD INDEX IF NOT EXISTS idx_periodo_visualizada (periodo_referencia, visualizada);

-- ============================================================================
-- PARTE 3: CRIAR STORED PROCEDURE DE FECHAMENTO DIÁRIO AUTOMÁTICO
-- ============================================================================

DROP PROCEDURE IF EXISTS gerar_fechamento_diario_automatico;
DELIMITER $$

CREATE PROCEDURE gerar_fechamento_diario_automatico(
    IN p_data DATE
)
BEGIN
    DECLARE v_produto_id INT;
    DECLARE v_estoque_inicial INT DEFAULT 0;
    DECLARE v_entradas INT DEFAULT 0;
    DECLARE v_vendas INT DEFAULT 0;
    DECLARE v_outras_saidas INT DEFAULT 0;
    DECLARE v_estoque_teorico INT DEFAULT 0;
    DECLARE v_estoque_real INT DEFAULT 0;
    DECLARE v_diferenca INT DEFAULT 0;
    DECLARE done INT DEFAULT FALSE;
    
    -- Cursor para iterar sobre todos os produtos
    DECLARE produto_cursor CURSOR FOR 
        SELECT DISTINCT p.id 
        FROM produtos p 
        WHERE p.ativo = 1;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Iniciar transação
    START TRANSACTION;
    
    OPEN produto_cursor;
    loop_produtos: LOOP
        FETCH produto_cursor INTO v_produto_id;
        IF done THEN
            LEAVE loop_produtos;
        END IF;
        
        -- 1. OBTER ESTOQUE INICIAL (do fechamento do dia anterior)
        SELECT COALESCE(estoque_real, 0) INTO v_estoque_inicial
        FROM fechamento_diario_estoque
        WHERE produto_id = v_produto_id 
        AND data_fechamento = DATE_SUB(p_data, INTERVAL 1 DAY)
        LIMIT 1;
        
        -- Se não existe fechamento anterior, usar estoque atual
        IF v_estoque_inicial = 0 THEN
            SELECT COALESCE(estoque_atual, 0) INTO v_estoque_inicial
            FROM produtos
            WHERE id = v_produto_id;
        END IF;
        
        -- 2. CONTAR ENTRADAS DO DIA
        SELECT COALESCE(SUM(quantidade), 0) INTO v_entradas
        FROM movimentacoes_estoque
        WHERE produto_id = v_produto_id
        AND DATE(data_movimentacao) = p_data
        AND tipo_movimentacao = 'entrada';
        
        -- 3. CONTAR VENDAS DO DIA
        SELECT COALESCE(SUM(quantidade), 0) INTO v_vendas
        FROM itens_comanda ic
        JOIN comandas c ON ic.comanda_id = c.id
        WHERE ic.produto_id = v_produto_id
        AND DATE(c.data_abertura) = p_data;
        
        -- 4. CONTAR OUTRAS SAÍDAS DO DIA
        SELECT COALESCE(SUM(quantidade), 0) INTO v_outras_saidas
        FROM movimentacoes_estoque
        WHERE produto_id = v_produto_id
        AND DATE(data_movimentacao) = p_data
        AND tipo_movimentacao IN ('saida', 'ajuste', 'danos');
        
        -- 5. CALCULAR ESTOQUE TEÓRICO
        SET v_estoque_teorico = v_estoque_inicial + v_entradas - v_vendas - v_outras_saidas;
        
        -- 6. OBTER ESTOQUE REAL ATUAL
        SELECT COALESCE(estoque_atual, 0) INTO v_estoque_real
        FROM produtos
        WHERE id = v_produto_id;
        
        -- 7. CALCULAR DIFERENÇA
        SET v_diferenca = v_estoque_teorico - v_estoque_real;
        
        -- 8. INSERIR OU ATUALIZAR FECHAMENTO DO DIA
        INSERT INTO fechamento_diario_estoque 
        (produto_id, data_fechamento, estoque_real, estoque_teorico, diferenca, 
         entradas_dia, vendas_dia, outras_saidas, status)
        VALUES 
        (v_produto_id, p_data, v_estoque_real, v_estoque_teorico, v_diferenca, 
         v_entradas, v_vendas, v_outras_saidas, 'concluido')
        ON DUPLICATE KEY UPDATE
            estoque_real = v_estoque_real,
            estoque_teorico = v_estoque_teorico,
            diferenca = v_diferenca,
            entradas_dia = v_entradas,
            vendas_dia = v_vendas,
            outras_saidas = v_outras_saidas,
            status = 'concluido',
            atualizado_em = CURRENT_TIMESTAMP;
        
        -- 9. ATUALIZAR REGISTROS DE PERDA COM DADOS DO PERÍODO
        UPDATE perdas_estoque
        SET 
            periodo_referencia = p_data,
            estoque_inicial_periodo = v_estoque_inicial,
            entradas_periodo = v_entradas,
            vendas_periodo = v_vendas
        WHERE produto_id = v_produto_id
        AND DATE(data_identificacao) = p_data
        AND periodo_referencia IS NULL;
        
    END LOOP;
    CLOSE produto_cursor;
    
    COMMIT;
    
    -- Retornar status
    SELECT 'Fechamento diário gerado com sucesso' AS mensagem, p_data AS data_processada;
    
END$$

DELIMITER ;

-- ============================================================================
-- PARTE 4: STORED PROCEDURE CORRIGIDA PARA RELATÓRIO DE ESTOQUE
-- ============================================================================

DROP PROCEDURE IF EXISTS relatorio_analise_estoque_periodo_corrigido;
DELIMITER $$

CREATE PROCEDURE relatorio_analise_estoque_periodo_corrigido(
    IN p_data_inicio DATE,
    IN p_data_fim DATE
)
BEGIN
    DECLARE p_data_inicio_anterior DATE;
    SET p_data_inicio_anterior = DATE_SUB(p_data_inicio, INTERVAL 1 DAY);
    
    SELECT 
        p.id,
        p.nome,
        cat.nome AS categoria,
        
        -- ===== ESTOQUE INICIAL (do fechamento do dia anterior) =====
        COALESCE(
            (SELECT estoque_real 
             FROM fechamento_diario_estoque 
             WHERE produto_id = p.id 
             AND data_fechamento = p_data_inicio_anterior 
             LIMIT 1),
            p.estoque_atual  -- fallback para estoque atual se não existe fechamento
        ) AS estoque_inicial,
        
        -- ===== ENTRADAS DO PERÍODO =====
        COALESCE(
            (SELECT SUM(quantidade) 
             FROM movimentacoes_estoque 
             WHERE produto_id = p.id 
             AND DATE(data_movimentacao) BETWEEN p_data_inicio AND p_data_fim 
             AND tipo_movimentacao = 'entrada'),
            0
        ) AS entradas_periodo,
        
        -- ===== VENDAS DO PERÍODO =====
        COALESCE(
            (SELECT SUM(ic.quantidade) 
             FROM itens_comanda ic 
             JOIN comandas c ON ic.comanda_id = c.id 
             WHERE ic.produto_id = p.id 
             AND DATE(c.data_abertura) BETWEEN p_data_inicio AND p_data_fim),
            0
        ) AS vendidas_periodo,
        
        -- ===== OUTRAS SAÍDAS DO PERÍODO =====
        COALESCE(
            (SELECT SUM(quantidade) 
             FROM movimentacoes_estoque 
             WHERE produto_id = p.id 
             AND DATE(data_movimentacao) BETWEEN p_data_inicio AND p_data_fim 
             AND tipo_movimentacao IN ('saida', 'ajuste', 'danos')),
            0
        ) AS outras_saidas_periodo,
        
        -- ===== ESTOQUE TEÓRICO FINAL =====
        (
            COALESCE(
                (SELECT estoque_real 
                 FROM fechamento_diario_estoque 
                 WHERE produto_id = p.id 
                 AND data_fechamento = p_data_inicio_anterior 
                 LIMIT 1),
                p.estoque_atual
            ) 
            + 
            COALESCE(
                (SELECT SUM(quantidade) 
                 FROM movimentacoes_estoque 
                 WHERE produto_id = p.id 
                 AND DATE(data_movimentacao) BETWEEN p_data_inicio AND p_data_fim 
                 AND tipo_movimentacao = 'entrada'),
                0
            )
            -
            COALESCE(
                (SELECT SUM(ic.quantidade) 
                 FROM itens_comanda ic 
                 JOIN comandas c ON ic.comanda_id = c.id 
                 WHERE ic.produto_id = p.id 
                 AND DATE(c.data_abertura) BETWEEN p_data_inicio AND p_data_fim),
                0
            )
            -
            COALESCE(
                (SELECT SUM(quantidade) 
                 FROM movimentacoes_estoque 
                 WHERE produto_id = p.id 
                 AND DATE(data_movimentacao) BETWEEN p_data_inicio AND p_data_fim 
                 AND tipo_movimentacao IN ('saida', 'ajuste', 'danos')),
                0
            )
        ) AS estoque_teorico_final,
        
        -- ===== ESTOQUE REAL ATUAL =====
        p.estoque_atual AS estoque_real_atual,
        
        -- ===== PERDAS (SÓ DO PERÍODO) =====
        GREATEST(0,
            (
                COALESCE(
                    (SELECT estoque_real 
                     FROM fechamento_diario_estoque 
                     WHERE produto_id = p.id 
                     AND data_fechamento = p_data_inicio_anterior 
                     LIMIT 1),
                    p.estoque_atual
                ) 
                + 
                COALESCE(
                    (SELECT SUM(quantidade) 
                     FROM movimentacoes_estoque 
                     WHERE produto_id = p.id 
                     AND DATE(data_movimentacao) BETWEEN p_data_inicio AND p_data_fim 
                     AND tipo_movimentacao = 'entrada'),
                    0
                )
                -
                COALESCE(
                    (SELECT SUM(ic.quantidade) 
                     FROM itens_comanda ic 
                     JOIN comandas c ON ic.comanda_id = c.id 
                     WHERE ic.produto_id = p.id 
                     AND DATE(c.data_abertura) BETWEEN p_data_inicio AND p_data_fim),
                    0
                )
                -
                COALESCE(
                    (SELECT SUM(quantidade) 
                     FROM movimentacoes_estoque 
                     WHERE produto_id = p.id 
                     AND DATE(data_movimentacao) BETWEEN p_data_inicio AND p_data_fim 
                     AND tipo_movimentacao IN ('saida', 'ajuste', 'danos')),
                    0
                )
            ) - p.estoque_atual
        ) AS perdas_quantidade,
        
        -- ===== VALOR DAS PERDAS =====
        ROUND(
            GREATEST(0,
                (
                    COALESCE(
                        (SELECT estoque_real 
                         FROM fechamento_diario_estoque 
                         WHERE produto_id = p.id 
                         AND data_fechamento = p_data_inicio_anterior 
                         LIMIT 1),
                        p.estoque_atual
                    ) 
                    + 
                    COALESCE(
                        (SELECT SUM(quantidade) 
                         FROM movimentacoes_estoque 
                         WHERE produto_id = p.id 
                         AND DATE(data_movimentacao) BETWEEN p_data_inicio AND p_data_fim 
                         AND tipo_movimentacao = 'entrada'),
                        0
                    )
                    -
                    COALESCE(
                        (SELECT SUM(ic.quantidade) 
                         FROM itens_comanda ic 
                         JOIN comandas c ON ic.comanda_id = c.id 
                         WHERE ic.produto_id = p.id 
                         AND DATE(c.data_abertura) BETWEEN p_data_inicio AND p_data_fim),
                        0
                    )
                    -
                    COALESCE(
                        (SELECT SUM(quantidade) 
                         FROM movimentacoes_estoque 
                         WHERE produto_id = p.id 
                         AND DATE(data_movimentacao) BETWEEN p_data_inicio AND p_data_fim 
                         AND tipo_movimentacao IN ('saida', 'ajuste', 'danos')),
                        0
                    )
                ) - p.estoque_atual
            ) * p.preco,
            2
        ) AS perdas_valor,
        
        -- ===== FATURAMENTO DO PERÍODO =====
        ROUND(
            COALESCE(
                (SELECT SUM(ic.quantidade * ic.preco_unitario) 
                 FROM itens_comanda ic 
                 JOIN comandas c ON ic.comanda_id = c.id 
                 WHERE ic.produto_id = p.id 
                 AND DATE(c.data_abertura) BETWEEN p_data_inicio AND p_data_fim),
                0
            ),
            2
        ) AS faturamento_periodo
        
    FROM produtos p
    LEFT JOIN categorias cat ON p.categoria_id = cat.id
    WHERE p.ativo = 1
    ORDER BY perdas_quantidade DESC, p.nome ASC;
    
END$$

DELIMITER ;

-- ============================================================================
-- PARTE 5: CRIAR FUNÇÃO PARA CÁLCULO DE PERDAS COM CONTEXTO DE PERÍODO
-- ============================================================================

DROP FUNCTION IF EXISTS fn_calcular_perda_periodo;
DELIMITER $$

CREATE FUNCTION fn_calcular_perda_periodo(
    p_produto_id INT,
    p_data_inicio DATE,
    p_data_fim DATE
) RETURNS INT DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE v_estoque_inicial INT;
    DECLARE v_entradas INT;
    DECLARE v_vendas INT;
    DECLARE v_saidas INT;
    DECLARE v_estoque_teorico INT;
    DECLARE v_estoque_real INT;
    DECLARE v_perda INT;
    DECLARE v_data_anterior DATE;
    
    SET v_data_anterior = DATE_SUB(p_data_inicio, INTERVAL 1 DAY);
    
    -- Estoque inicial (do fechamento anterior)
    SELECT COALESCE(estoque_real, 0) INTO v_estoque_inicial
    FROM fechamento_diario_estoque
    WHERE produto_id = p_produto_id
    AND data_fechamento = v_data_anterior
    LIMIT 1;
    
    IF v_estoque_inicial = 0 THEN
        SELECT COALESCE(estoque_atual, 0) INTO v_estoque_inicial
        FROM produtos WHERE id = p_produto_id;
    END IF;
    
    -- Entradas do período
    SELECT COALESCE(SUM(quantidade), 0) INTO v_entradas
    FROM movimentacoes_estoque
    WHERE produto_id = p_produto_id
    AND DATE(data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
    AND tipo_movimentacao = 'entrada';
    
    -- Vendas do período
    SELECT COALESCE(SUM(ic.quantidade), 0) INTO v_vendas
    FROM itens_comanda ic
    JOIN comandas c ON ic.comanda_id = c.id
    WHERE ic.produto_id = p_produto_id
    AND DATE(c.data_abertura) BETWEEN p_data_inicio AND p_data_fim;
    
    -- Outras saídas do período
    SELECT COALESCE(SUM(quantidade), 0) INTO v_saidas
    FROM movimentacoes_estoque
    WHERE produto_id = p_produto_id
    AND DATE(data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
    AND tipo_movimentacao IN ('saida', 'ajuste', 'danos');
    
    -- Cálculos
    SET v_estoque_teorico = v_estoque_inicial + v_entradas - v_vendas - v_saidas;
    
    SELECT COALESCE(estoque_atual, 0) INTO v_estoque_real
    FROM produtos WHERE id = p_produto_id;
    
    SET v_perda = GREATEST(0, v_estoque_teorico - v_estoque_real);
    
    RETURN v_perda;
END$$

DELIMITER ;

-- ============================================================================
-- PARTE 6: CRIAR VIEW PARA RELATÓRIO SIMPLIFICADO
-- ============================================================================

DROP VIEW IF EXISTS vw_relatorio_estoque_preciso;

CREATE VIEW vw_relatorio_estoque_preciso AS
SELECT 
    p.id,
    p.nome AS produto_nome,
    cat.nome AS categoria_nome,
    p.estoque_atual,
    p.preco,
    -- Referência para cálculos: data atual - 1 dia
    DATE_SUB(CURDATE(), INTERVAL 1 DAY) AS data_referencia_inicio
FROM produtos p
LEFT JOIN categorias cat ON p.categoria_id = cat.id
WHERE p.ativo = 1;

-- ============================================================================
-- PARTE 7: VERIFICAÇÃO E TESTES
-- ============================================================================

-- Teste 1: Verificar se tabela foi criada
SELECT 'Tabela fechamento_diario_estoque criada com sucesso' AS status;

-- Teste 2: Testar procedure com data de exemplo
-- CALL gerar_fechamento_diario_automatico('2025-12-14');

-- Teste 3: Testar relatório com período
-- CALL relatorio_analise_estoque_periodo_corrigido('2025-12-14', '2025-12-14');

-- Teste 4: Verificar função
-- SELECT fn_calcular_perda_periodo(1, '2025-12-14', '2025-12-14') AS perdas;

-- ============================================================================
-- FIM DO SCRIPT
-- ============================================================================
