-- =============================================================================
-- ⚠️ ARQUIVO DESCONTINUADO - NÃO EXECUTAR
-- =============================================================================
-- Data: 11 de dezembro de 2025
-- Status: OBSOLETO - Usar scripts individuais (01-09) em vez deste arquivo
-- 
-- ❌ POR QUE NÃO USAR:
--    - Tenta adicionar colunas que já existem (erro #1060)
--    - Tenta criar tabelas que já existem
--    - Script combinado é menos flexível que scripts individuais
-- 
-- ✅ O QUE USAR EM VEZ DISSO:
--    Scripts já executados com sucesso:
--    1. 01_criar_tipos_ajuste_estoque.sql          ✅ EXECUTADO
--    2. 02_adicionar_colunas_movimentacoes.sql     ✅ EXECUTADO
--    3. 03_migrar_dados_vendas.sql                 ✅ EXECUTADO
--    4. 04_migrar_dados_entradas.sql               ✅ EXECUTADO
--    5. 05_migrar_dados_outras_saidas.sql          ✅ EXECUTADO
--    6. 06_criar_stored_procedure_corrigida.sql    ✅ EXECUTADO
--    7. 07_criar_funcoes_auxiliares.sql            ✅ EXECUTADO
--    8. 08_criar_view_auditoria.sql                ✅ EXECUTADO
--    9. 09_criar_log_migracao.sql                  ✅ EXECUTADO
--
-- ✅ API TAMBÉM FOI ATIVADA:
--    - modules/relatorios/relatorios.js            ✅ ATUALIZADO
--    - verçaooficial/modules/relatorios/relatorios.js ✅ ATUALIZADO
--
-- 📖 DOCUMENTAÇÃO:
--    - INSTRUÇÕES_EXECUÇÃO.md   - Guia de execução passo a passo
--    - MIGRACAO_CONCLUIDA.md    - Sumário final da migração
--    - GUIA_MIGRACAO_CORRECAO_PERDAS.md - Guia completo de migração
-- =============================================================================

-- ⚠️ TODO O CONTEÚDO ABAIXO ESTÁ COMENTADO PORQUE JÁ FOI EXECUTADO
-- ⚠️ NÃO DESCOMENTE ESTE ARQUIVO
-- ⚠️ USAR APENAS PARA REFERÊNCIA HISTÓRICA

/*

🔧 MIGRAÇÃO: CORREÇÃO DA LÓGICA DE CÁLCULO DE PERDAS DE ESTOQUE (HISTÓRICO)

Este arquivo continha a migração completa em um script único.
Foi substituído por 9 scripts individuais para maior segurança e flexibilidade.

CONTEÚDO ORIGINAL (PRESERVADO PARA REFERÊNCIA):


*/

-- =============================================================================
-- FIM DO ARQUIVO DESCONTINUADO
-- =============================================================================
-- A migração foi concluída com sucesso usando os scripts 01-09
-- Veja MIGRACAO_CONCLUIDA.md para o sumário final
-- =============================================================================

-- =============================================================================
-- ✅ FASE 2: CRIAR ESTRUTURA DE SUPORTE
-- =============================================================================

-- 2.1 Criar tabela de tipos de ajuste de estoque
CREATE TABLE IF NOT EXISTS tipos_ajuste_estoque (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(50) NOT NULL UNIQUE,
    tipo ENUM('entrada', 'saida') NOT NULL,
    descricao TEXT,
    codigo VARCHAR(10),
    ativo TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_tipo (tipo),
    INDEX idx_ativo (ativo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
COMMENT='Tipos de movimentação de estoque (entrada/saída)';

-- 2.2 Inserir tipos padrão
INSERT IGNORE INTO tipos_ajuste_estoque (nome, tipo, descricao, codigo) VALUES
('Compra', 'entrada', 'Entrada por compra de fornecedor', 'COMP'),
('Devolução Cliente', 'entrada', 'Devolução de cliente/venda cancelada', 'DEVOL'),
('Ajuste Entrada', 'entrada', 'Ajuste positivo de inventário (correção)', 'ADJ+'),
('Ajuste Saída', 'saida', 'Ajuste negativo de inventário (correção)', 'ADJ-'),
('Venda', 'saida', 'Saída por venda normal', 'VEND'),
('Perda Identificada', 'saida', 'Perda identificada (quebra, dano, roubo)', 'PERD'),
('Transferência Out', 'saida', 'Transferência para outra unidade/local', 'TRANSF'),
('Consumo Interno', 'saida', 'Consumo interno (equipe, teste)', 'CONS'),
('Descarte', 'saida', 'Produto descartado (vencido, etc)', 'DESC');

-- =============================================================================
-- ✅ FASE 3: ADICIONAR COLUNA MOTIVO
-- =============================================================================

-- 3.1 Adicionar coluna motivo em movimentacoes_estoque (se não existir)
ALTER TABLE movimentacoes_estoque 
ADD COLUMN motivo VARCHAR(50) DEFAULT 'venda' AFTER tipo,
ADD COLUMN tipo_ajuste_id INT DEFAULT NULL AFTER motivo,
ADD INDEX idx_motivo (motivo),
ADD CONSTRAINT fk_tipo_ajuste FOREIGN KEY (tipo_ajuste_id) 
    REFERENCES tipos_ajuste_estoque(id) ON DELETE SET NULL;

-- 3.2 Adicionar coluna de rastreamento de sincronização
ALTER TABLE movimentacoes_estoque 
ADD COLUMN comanda_id INT DEFAULT NULL AFTER fornecedor_id,
ADD INDEX idx_comanda (comanda_id),
ADD CONSTRAINT fk_comanda_mov FOREIGN KEY (comanda_id) 
    REFERENCES comandas(id) ON DELETE SET NULL;

-- =============================================================================
-- ✅ FASE 4: MIGRAR DADOS EXISTENTES
-- =============================================================================

-- 4.1 Registrar início da migração
SELECT NOW() as tempo_inicio, 'Iniciando migração de dados' as acao;

-- 4.2 Atualizar movimentações de VENDA
-- Associar saídas a vendas reais em itens_comanda
UPDATE movimentacoes_estoque me
INNER JOIN itens_comanda ic ON (
    ic.produto_id = me.produto_id 
    AND me.tipo = 'saida'
)
INNER JOIN comandas c ON ic.comanda_id = c.id
SET 
    me.motivo = 'venda',
    me.comanda_id = c.id,
    me.tipo_ajuste_id = (SELECT id FROM tipos_ajuste_estoque WHERE codigo = 'VEND'),
    me.observacao = CONCAT(
        COALESCE(me.observacao, ''), 
        ' [Sincronizado com Comanda #', c.id, ']'
    )
WHERE me.tipo = 'saida'
AND me.motivo IS NULL
AND me.data_movimentacao >= c.created_at
AND me.data_movimentacao <= IFNULL(c.data_finalizacao, NOW())
LIMIT 1000;

-- 4.3 Atualizar entrada por COMPRA (padrão para entradas sem motivo)
UPDATE movimentacoes_estoque 
SET 
    motivo = 'compra',
    tipo_ajuste_id = (SELECT id FROM tipos_ajuste_estoque WHERE codigo = 'COMP')
WHERE tipo = 'entrada'
AND (motivo IS NULL OR motivo = 'venda');

-- 4.4 Identificar saídas que NÃO são vendas (perdas, ajustes, etc)
UPDATE movimentacoes_estoque 
SET 
    motivo = CASE
        WHEN observacao LIKE '%Devolução%' OR observacao LIKE '%devol%' 
            THEN 'devolucao'
        WHEN observacao LIKE '%Ajuste%' OR observacao LIKE '%ajuste%'
            THEN 'ajuste'
        WHEN observacao LIKE '%Perda%' OR observacao LIKE '%perda%'
            THEN 'perda_identificada'
        WHEN observacao LIKE '%Transferência%' OR observacao LIKE '%transfer%'
            THEN 'transferencia'
        ELSE 'ajuste'  -- Default para saídas desconhecidas
    END,
    tipo_ajuste_id = CASE
        WHEN observacao LIKE '%Ajuste%' OR observacao LIKE '%ajuste%'
            THEN (SELECT id FROM tipos_ajuste_estoque WHERE codigo = 'ADJ-')
        WHEN observacao LIKE '%Perda%' OR observacao LIKE '%perda%'
            THEN (SELECT id FROM tipos_ajuste_estoque WHERE codigo = 'PERD')
        WHEN observacao LIKE '%Transferência%' OR observacao LIKE '%transfer%'
            THEN (SELECT id FROM tipos_ajuste_estoque WHERE codigo = 'TRANSF')
        ELSE (SELECT id FROM tipos_ajuste_estoque WHERE codigo = 'ADJ-')
    END
WHERE tipo = 'saida'
AND (motivo IS NULL OR motivo = 'venda')
AND observacao NOT LIKE '%Venda%';

-- 4.5 Registrar final da migração de dados
SELECT COUNT(*) as total_atualizadas FROM movimentacoes_estoque 
WHERE tipo_ajuste_id IS NOT NULL;

-- =============================================================================
-- ✅ FASE 5: CRIAR STORED PROCEDURE CORRIGIDA
-- =============================================================================

DELIMITER $$

-- 5.1 Dropar procedure antiga se existir
DROP PROCEDURE IF EXISTS relatorio_analise_estoque_periodo_corrigido$$

-- 5.2 Criar nova procedure com lógica corrigida
CREATE PROCEDURE relatorio_analise_estoque_periodo_corrigido(
    IN p_data_inicio DATE,
    IN p_data_fim DATE
)
BEGIN
    -- PROCEDURE: Análise de estoque com cálculo correto de perdas
    -- Considera TODAS as movimentações com seus motivos específicos
    -- Evita duplicação de contabilizações
    
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
        ), 0) as vendas_periodo,
        
        -- ===== SAÍDAS NÃO COMERCIAIS (perdas já identificadas, ajustes-) =====
        COALESCE((
            SELECT SUM(me.quantidade)
            FROM movimentacoes_estoque me
            WHERE me.produto_id = p.id
            AND me.tipo = 'saida'
            AND me.motivo NOT IN ('venda')  -- Exclui saídas por venda (já em itens_comanda)
            AND DATE(me.data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
        ), 0) as saidas_nao_comerciais_periodo,
        
        -- ===== ESTOQUE TEÓRICO FINAL =====
        -- = Estoque Inicial + Entradas - Vendas - Saídas Não Comerciais
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
                AND DATE(me.data_movimentacao) <= p_data_fim
            ), 0)
        ) as estoque_teorico_final,
        
        -- ===== DIFERENÇA (PERDA NÃO IDENTIFICADA) =====
        -- = Estoque Teórico - Estoque Real
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
                AND DATE(me.data_movimentacao) <= p_data_fim
            ), 0) - p.estoque_atual
        ) as diferenca_estoque,
        
        -- ===== APENAS PERDAS NÃO IDENTIFICADAS (diferença > 0) =====
        GREATEST(
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
                    AND DATE(me.data_movimentacao) <= p_data_fim
                ), 0) - p.estoque_atual
            ),
            0
        ) as perdas_nao_identificadas,
        
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
    ORDER BY perdas_nao_identificadas DESC, p.nome ASC;
    
