-- =============================================
-- BANCO DE DADOS SISTEMA RESTAURANTE
-- =============================================

-- Criar banco de dados
CREATE DATABASE IF NOT EXISTS sistema_restaurante;
USE sistema_restaurante;

-- =============================================
-- TABELAS PRINCIPAIS
-- =============================================

-- Tabela de configurações simplificada
CREATE TABLE configuracoes (
    id INT PRIMARY KEY AUTO_INCREMENT,
    taxa_gorjeta DECIMAL(5,2) DEFAULT 0,
    tipo_taxa ENUM('fixa', 'percentual', 'nenhuma') DEFAULT 'nenhuma',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de categorias de produtos
CREATE TABLE categorias (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(50) NOT NULL UNIQUE,
    descricao TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de fornecedores
CREATE TABLE fornecedores (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL,
    contato VARCHAR(100),
    telefone VARCHAR(20),
    produtos_fornecidos TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de produtos
CREATE TABLE produtos (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL,
    categoria_id INT NOT NULL,
    preco DECIMAL(10, 2) NOT NULL,
    estoque_atual INT DEFAULT 0,
    estoque_minimo INT DEFAULT 0,
    imagem VARCHAR(255),
    ativo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (categoria_id) REFERENCES categorias(id)
);

-- Tabela de comandas simplificada
CREATE TABLE comandas (
    id INT PRIMARY KEY AUTO_INCREMENT,
    data_venda TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('aberta', 'fechada', 'cancelada') DEFAULT 'aberta',
    valor_total DECIMAL(10, 2) DEFAULT 0,
    taxa_gorjeta DECIMAL(10, 2) DEFAULT 0,
    observacoes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Tabela de itens da comanda (produtos catalogados)
CREATE TABLE itens_comanda (
    id INT PRIMARY KEY AUTO_INCREMENT,
    comanda_id INT NOT NULL,
    produto_id INT NOT NULL,
    quantidade INT NOT NULL DEFAULT 1,
    preco_unitario DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (comanda_id) REFERENCES comandas(id) ON DELETE CASCADE,
    FOREIGN KEY (produto_id) REFERENCES produtos(id)
);

-- Tabela de itens livres (produtos não catalogados)
CREATE TABLE itens_livres (
    id INT PRIMARY KEY AUTO_INCREMENT,
    comanda_id INT NOT NULL,
    descricao VARCHAR(255) NOT NULL,
    valor DECIMAL(10, 2) NOT NULL,
    quantidade INT NOT NULL DEFAULT 1,
    subtotal DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (comanda_id) REFERENCES comandas(id) ON DELETE CASCADE
);

-- Tabela de movimentações de estoque
CREATE TABLE movimentacoes_estoque (
    id INT PRIMARY KEY AUTO_INCREMENT,
    produto_id INT NOT NULL,
    tipo ENUM('entrada', 'saida') NOT NULL,
    quantidade INT NOT NULL,
    data_movimentacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    observacao TEXT,
    fornecedor_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (produto_id) REFERENCES produtos(id),
    FOREIGN KEY (fornecedor_id) REFERENCES fornecedores(id)
);

-- Tabela de usuários do sistema
CREATE TABLE usuarios (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    senha VARCHAR(255) NOT NULL,
    perfil ENUM('admin', 'caixa', 'estoque') NOT NULL DEFAULT 'caixa',
    ativo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- =============================================
-- DADOS INICIAIS
-- =============================================

-- Inserir configuração padrão
INSERT INTO configuracoes (taxa_gorjeta, tipo_taxa) VALUES (10.00, 'percentual');

-- Inserir categorias padrão
INSERT INTO categorias (nome, descricao) VALUES
('Espetos', 'Espetos variados'),
('Porções', 'Porções de diferentes tamanhos'),
('Bebidas', 'Bebidas não alcoólicas'),
('Cervejas', 'Cervejas e bebidas alcoólicas'),
('Diversos', 'Outros produtos');

-- Inserir produtos de exemplo (Espetos)
INSERT INTO produtos (nome, categoria_id, preco, estoque_atual, estoque_minimo) VALUES
('Frango com Bacon', 1, 10.00, 50, 10),
('Almôndega de carne com queijo', 1, 10.00, 50, 10),
('Contra Filé', 1, 10.00, 50, 10),
('Linguiça de porco', 1, 10.00, 50, 10),
('Provolone', 1, 10.00, 50, 10),
('Coração', 1, 10.00, 50, 10);

-- Inserir produtos de exemplo (Porções)
INSERT INTO produtos (nome, categoria_id, preco, estoque_atual, estoque_minimo) VALUES
('Macarrão M', 2, 10.00, 30, 5),
('Mandioca M', 2, 10.00, 30, 5),
('Arroz M', 2, 10.00, 30, 5),
('Salada M', 2, 12.00, 30, 5),
('Feijão Tropeiro M', 2, 15.00, 30, 5),
('Macarrão G', 2, 20.00, 30, 5),
('Mandioca G', 2, 20.00, 30, 5),
('Arroz G', 2, 20.00, 30, 5),
('Salada G', 2, 22.00, 30, 5),
('Feijão Tropeiro G', 2, 25.00, 30, 5);

-- Inserir produtos de exemplo (Bebidas)
INSERT INTO produtos (nome, categoria_id, preco, estoque_atual, estoque_minimo) VALUES
('Água Sem Gás', 3, 3.00, 100, 20),
('Água Com Gás', 3, 3.50, 100, 20),
('Coca-Cola KS', 3, 5.00, 100, 20),
('Diversas latas 350ml', 3, 6.00, 100, 20),
('Coca-Cola 600ml', 3, 8.00, 100, 20),
('H2OH', 3, 8.00, 100, 20),
('Mineiro', 3, 8.00, 100, 20),
('Energéticos', 3, 10.00, 100, 20),
('Garrafas 1L', 3, 10.00, 100, 20),
('Garrafas 2L (exceto Coca)', 3, 12.00, 100, 20),
('H2OH 1,5L', 3, 12.00, 100, 20),
('Coca-Cola 2L', 3, 14.00, 100, 20),
('Sucos Life 900ml', 3, 18.00, 100, 20);

-- Inserir produtos de exemplo (Cervejas)
INSERT INTO produtos (nome, categoria_id, preco, estoque_atual, estoque_minimo) VALUES
('Barrigudinhas', 4, 4.00, 100, 20),
('Latas e Beat''s', 4, 6.00, 100, 20),
('Skol/Antarctica 600ml', 4, 10.00, 100, 20),
('Long Necks', 4, 10.00, 100, 20),
('Chopp', 4, 10.00, 100, 20),
('Original', 4, 12.00, 100, 20),
('Spaten', 4, 12.00, 100, 20),
('Budweiser', 4, 12.00, 100, 20),
('Amstel 600ml', 4, 12.00, 100, 20),
('Heineken 600ml', 4, 15.00, 100, 20);

-- Criar usuário administrador padrão
INSERT INTO usuarios (nome, email, senha, perfil) VALUES
('Administrador', 'admin@sistema.com', SHA2('admin123', 256), 'admin'),
('Caixa 01', 'caixa01@restaurante.com', SHA2('caixa123', 256), 'caixa');

-- =============================================
-- TRIGGERS PARA AUTOMATIZAÇÃO
-- =============================================

DELIMITER //

-- Trigger 1: Atualizar estoque quando item é vendido
CREATE TRIGGER after_insert_itens_comanda
AFTER INSERT ON itens_comanda
FOR EACH ROW
BEGIN
    UPDATE produtos 
    SET estoque_atual = estoque_atual - NEW.quantidade,
        updated_at = NOW()
    WHERE id = NEW.produto_id;
END//

-- Trigger 2: Atualizar valor total da comanda quando item é adicionado
CREATE TRIGGER atualiza_total_comanda_insercao
AFTER INSERT ON itens_comanda
FOR EACH ROW
BEGIN
    UPDATE comandas 
    SET valor_total = (
        SELECT COALESCE(SUM(subtotal), 0) FROM itens_comanda WHERE comanda_id = NEW.comanda_id
    ) + (
        SELECT COALESCE(SUM(subtotal), 0) FROM itens_livres WHERE comanda_id = NEW.comanda_id
    ),
    updated_at = NOW()
    WHERE id = NEW.comanda_id;
END//

-- Trigger 3: Atualizar valor total quando item livre é adicionado
CREATE TRIGGER atualiza_total_comanda_itens_livres
AFTER INSERT ON itens_livres
FOR EACH ROW
BEGIN
    UPDATE comandas 
    SET valor_total = (
        SELECT COALESCE(SUM(subtotal), 0) FROM itens_comanda WHERE comanda_id = NEW.comanda_id
    ) + (
        SELECT COALESCE(SUM(subtotal), 0) FROM itens_livres WHERE comanda_id = NEW.comanda_id
    ),
    updated_at = NOW()
    WHERE id = NEW.comanda_id;
END//

-- Trigger 4: Aplicar taxa automaticamente ao fechar comanda
CREATE TRIGGER aplica_taxa_gorjeta
BEFORE UPDATE ON comandas
FOR EACH ROW
BEGIN
    DECLARE taxa_config DECIMAL(10,2) DEFAULT 0;
    DECLARE tipo_taxa_config VARCHAR(20) DEFAULT 'nenhuma';

    IF NEW.status = 'fechada' AND OLD.status = 'aberta' THEN
        SELECT taxa_gorjeta, tipo_taxa INTO taxa_config, tipo_taxa_config
        FROM configuracoes ORDER BY id DESC LIMIT 1;

        IF tipo_taxa_config = 'percentual' AND taxa_config > 0 THEN
            SET NEW.taxa_gorjeta = (NEW.valor_total * taxa_config) / 100;
        ELSEIF tipo_taxa_config = 'fixa' AND taxa_config > 0 THEN
            SET NEW.taxa_gorjeta = taxa_config;
        ELSE
            SET NEW.taxa_gorjeta = 0;
        END IF;

        SET NEW.data_venda = NOW();
    END IF;
END//

DELIMITER ;

-- =============================================
-- VIEWS PARA RELATÓRIOS
-- =============================================

-- View para relatório de vendas por período
CREATE VIEW view_vendas_periodo AS
SELECT 
    DATE(data_venda) as data_venda,
    COUNT(id) as total_comandas,
    SUM(valor_total) as valor_total_vendas,
    SUM(taxa_gorjeta) as total_gorjetas,
    AVG(valor_total) as ticket_medio
FROM comandas 
WHERE status = 'fechada'
GROUP BY DATE(data_venda);

-- View para produtos mais vendidos
CREATE VIEW view_produtos_mais_vendidos AS
SELECT 
    p.nome,
    p.categoria_id,
    cat.nome as categoria,
    SUM(ic.quantidade) as total_vendido,
    SUM(ic.subtotal) as valor_total_vendido
FROM itens_comanda ic
JOIN produtos p ON ic.produto_id = p.id
JOIN categorias cat ON p.categoria_id = cat.id
JOIN comandas c ON ic.comanda_id = c.id
WHERE c.status = 'fechada'
GROUP BY p.id
ORDER BY total_vendido DESC;

-- View para controle de estoque mínimo
CREATE VIEW view_estoque_minimo AS
SELECT 
    p.id,
    p.nome,
    p.estoque_atual,
    p.estoque_minimo,
    cat.nome as categoria,
    (p.estoque_minimo - p.estoque_atual) as quantidade_falta
FROM produtos p
JOIN categorias cat ON p.categoria_id = cat.id
WHERE p.estoque_atual <= p.estoque_minimo
AND p.ativo = TRUE
ORDER BY quantidade_falta DESC;

-- View para dashboard administrativo
CREATE VIEW view_dashboard AS
SELECT 
    (SELECT COUNT(*) FROM comandas WHERE DATE(data_venda) = CURDATE() AND status = 'fechada') as vendas_hoje,
    (SELECT COALESCE(SUM(valor_total), 0) FROM comandas WHERE DATE(data_venda) = CURDATE() AND status = 'fechada') as faturamento_hoje,
    (SELECT COUNT(*) FROM produtos WHERE estoque_atual <= estoque_minimo AND ativo = TRUE) as alertas_estoque,
    (SELECT COALESCE(AVG(valor_total), 0) FROM comandas WHERE DATE(data_venda) = CURDATE() AND status = 'fechada') as ticket_medio;

-- =============================================
-- PROCEDURES ÚTEIS
-- =============================================

DELIMITER //

-- Procedure para registrar entrada no estoque
CREATE PROCEDURE registrar_entrada_estoque(
    IN p_produto_id INT,
    IN p_quantidade INT,
    IN p_observacao TEXT,
    IN p_fornecedor_id INT
)
BEGIN
    START TRANSACTION;
    
    -- Registrar movimentação
    INSERT INTO movimentacoes_estoque (produto_id, tipo, quantidade, observacao, fornecedor_id)
    VALUES (p_produto_id, 'entrada', p_quantidade, p_observacao, p_fornecedor_id);
    
    -- Atualizar estoque
    UPDATE produtos 
    SET estoque_atual = estoque_atual + p_quantidade,
        updated_at = NOW()
    WHERE id = p_produto_id;
    
    COMMIT;
END//

-- Procedure para fechar comanda com cálculo automático
CREATE PROCEDURE fechar_comanda(IN p_comanda_id INT)
BEGIN
    DECLARE total_comanda DECIMAL(10,2);
    DECLARE taxa_config DECIMAL(5,2);
    DECLARE tipo_taxa_config VARCHAR(20);
    
    -- Calcular total da comanda
    SELECT COALESCE(SUM(subtotal), 0) INTO total_comanda
    FROM (
        SELECT subtotal FROM itens_comanda WHERE comanda_id = p_comanda_id
        UNION ALL
        SELECT subtotal FROM itens_livres WHERE comanda_id = p_comanda_id
    ) AS todos_itens;
    
    -- Obter configuração de taxa
    SELECT taxa_gorjeta, tipo_taxa INTO taxa_config, tipo_taxa_config
    FROM configuracoes ORDER BY id DESC LIMIT 1;
    
    -- Fechar comanda
    UPDATE comandas 
    SET status = 'fechada',
        valor_total = total_comanda,
        taxa_gorjeta = CASE 
            WHEN tipo_taxa_config = 'percentual' THEN (total_comanda * taxa_config) / 100
            WHEN tipo_taxa_config = 'fixa' THEN taxa_config
            ELSE 0
        END,
        data_venda = NOW()
    WHERE id = p_comanda_id;
    
END//

DELIMITER ;

-- =============================================
-- ÍNDICES PARA MELHOR PERFORMANCE
-- =============================================

-- Índices para consultas frequentes
CREATE INDEX idx_comandas_data_status ON comandas(data_venda, status);
CREATE INDEX idx_itens_comanda_comanda ON itens_comanda(comanda_id);
CREATE INDEX idx_itens_comanda_produto ON itens_comanda(produto_id);
CREATE INDEX idx_produtos_categoria ON produtos(categoria_id);
CREATE INDEX idx_produtos_ativo ON produtos(ativo);
CREATE INDEX idx_movimentacoes_data ON movimentacoes_estoque(data_movimentacao);
CREATE INDEX idx_movimentacoes_produto ON movimentacoes_estoque(produto_id);

-- =============================================
-- CONSULTAS DE TESTE
-- =============================================

-- Teste: Criar uma comanda de exemplo
INSERT INTO comandas (status, valor_total) VALUES ('aberta', 0);

-- Teste: Adicionar itens à comanda
INSERT INTO itens_comanda (comanda_id, produto_id, quantidade, preco_unitario, subtotal)
VALUES 
(1, 1, 2, 10.00, 20.00),  -- 2x Frango com Bacon
(1, 23, 1, 5.00, 5.00),   -- 1x Coca-Cola KS
(1, 35, 2, 10.00, 20.00); -- 2x Skol 600ml

-- Teste: Fechar a comanda
CALL fechar_comanda(1);

-- Verificar resultados
SELECT * FROM comandas WHERE id = 1;
SELECT * FROM itens_comanda WHERE comanda_id = 1;
SELECT * FROM produtos WHERE id IN (1, 23, 35); -- Verificar estoque atualizado

-- =============================================
-- MENSAGEM DE CONFIRMAÇÃO
-- =============================================

SELECT '✅ BANCO DE DADOS CRIADO COM SUCESSO!' as status;
SELECT '📊 TABELAS: 9 tabelas criadas' as detalhes;
SELECT '🔧 TRIGGERS: 4 triggers de automação' as detalhes;
SELECT '👤 USUÁRIOS: Admin (admin@sistema.com / admin123)' as login;
SELECT '📈 VIEWS: 4 views para relatórios' as detalhes;