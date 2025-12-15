-- =============================================================================
-- 📋 SCRIPT 1: CRIAR TABELA DE TIPOS DE AJUSTE DE ESTOQUE
-- =============================================================================
-- Arquivo: 01_criar_tipos_ajuste_estoque.sql
-- Descrição: Cria tabela que define todos os tipos de movimentação de estoque
-- Tempo estimado: < 1 segundo
-- =============================================================================

CREATE TABLE IF NOT EXISTS tipos_ajuste_estoque (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(50) NOT NULL UNIQUE,
    tipo ENUM('entrada', 'saida') NOT NULL,
    descricao TEXT,
    codigo VARCHAR(10),
    ativo TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_tipo (tipo),
    INDEX idx_ativo (ativo),
    INDEX idx_codigo (codigo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
COMMENT='Tipos de movimentação de estoque (entrada/saída)';

-- =============================================================================
-- INSERIR TIPOS PADRÃO
-- =============================================================================

INSERT INTO tipos_ajuste_estoque (nome, tipo, descricao, codigo) VALUES
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
-- VALIDAR INSERÇÃO
-- =============================================================================

-- Verificar tipos inseridos
SELECT * FROM tipos_ajuste_estoque ORDER BY tipo, nome;

-- Contar registros
SELECT COUNT(*) as total_tipos FROM tipos_ajuste_estoque;

-- =============================================================================
-- FIM DO SCRIPT
-- =============================================================================