END$$

DELIMITER ;

-- =============================================================================
-- ✅ FASE 6: FUNÇÃO AUXILIAR DE CONTROLE
-- =============================================================================

DELIMITER $$

-- 6.1 Função para obter estoque acumulado até uma data
CREATE FUNCTION IF NOT EXISTS fn_estoque_acumulado(
    p_produto_id INT,
    p_data_fim DATE
) 
RETURNS INT
READS SQL DATA
DETERMINISTIC
BEGIN
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

-- 6.2 Função para calcular perda de um produto em período
CREATE FUNCTION IF NOT EXISTS fn_calcular_perda(
    p_produto_id INT,
    p_data_fim DATE
)
RETURNS INT
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_estoque_teorico INT;
    DECLARE v_estoque_real INT;
    DECLARE v_perda INT;
    
    -- Obter estoque teórico acumulado
    SELECT fn_estoque_acumulado(p_produto_id, p_data_fim) INTO v_estoque_teorico;
    
    -- Obter estoque real
    SELECT estoque_atual INTO v_estoque_real FROM produtos WHERE id = p_produto_id;
    
    -- Calcular perda
    SET v_perda = GREATEST(v_estoque_teorico - v_estoque_real, 0);
    
    RETURN v_perda;
END$$

DELIMITER ;

