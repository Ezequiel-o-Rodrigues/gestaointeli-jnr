-- =============================================================================
-- 📋 SCRIPT 9: CRIAR TABELA DE LOG DE MIGRAÇÕES
-- =============================================================================
-- Arquivo: 09_criar_log_migracao.sql
-- Descrição: Tabela para registrar histórico de migrações executadas
-- Tempo estimado: 1-2 segundos
-- =============================================================================

-- =============================================================================
-- 9.1 CRIAR TABELA DE LOG
-- =============================================================================

CREATE TABLE IF NOT EXISTS logs_migracao_estoque (
    id INT PRIMARY KEY AUTO_INCREMENT,
    data_execucao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tipo_migracao VARCHAR(100) NOT NULL,
    status ENUM('sucesso', 'erro', 'aviso') DEFAULT 'sucesso',
    descricao TEXT,
    registros_afetados INT DEFAULT 0,
    tempo_execucao_segundos INT,
    usuario_execucao VARCHAR(100),
    versao VARCHAR(20),
    detalhes_erro TEXT,
    
    INDEX idx_data (data_execucao),
    INDEX idx_status (status),
    INDEX idx_tipo (tipo_migracao)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
COMMENT='Histórico de migrações de estrutura de estoque';

-- =============================================================================
-- 9.2 REGISTRAR MIGRAÇÕES
-- =============================================================================

INSERT INTO logs_migracao_estoque 
(tipo_migracao, status, descricao, usuario_execucao, versao)
VALUES (
    'correcao_logica_perdas_v2',
    'sucesso',
    'Script 1: Criação de tabela tipos_ajuste_estoque',
    CURRENT_USER(),
    '2.0'
);

INSERT INTO logs_migracao_estoque 
(tipo_migracao, status, descricao, usuario_execucao, versao)
VALUES (
    'correcao_logica_perdas_v2',
    'sucesso',
    'Script 2: Adição de colunas em movimentacoes_estoque',
    CURRENT_USER(),
    '2.0'
);

INSERT INTO logs_migracao_estoque 
(tipo_migracao, status, descricao, usuario_execucao, versao)
VALUES (
    'correcao_logica_perdas_v2',
    'sucesso',
    'Script 3: Migração de dados - Vendas',
    CURRENT_USER(),
    '2.0'
);

INSERT INTO logs_migracao_estoque 
(tipo_migracao, status, descricao, usuario_execucao, versao)
VALUES (
    'correcao_logica_perdas_v2',
    'sucesso',
    'Script 4: Migração de dados - Entradas',
    CURRENT_USER(),
    '2.0'
);

INSERT INTO logs_migracao_estoque 
(tipo_migracao, status, descricao, usuario_execucao, versao)
VALUES (
    'correcao_logica_perdas_v2',
    'sucesso',
    'Script 5: Migração de dados - Outras saídas',
    CURRENT_USER(),
    '2.0'
);

INSERT INTO logs_migracao_estoque 
(tipo_migracao, status, descricao, usuario_execucao, versao)
VALUES (
    'correcao_logica_perdas_v2',
    'sucesso',
    'Script 6: Criação de stored procedure corrigida',
    CURRENT_USER(),
    '2.0'
);

INSERT INTO logs_migracao_estoque 
(tipo_migracao, status, descricao, usuario_execucao, versao)
VALUES (
    'correcao_logica_perdas_v2',
    'sucesso',
    'Script 7: Criação de funções auxiliares',
    CURRENT_USER(),
    '2.0'
);

INSERT INTO logs_migracao_estoque 
(tipo_migracao, status, descricao, usuario_execucao, versao)
VALUES (
    'correcao_logica_perdas_v2',
    'sucesso',
    'Script 8: Criação de view de auditoria',
    CURRENT_USER(),
    '2.0'
);

-- =============================================================================
-- 9.3 VALIDAR LOG
-- =============================================================================

-- Ver todos os registros de migração
SELECT * FROM logs_migracao_estoque ORDER BY data_execucao DESC;

-- Contar migrações por status
SELECT 
    status,
    COUNT(*) as total
FROM logs_migracao_estoque
GROUP BY status;

-- Últimas migrações
SELECT 
    data_execucao,
    tipo_migracao,
    status,
    descricao
FROM logs_migracao_estoque
ORDER BY data_execucao DESC
LIMIT 10;

-- =============================================================================
-- FIM DO SCRIPT
-- =============================================================================
