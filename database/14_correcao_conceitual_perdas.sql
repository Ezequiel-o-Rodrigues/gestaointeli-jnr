-- ============================================================================
-- SCRIPT DE CORREÇÃO CONCEITUAL DA LÓGICA DE PERDAS
-- Data: 14 de Dezembro de 2025
-- Objetivo: Separar divergência acumulada de perdas periódicas
-- ============================================================================

-- ============================================================================
-- PARTE 1: CRIAR TABELA DE SNAPSHOTS DIÁRIOS
-- ============================================================================

CREATE TABLE IF NOT EXISTS estoque_snapshots (
    id INT PRIMARY KEY AUTO_INCREMENT,
    produto_id INT NOT NULL,
    data_snapshot DATE NOT NULL,
    estoque_real INT NOT NULL COMMENT 'Estoque real no fim do dia',
    estoque_teorico INT NOT NULL COMMENT 'O que deveria ter baseado em todas as movimentações',
    divergencia INT DEFAULT 0 COMMENT 'Diferença entre teórico e real',
    entradas_dia INT DEFAULT 0,
    saidas_dia INT DEFAULT 0,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_produto_data (produto_id, data_snapshot),
    FOREIGN KEY (produto_id) REFERENCES produtos(id) ON DELETE CASCADE,
    INDEX idx_data_snapshot (data_snapshot),
    INDEX idx_produto_data (produto_id, data_snapshot),
    INDEX idx_divergencia (divergencia)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Snapshots diários do estoque para cálculos precisos de perdas periódicas';

-- ============================================================================
-- PARTE 2: CRIAR TABELA DE HISTÓRICO DE AJUSTES
-- ============================================================================

CREATE TABLE IF NOT EXISTS historico_ajustes_estoque (
    id INT PRIMARY KEY AUTO_INCREMENT,
    produto_id INT NOT NULL,
    divergencia_detectada INT NOT NULL,
    data_ajuste DATE NOT NULL,
    ajuste_aplicado INT NOT NULL,
    motivo VARCHAR(255),
    observacao TEXT,
    ajustado_por INT,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (produto_id) REFERENCES produtos(id) ON DELETE CASCADE,
    INDEX idx_data_ajuste (data_ajuste),
    INDEX idx_produto (produto_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Histórico de ajustes de divergência de estoque';

-- ============================================================================
-- PARTE 3: FUNÇÃO PARA CALCULAR ESTOQUE TEÓRICO ATÉ UMA DATA
-- ============================================================================

DROP FUNCTION IF EXISTS fn_estoque_teorico_ate_data;
DELIMITER $$

CREATE FUNCTION fn_estoque_teorico_ate_data(
    p_produto_id INT,
    p_data DATE
) RETURNS INT DETERMINISTIC READS SQL DATA
COMMENT 'Calcula o estoque teórico até uma data considerando APENAS entradas (inventários)'
BEGIN
    DECLARE v_entradas INT DEFAULT 0;
    DECLARE v_saidas INT DEFAULT 0;
    
    -- Somar TODAS as entradas (inventários) até a data
    SELECT COALESCE(SUM(quantidade), 0) INTO v_entradas
    FROM movimentacoes_estoque
    WHERE produto_id = p_produto_id
    AND DATE(data_movimentacao) <= p_data
    AND tipo = 'entrada';
    
    -- Somar TODAS as saídas até a data (vendas)
    SELECT COALESCE(SUM(ic.quantidade), 0) INTO v_saidas
    FROM itens_comanda ic
    JOIN comandas c ON ic.comanda_id = c.id
    WHERE ic.produto_id = p_produto_id
    AND DATE(c.data_venda) <= p_data;
    
    RETURN GREATEST(0, v_entradas - v_saidas);
END$$

DELIMITER ;

-- ============================================================================
-- PARTE 4: FUNÇÃO PARA CALCULAR DIVERGÊNCIA ATUAL
-- ============================================================================

DROP FUNCTION IF EXISTS fn_divergencia_atual;
DELIMITER $$

CREATE FUNCTION fn_divergencia_atual(p_produto_id INT) 
RETURNS INT DETERMINISTIC READS SQL DATA
COMMENT 'Calcula a divergência entre estoque teórico e real HOJE'
BEGIN
    DECLARE v_estoque_teorico INT;
    DECLARE v_estoque_real INT;
    
    -- Calcular estoque teórico até hoje
    SELECT fn_estoque_teorico_ate_data(p_produto_id, CURDATE()) INTO v_estoque_teorico;
    
    -- Pegar estoque real
    SELECT COALESCE(estoque_atual, 0) INTO v_estoque_real
    FROM produtos WHERE id = p_produto_id;
    
    -- Retornar divergência (positivo = faltam produtos, negativo = sobram)
    RETURN v_estoque_teorico - v_estoque_real;
END$$

DELIMITER ;

-- ============================================================================
-- PARTE 5: STORED PROCEDURE PARA GERAR SNAPSHOT DIÁRIO
-- ============================================================================

DROP PROCEDURE IF EXISTS gerar_snapshot_diario_corrigido;
DELIMITER $$

CREATE PROCEDURE gerar_snapshot_diario_corrigido(IN p_data DATE)
COMMENT 'Gera snapshot diário de estoque para TODOS os produtos'
BEGIN
    DECLARE v_produto_id INT;
    DECLARE v_estoque_real INT;
    DECLARE v_estoque_teorico INT;
    DECLARE v_divergencia INT;
    DECLARE v_entradas INT;
    DECLARE v_saidas INT;
    DECLARE done INT DEFAULT FALSE;
    
    DECLARE produto_cursor CURSOR FOR 
        SELECT id FROM produtos WHERE ativo = 1;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    START TRANSACTION;
    
    OPEN produto_cursor;
    loop_produtos: LOOP
        FETCH produto_cursor INTO v_produto_id;
        IF done THEN
            LEAVE loop_produtos;
        END IF;
        
        -- 1. Pegar estoque real ATUAL do produto
        SELECT COALESCE(estoque_atual, 0) INTO v_estoque_real
        FROM produtos WHERE id = v_produto_id;
        
        -- 2. Calcular estoque teórico até a data
        SELECT fn_estoque_teorico_ate_data(v_produto_id, p_data) INTO v_estoque_teorico;
        
        -- 3. Calcular divergência
        SET v_divergencia = v_estoque_teorico - v_estoque_real;
        
        -- 4. Contar entradas do dia
        SELECT COALESCE(SUM(quantidade), 0) INTO v_entradas
        FROM movimentacoes_estoque
        WHERE produto_id = v_produto_id
        AND DATE(data_movimentacao) = p_data
        AND tipo = 'entrada';
        
        -- 5. Contar saídas do dia
        SELECT COALESCE(
            (SELECT SUM(ic.quantidade)
             FROM itens_comanda ic
             JOIN comandas c ON ic.comanda_id = c.id
             WHERE ic.produto_id = v_produto_id
             AND DATE(c.data_venda) = p_data)
            +
            (SELECT SUM(quantidade)
             FROM movimentacoes_estoque
             WHERE produto_id = v_produto_id
             AND DATE(data_movimentacao) = p_data
             AND tipo = 'saida'),
            0
        ) INTO v_saidas;
        
        -- 6. Inserir ou atualizar snapshot
        INSERT INTO estoque_snapshots 
        (produto_id, data_snapshot, estoque_real, estoque_teorico, divergencia, entradas_dia, saidas_dia)
        VALUES 
        (v_produto_id, p_data, v_estoque_real, v_estoque_teorico, v_divergencia, v_entradas, v_saidas)
        ON DUPLICATE KEY UPDATE
            estoque_real = v_estoque_real,
            estoque_teorico = v_estoque_teorico,
            divergencia = v_divergencia,
            entradas_dia = v_entradas,
            saidas_dia = v_saidas;
        
    END LOOP;
    CLOSE produto_cursor;
    
    COMMIT;
    
    SELECT 'Snapshot diário gerado com sucesso' AS mensagem, p_data AS data_processada;
END$$

DELIMITER ;

-- ============================================================================
-- PARTE 6: FUNÇÃO PARA CALCULAR PERDAS DE UM PERÍODO ESPECÍFICO
-- ============================================================================

DROP FUNCTION IF EXISTS fn_perdas_periodo;
DELIMITER $$

CREATE FUNCTION fn_perdas_periodo(
    p_produto_id INT,
    p_data_inicio DATE,
    p_data_fim DATE
) RETURNS INT DETERMINISTIC READS SQL DATA
COMMENT 'Calcula perdas APENAS DO PERÍODO usando snapshot do dia anterior'
BEGIN
    DECLARE v_estoque_real_inicio INT DEFAULT 0;
    DECLARE v_entradas INT DEFAULT 0;
    DECLARE v_saidas INT DEFAULT 0;
    DECLARE v_estoque_teorico_periodo INT;
    DECLARE v_estoque_real_fim INT;
    DECLARE v_perda INT;
    
    -- 1. Estoque real do INÍCIO do período (snapshot do dia anterior)
    SELECT COALESCE(estoque_real, 0) INTO v_estoque_real_inicio
    FROM estoque_snapshots
    WHERE produto_id = p_produto_id
    AND data_snapshot = DATE_SUB(p_data_inicio, INTERVAL 1 DAY)
    LIMIT 1;
    
    -- Se não existe snapshot, usar 0 (significa que no dia anterior não havia nada ou é primeiro registro)
    
    -- 2. Entradas do período (inventários)
    SELECT COALESCE(SUM(quantidade), 0) INTO v_entradas
    FROM movimentacoes_estoque
    WHERE produto_id = p_produto_id
    AND DATE(data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
    AND tipo = 'entrada';
    
    -- 3. Saídas do período (vendas)
    SELECT COALESCE(SUM(ic.quantidade), 0) INTO v_saidas
    FROM itens_comanda ic
    JOIN comandas c ON ic.comanda_id = c.id
    WHERE ic.produto_id = p_produto_id
    AND DATE(c.data_venda) BETWEEN p_data_inicio AND p_data_fim;
    
    -- 4. Estoque teórico esperado no fim do período = Inicial + Entradas - Vendas
    SET v_estoque_teorico_periodo = v_estoque_real_inicio + v_entradas - v_saidas;
    
    -- 5. Estoque real no fim do período (estoque_atual)
    SELECT COALESCE(estoque_atual, 0) INTO v_estoque_real_fim
    FROM produtos WHERE id = p_produto_id;
    
    -- 6. Perdas do período = O que deveria ter - O que tem
    SET v_perda = GREATEST(0, v_estoque_teorico_periodo - v_estoque_real_fim);
    
    RETURN v_perda;
END$$

DELIMITER ;

-- ============================================================================
-- PARTE 7: STORED PROCEDURE PARA RELATÓRIO CORRETO DE PERÍODO
-- ============================================================================

DROP PROCEDURE IF EXISTS relatorio_perdas_periodo_correto;
DELIMITER $$

CREATE PROCEDURE relatorio_perdas_periodo_correto(
    IN p_data_inicio DATE,
    IN p_data_fim DATE
)
COMMENT 'Relatório de perdas do período usando snapshots para evitar perdas antigas'
BEGIN
    SELECT 
        p.id,
        p.nome,
        cat.nome AS categoria,
        p.preco,
        
        -- ===== ESTOQUE REAL DO INÍCIO (snapshot dia anterior) =====
        COALESCE(
            (SELECT estoque_real FROM estoque_snapshots 
             WHERE produto_id = p.id 
             AND data_snapshot = DATE_SUB(p_data_inicio, INTERVAL 1 DAY) 
             LIMIT 1),
            0
        ) AS estoque_inicial,
        
        -- ===== ENTRADAS DO PERÍODO (Inventários) =====
        COALESCE(
            (SELECT SUM(quantidade) FROM movimentacoes_estoque 
             WHERE produto_id = p.id 
             AND DATE(data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
             AND tipo = 'entrada'),
            0
        ) AS entradas_periodo,
        
        -- ===== SAÍDAS DO PERÍODO (Vendas) =====
        COALESCE(
            (SELECT SUM(ic.quantidade) FROM itens_comanda ic
             JOIN comandas c ON ic.comanda_id = c.id
             WHERE ic.produto_id = p.id
             AND DATE(c.data_venda) BETWEEN p_data_inicio AND p_data_fim),
            0
        ) AS saidas_periodo,
        
        -- ===== ESTOQUE TEÓRICO FINAL DO PERÍODO =====
        (
            COALESCE(
                (SELECT estoque_real FROM estoque_snapshots 
                 WHERE produto_id = p.id 
                 AND data_snapshot = DATE_SUB(p_data_inicio, INTERVAL 1 DAY) 
                 LIMIT 1),
                0
            )
            +
            COALESCE(
                (SELECT SUM(quantidade) FROM movimentacoes_estoque 
                 WHERE produto_id = p.id 
                 AND DATE(data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
                 AND tipo = 'entrada'),
                0
            )
            -
            COALESCE(
                (SELECT SUM(ic.quantidade) FROM itens_comanda ic
                 JOIN comandas c ON ic.comanda_id = c.id
                 WHERE ic.produto_id = p.id
                 AND DATE(c.data_venda) BETWEEN p_data_inicio AND p_data_fim),
                0
            )
        ) AS estoque_teorico_final,
        
        -- ===== ESTOQUE REAL FINAL =====
        COALESCE(p.estoque_atual, 0) AS estoque_real_final,
        
        -- ===== PERDAS DO PERÍODO =====
        GREATEST(0,
            (
                COALESCE(
                    (SELECT estoque_real FROM estoque_snapshots 
                     WHERE produto_id = p.id 
                     AND data_snapshot = DATE_SUB(p_data_inicio, INTERVAL 1 DAY) 
                     LIMIT 1),
                    0
                )
                +
                COALESCE(
                    (SELECT SUM(quantidade) FROM movimentacoes_estoque 
                     WHERE produto_id = p.id 
                     AND DATE(data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
                     AND tipo = 'entrada'),
                    0
                )
                -
                COALESCE(
                    (SELECT SUM(ic.quantidade) FROM itens_comanda ic
                     JOIN comandas c ON ic.comanda_id = c.id
                     WHERE ic.produto_id = p.id
                     AND DATE(c.data_venda) BETWEEN p_data_inicio AND p_data_fim),
                    0
                )
            )
            -
            COALESCE(p.estoque_atual, 0)
        ) AS perdas_quantidade,
        
        -- ===== VALOR DAS PERDAS =====
        ROUND(
            GREATEST(0,
                (
                    COALESCE(
                        (SELECT estoque_real FROM estoque_snapshots 
                         WHERE produto_id = p.id 
                         AND data_snapshot = DATE_SUB(p_data_inicio, INTERVAL 1 DAY) 
                         LIMIT 1),
                        0
                    )
                    +
                    COALESCE(
                        (SELECT SUM(quantidade) FROM movimentacoes_estoque 
                         WHERE produto_id = p.id 
                         AND DATE(data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
                         AND tipo = 'entrada'),
                        0
                    )
                    -
                    COALESCE(
                        (SELECT SUM(ic.quantidade) FROM itens_comanda ic
                         JOIN comandas c ON ic.comanda_id = c.id
                         WHERE ic.produto_id = p.id
                         AND DATE(c.data_venda) BETWEEN p_data_inicio AND p_data_fim),
                        0
                    )
                )
                -
                COALESCE(p.estoque_atual, 0)
            ) * COALESCE(p.preco, 0),
            2
        ) AS perdas_valor
        
    FROM produtos p
    LEFT JOIN categorias cat ON p.categoria_id = cat.id
    WHERE p.ativo = 1
    ORDER BY perdas_quantidade DESC, p.nome ASC;
    
END$$

DELIMITER ;

-- ============================================================================
-- PARTE 8: QUERY PARA VERIFICAR DIVERGÊNCIAS ATUAIS
-- ============================================================================

-- Query para encontrar produtos com divergência
-- Execute para diagnosticar o problema:
/*
SELECT 
    p.id,
    p.nome,
    p.estoque_atual AS estoque_real,
    fn_estoque_teorico_ate_data(p.id, CURDATE()) AS estoque_teorico,
    fn_divergencia_atual(p.id) AS divergencia,
    CASE 
        WHEN fn_divergencia_atual(p.id) > 0 THEN 'FALTAM PRODUTOS'
        WHEN fn_divergencia_atual(p.id) < 0 THEN 'SOBRAM PRODUTOS'
        ELSE 'OK'
    END AS status
FROM produtos p
WHERE p.ativo = 1
ORDER BY ABS(fn_divergencia_atual(p.id)) DESC;
*/

-- ============================================================================
-- PARTE 9: QUERY PARA APLICAR AJUSTES DE DIVERGÊNCIA
-- ============================================================================

-- CUIDADO: Execute com atenção!
-- Esta query AJUSTA todos os estoques para bater com o teórico
/*
-- 1. Primeiro, ANALISE para ver o que será ajustado:
SELECT 
    p.id,
    p.nome,
    p.estoque_atual,
    fn_estoque_teorico_ate_data(p.id, CURDATE()) AS estoque_deve_ser,
    fn_divergencia_atual(p.id) AS ajuste_necessario
FROM produtos p
WHERE p.ativo = 1
AND fn_divergencia_atual(p.id) != 0
ORDER BY ABS(fn_divergencia_atual(p.id)) DESC;

-- 2. Se os ajustes forem corretos, execute este script:
START TRANSACTION;

-- Para cada produto com divergência, fazer ajuste
INSERT INTO historico_ajustes_estoque 
(produto_id, divergencia_detectada, data_ajuste, ajuste_aplicado, motivo)
SELECT 
    p.id,
    fn_divergencia_atual(p.id),
    CURDATE(),
    fn_divergencia_atual(p.id),
    'Ajuste automático de divergência acumulada'
FROM produtos p
WHERE p.ativo = 1
AND fn_divergencia_atual(p.id) != 0;

-- Registrar movimentações de ajuste
INSERT INTO movimentacoes_estoque 
(produto_id, tipo_movimentacao, quantidade, motivo, data_movimentacao)
SELECT 
    p.id,
    CASE WHEN fn_divergencia_atual(p.id) > 0 THEN 'entrada' ELSE 'saida' END,
    ABS(fn_divergencia_atual(p.id)),
    'Ajuste de divergência acumulada',
    CURDATE()
FROM produtos p
WHERE p.ativo = 1
AND fn_divergencia_atual(p.id) != 0;

-- Atualizar estoque
UPDATE produtos p
SET estoque_atual = fn_estoque_teorico_ate_data(p.id, CURDATE())
WHERE p.ativo = 1
AND fn_divergencia_atual(p.id) != 0;

COMMIT;
*/

-- ============================================================================
-- PARTE 10: TESTES
-- ============================================================================

-- Teste 1: Verificar se tabelas foram criadas
-- SHOW TABLES LIKE 'estoque_snapshots%';

-- Teste 2: Gerar snapshot de hoje
-- CALL gerar_snapshot_diario_corrigido(CURDATE());

-- Teste 3: Verificar snapshots gerados
-- SELECT * FROM estoque_snapshots ORDER BY data_snapshot DESC LIMIT 10;

-- Teste 4: Verificar divergências
-- SELECT p.id, p.nome, fn_divergencia_atual(p.id) AS divergencia FROM produtos p WHERE p.ativo = 1;

-- Teste 5: Gerar relatório de período
-- CALL relatorio_perdas_periodo_correto('2025-12-01', '2025-12-14');

-- ============================================================================
-- FIM DO SCRIPT
-- ============================================================================