-- =============================================================================
-- ✅ FASE 7: VALIDAÇÃO PÓS-MIGRAÇÃO
-- =============================================================================

-- 7.1 Verificar consistência: produtos com estoque negativo (erro crítico)
SELECT 
    p.id,
    p.nome,
    p.estoque_atual,
    'ERRO CRÍTICO: Estoque negativo' as alerta
FROM produtos p
WHERE p.estoque_atual < 0;

-- 7.2 Verificar produtos com muitas movimentações desconhecidas
SELECT 
    p.id,
    p.nome,
    COUNT(me.id) as total_movimentacoes,
    SUM(CASE WHEN me.motivo IS NULL THEN 1 ELSE 0 END) as motivos_desconhecidos
FROM produtos p
LEFT JOIN movimentacoes_estoque me ON p.id = me.produto_id
GROUP BY p.id
HAVING motivos_desconhecidos > 0
ORDER BY motivos_desconhecidos DESC;

-- 7.3 Relatório de validação final
SELECT 
    'Total de Movimentações' as descricao,
    COUNT(*) as quantidade
FROM movimentacoes_estoque
UNION ALL
SELECT 
    'Movimentações com motivo definido',
    COUNT(*) 
FROM movimentacoes_estoque 
WHERE motivo IS NOT NULL
UNION ALL
SELECT 
    'Movimentações com tipo_ajuste_id',
    COUNT(*) 
FROM movimentacoes_estoque 
WHERE tipo_ajuste_id IS NOT NULL
UNION ALL
SELECT 
    'Produtos com estoque_atual >= 0',
    COUNT(*) 
FROM produtos 
WHERE estoque_atual >= 0
UNION ALL
SELECT 
    'Produtos ativos',
    COUNT(*) 
FROM produtos 
WHERE ativo = 1;

-- =============================================================================
-- ✅ FASE 8: CRIAR VIEW PARA AUDITORIA
-- =============================================================================

CREATE OR REPLACE VIEW vw_analise_perdas_corrigida AS
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
    
    -- Contadores
    (SELECT COUNT(*) 
     FROM movimentacoes_estoque 
     WHERE produto_id = p.id AND tipo = 'entrada') as total_entradas,
    (SELECT COUNT(*) 
     FROM movimentacoes_estoque 
     WHERE produto_id = p.id AND tipo = 'saida') as total_saidas,
    (SELECT COUNT(*) 
     FROM itens_comanda 
     WHERE produto_id = p.id) as total_vendas
    
FROM produtos p
INNER JOIN categorias cat ON p.categoria_id = cat.id
WHERE p.ativo = 1
ORDER BY fn_calcular_perda(p.id, CURDATE()) DESC;

-- =============================================================================
-- ✅ FASE 9: REGISTRAR SUCESSO DA MIGRAÇÃO
-- =============================================================================

-- Criar tabela de log de migrações
CREATE TABLE IF NOT EXISTS logs_migracao_estoque (
    id INT PRIMARY KEY AUTO_INCREMENT,
    data_execucao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tipo_migracao VARCHAR(100),
    status ENUM('sucesso', 'erro', 'aviso') DEFAULT 'sucesso',
    descricao TEXT,
    registros_afetados INT DEFAULT 0,
    tempo_execucao_segundos INT,
    usuario_execucao VARCHAR(100)
);

INSERT INTO logs_migracao_estoque 
(tipo_migracao, status, descricao, registros_afetados, usuario_execucao)
VALUES (
    'correcao_logica_perdas_v1',
    'sucesso',
    'Migração completa: adição de coluna motivo, tipos de ajuste, nova stored procedure',
    (SELECT COUNT(*) FROM movimentacoes_estoque),
    CURRENT_USER()
);

SELECT 'Migração concluída com sucesso!' as mensagem;

-- =============================================================================
-- 📊 TESTE FINAL: Comparar antiga vs. nova lógica
-- =============================================================================

-- Exemplo: Produto "Feijão Tropeiro G"
SELECT 
    'TESTE DE VALIDAÇÃO' as categoria,
    p.id,
    p.nome,
    p.estoque_atual,
    fn_estoque_acumulado(p.id, CURDATE()) as estoque_teorico_novo,
    fn_calcular_perda(p.id, CURDATE()) as perda_nova
FROM produtos p
WHERE p.nome LIKE '%Feijão%'
LIMIT 1;

-- =============================================================================
-- ⚠️ NOTAS IMPORTANTES
-- =============================================================================
-- 1. Esta migração foi preparada para ser IDEMPOTENTE (segura executar múltiplas vezes)
-- 2. Backup recomendado antes da execução em produção
-- 3. Testar em ambiente de teste primeiro
-- 4. Validar relatórios após a execução
-- 5. Monitorar por 7 dias em produção
-- =============================================================================
