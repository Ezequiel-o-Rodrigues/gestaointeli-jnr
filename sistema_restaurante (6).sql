-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Tempo de geração: 11/11/2025 às 05:05
-- Versão do servidor: 10.4.32-MariaDB
-- Versão do PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Banco de dados: `sistema_restaurante`
--

DELIMITER $$
--
-- Procedimentos
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `fechar_comanda` (IN `p_comanda_id` INT)   BEGIN
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
    
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `registrar_entrada_estoque` (IN `p_produto_id` INT, IN `p_quantidade` INT, IN `p_observacao` TEXT, IN `p_fornecedor_id` INT)   BEGIN
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
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `registrar_inventario_estoque` (IN `p_produto_id` INT, IN `p_quantidade_fisica` INT, IN `p_observacao` TEXT, IN `p_usuario_id` INT)   BEGIN
    DECLARE v_quantidade_sistema INT;
    DECLARE v_diferenca INT;
    
    START TRANSACTION;
    
    -- Obter quantidade atual do sistema
    SELECT estoque_atual INTO v_quantidade_sistema 
    FROM produtos WHERE id = p_produto_id;
    
    -- Calcular diferença
    SET v_diferenca = p_quantidade_fisica - v_quantidade_sistema;
    
    -- Registrar o inventário
    INSERT INTO inventarios_estoque (
        produto_id, 
        quantidade_fisica, 
        quantidade_sistema, 
        diferenca, 
        observacao, 
        usuario_id
    ) VALUES (
        p_produto_id,
        p_quantidade_fisica,
        v_quantidade_sistema,
        v_diferenca,
        p_observacao,
        p_usuario_id
    );
    
    -- Atualizar estoque no sistema para igualar ao físico
    UPDATE produtos 
    SET estoque_atual = p_quantidade_fisica,
        updated_at = NOW()
    WHERE id = p_produto_id;
    
    -- Registrar movimentação de ajuste
    IF v_diferenca != 0 THEN
        INSERT INTO movimentacoes_estoque (
            produto_id,
            tipo,
            quantidade,
            observacao,
            data_movimentacao
        ) VALUES (
            p_produto_id,
            IF(v_diferenca > 0, 'entrada', 'saida'),
            ABS(v_diferenca),
            CONCAT('Ajuste de inventário: ', COALESCE(p_observacao, 'Sem observação')),
            NOW()
        );
    END IF;
    
    COMMIT;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `relatorio_analise_estoque_periodo` (IN `p_data_inicio` DATE, IN `p_data_fim` DATE)   BEGIN
    SELECT 
        p.id,
        p.nome,
        cat.nome as categoria,
        p.preco,
        
        -- Estoque inicial do período (todas as entradas antes do período)
        COALESCE((
            SELECT SUM(me.quantidade) 
            FROM movimentacoes_estoque me 
            WHERE me.produto_id = p.id 
            AND me.tipo = 'entrada' 
            AND DATE(me.data_movimentacao) < p_data_inicio
        ), 0) as estoque_inicial,
        
        -- Entradas durante o período
        COALESCE((
            SELECT SUM(me.quantidade) 
            FROM movimentacoes_estoque me 
            WHERE me.produto_id = p.id 
            AND me.tipo = 'entrada' 
            AND DATE(me.data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
        ), 0) as entradas_periodo,
        
        -- Saídas por vendas durante o período
        COALESCE((
            SELECT SUM(ic.quantidade) 
            FROM itens_comanda ic 
            JOIN comandas c ON ic.comanda_id = c.id 
            WHERE ic.produto_id = p.id 
            AND c.status = 'fechada'
            AND DATE(c.data_venda) BETWEEN p_data_inicio AND p_data_fim
        ), 0) as vendidas_periodo,
        
        -- Faturamento do produto no período
        COALESCE((
            SELECT SUM(ic.subtotal) 
            FROM itens_comanda ic 
            JOIN comandas c ON ic.comanda_id = c.id 
            WHERE ic.produto_id = p.id 
            AND c.status = 'fechada'
            AND DATE(c.data_venda) BETWEEN p_data_inicio AND p_data_fim
        ), 0) as faturamento_periodo,
        
        -- Estoque teórico final (estoque_inicial + entradas - vendas)
        (COALESCE((
            SELECT SUM(me.quantidade) 
            FROM movimentacoes_estoque me 
            WHERE me.produto_id = p.id 
            AND me.tipo = 'entrada' 
            AND DATE(me.data_movimentacao) < p_data_inicio
        ), 0) + 
        COALESCE((
            SELECT SUM(me.quantidade) 
            FROM movimentacoes_estoque me 
            WHERE me.produto_id = p.id 
            AND me.tipo = 'entrada' 
            AND DATE(me.data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
        ), 0)) - 
        COALESCE((
            SELECT SUM(ic.quantidade) 
            FROM itens_comanda ic 
            JOIN comandas c ON ic.comanda_id = c.id 
            WHERE ic.produto_id = p.id 
            AND c.status = 'fechada'
            AND DATE(c.data_venda) BETWEEN p_data_inicio AND p_data_fim
        ), 0) as estoque_teorico_final,
        
        -- Estoque real atual
        p.estoque_atual as estoque_real_atual,
        
        -- Diferença (perdas)
        ((COALESCE((
            SELECT SUM(me.quantidade) 
            FROM movimentacoes_estoque me 
            WHERE me.produto_id = p.id 
            AND me.tipo = 'entrada' 
            AND DATE(me.data_movimentacao) < p_data_inicio
        ), 0) + 
        COALESCE((
            SELECT SUM(me.quantidade) 
            FROM movimentacoes_estoque me 
            WHERE me.produto_id = p.id 
            AND me.tipo = 'entrada' 
            AND DATE(me.data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
        ), 0)) - 
        COALESCE((
            SELECT SUM(ic.quantidade) 
            FROM itens_comanda ic 
            JOIN comandas c ON ic.comanda_id = c.id 
            WHERE ic.produto_id = p.id 
            AND c.status = 'fechada'
            AND DATE(c.data_venda) BETWEEN p_data_inicio AND p_data_fim
        ), 0)) - p.estoque_atual as perdas_quantidade,
        
        -- Valor das perdas
        (((COALESCE((
            SELECT SUM(me.quantidade) 
            FROM movimentacoes_estoque me 
            WHERE me.produto_id = p.id 
            AND me.tipo = 'entrada' 
            AND DATE(me.data_movimentacao) < p_data_inicio
        ), 0) + 
        COALESCE((
            SELECT SUM(me.quantidade) 
            FROM movimentacoes_estoque me 
            WHERE me.produto_id = p.id 
            AND me.tipo = 'entrada' 
            AND DATE(me.data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
        ), 0)) - 
        COALESCE((
            SELECT SUM(ic.quantidade) 
            FROM itens_comanda ic 
            JOIN comandas c ON ic.comanda_id = c.id 
            WHERE ic.produto_id = p.id 
            AND c.status = 'fechada'
            AND DATE(c.data_venda) BETWEEN p_data_inicio AND p_data_fim
        ), 0)) - p.estoque_atual) * p.preco as perdas_valor
        
    FROM produtos p
    JOIN categorias cat ON p.categoria_id = cat.id
    WHERE p.ativo = 1
    ORDER BY perdas_valor DESC, perdas_quantidade DESC;
    
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estrutura para tabela `categorias`
--

CREATE TABLE `categorias` (
  `id` int(11) NOT NULL,
  `nome` varchar(50) NOT NULL,
  `descricao` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Despejando dados para a tabela `categorias`
--

INSERT INTO `categorias` (`id`, `nome`, `descricao`, `created_at`) VALUES
(1, 'Alimenticio', 'Produtos alimentícios (Espetos e Porções)', '2025-09-24 19:00:52'),
(3, 'Bebidas não alcoólicas', 'Bebidas sem álcool', '2025-09-24 19:00:52'),
(4, 'Bebidas alcoólicas', 'Bebidas com álcool (cervejas, drinks, etc.)', '2025-09-24 19:00:52'),
(5, 'Diversos', 'Outros produtos diversos', '2025-09-24 19:00:52');

-- --------------------------------------------------------

--
-- Estrutura para tabela `comandas`
--

CREATE TABLE `comandas` (
  `id` int(11) NOT NULL,
  `data_venda` timestamp NOT NULL DEFAULT current_timestamp(),
  `status` enum('aberta','fechada','cancelada') DEFAULT 'aberta',
  `valor_total` decimal(10,2) DEFAULT 0.00,
  `taxa_gorjeta` decimal(10,2) DEFAULT 0.00,
  `observacoes` text DEFAULT NULL,
  `garcom_id` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `data_finalizacao` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Despejando dados para a tabela `comandas`
--

INSERT INTO `comandas` (`id`, `data_venda`, `status`, `valor_total`, `taxa_gorjeta`, `observacoes`, `garcom_id`, `created_at`, `updated_at`, `data_finalizacao`) VALUES
(117, '2025-11-11 02:41:59', 'fechada', 45.00, 4.50, NULL, 1, '2025-11-11 02:18:16', '2025-11-11 02:41:59', NULL),
(118, '2025-11-11 02:41:53', 'fechada', 45.00, 4.50, NULL, 1, '2025-11-11 02:19:17', '2025-11-11 02:41:53', NULL),
(119, '2025-11-11 02:36:44', 'fechada', 54.00, 5.40, NULL, 1, '2025-11-11 02:33:25', '2025-11-11 02:36:44', NULL),
(120, '2025-11-11 02:36:35', 'fechada', 15.00, 1.50, NULL, 2, '2025-11-11 02:36:22', '2025-11-11 02:36:35', NULL),
(121, '2025-11-11 02:38:32', 'fechada', 73.00, 7.30, NULL, 1, '2025-11-11 02:38:19', '2025-11-11 02:38:32', NULL),
(122, '2025-11-11 02:38:43', 'fechada', 123.00, 12.30, NULL, 4, '2025-11-11 02:38:37', '2025-11-11 02:38:43', NULL),
(123, '2025-11-11 02:40:41', 'fechada', 15.00, 1.50, NULL, 3, '2025-11-11 02:40:35', '2025-11-11 02:40:41', NULL),
(124, '2025-11-11 02:41:46', 'fechada', 30.00, 3.00, NULL, 2, '2025-11-11 02:41:40', '2025-11-11 02:41:46', NULL),
(125, '2025-11-11 02:46:40', 'fechada', 73.00, 7.30, NULL, 3, '2025-11-11 02:46:33', '2025-11-11 02:46:40', NULL),
(126, '2025-11-11 02:52:24', 'fechada', 24.00, 2.40, NULL, 2, '2025-11-11 02:46:55', '2025-11-11 02:52:24', NULL),
(127, '2025-11-11 02:47:07', 'fechada', 73.00, 7.30, NULL, NULL, '2025-11-11 02:47:00', '2025-11-11 02:47:07', NULL),
(128, '2025-11-11 02:47:21', 'fechada', 73.00, 7.30, NULL, 4, '2025-11-11 02:47:13', '2025-11-11 02:47:21', NULL),
(129, '2025-11-11 02:49:36', 'fechada', 28.00, 2.80, NULL, 2, '2025-11-11 02:49:18', '2025-11-11 02:49:36', NULL),
(130, '2025-11-11 02:52:01', 'fechada', 24.00, 2.40, NULL, 4, '2025-11-11 02:51:51', '2025-11-11 02:52:01', NULL),
(131, '2025-11-11 02:53:10', 'fechada', 12.00, 1.20, NULL, NULL, '2025-11-11 02:52:57', '2025-11-11 02:53:10', NULL),
(132, '2025-11-11 02:54:11', 'fechada', 12.00, 1.20, NULL, NULL, '2025-11-11 02:54:08', '2025-11-11 02:54:11', NULL),
(133, '2025-11-11 02:54:28', 'fechada', 15.00, 1.50, NULL, NULL, '2025-11-11 02:54:26', '2025-11-11 02:54:28', NULL),
(134, '2025-11-11 02:55:48', 'fechada', 15.00, 1.50, NULL, NULL, '2025-11-11 02:55:46', '2025-11-11 02:55:48', NULL),
(135, '2025-11-11 02:57:41', 'fechada', 15.00, 1.50, NULL, NULL, '2025-11-11 02:57:38', '2025-11-11 02:57:41', NULL),
(136, '2025-11-11 03:13:37', 'fechada', 15.00, 1.50, NULL, NULL, '2025-11-11 03:13:13', '2025-11-11 03:13:37', NULL),
(137, '2025-11-11 03:15:17', 'fechada', 0.00, 0.00, NULL, NULL, '2025-11-11 03:14:20', '2025-11-11 03:15:17', NULL),
(138, '2025-11-11 03:15:35', 'fechada', 15.00, 1.50, NULL, 3, '2025-11-11 03:15:26', '2025-11-11 03:15:35', NULL),
(139, '2025-11-11 03:16:31', 'aberta', 0.00, 3.00, NULL, NULL, '2025-11-11 03:16:31', '2025-11-11 03:16:36', NULL),
(140, '2025-11-11 03:16:41', 'aberta', 0.00, 3.00, NULL, NULL, '2025-11-11 03:16:41', '2025-11-11 03:16:41', NULL),
(141, '2025-11-11 03:16:42', 'aberta', 0.00, 3.00, NULL, NULL, '2025-11-11 03:16:42', '2025-11-11 03:16:42', NULL),
(142, '2025-11-11 03:16:56', 'aberta', 0.00, 3.00, NULL, NULL, '2025-11-11 03:16:56', '2025-11-11 03:58:56', NULL),
(143, '2025-11-11 03:43:01', 'fechada', 15.00, 1.50, NULL, 3, '2025-11-11 03:17:07', '2025-11-11 03:43:01', NULL),
(144, '2025-11-11 03:18:10', 'fechada', 15.00, 1.50, NULL, 1, '2025-11-11 03:18:04', '2025-11-11 03:18:10', NULL),
(145, '2025-11-11 03:35:31', 'fechada', 45.00, 4.50, NULL, 4, '2025-11-11 03:35:18', '2025-11-11 03:35:31', NULL),
(146, '2025-11-11 03:49:34', 'fechada', 15.00, 1.50, NULL, 1, '2025-11-11 03:49:27', '2025-11-11 03:49:34', NULL),
(147, '2025-11-11 03:59:15', 'aberta', 0.00, 3.00, NULL, NULL, '2025-11-11 03:59:15', '2025-11-11 04:03:11', NULL);

--
-- Acionadores `comandas`
--
DELIMITER $$
CREATE TRIGGER `aplica_taxa_gorjeta` BEFORE UPDATE ON `comandas` FOR EACH ROW BEGIN
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
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estrutura stand-in para view `comanda_itens`
-- (Veja abaixo para a visão atual)
--
CREATE TABLE `comanda_itens` (
`id` int(11)
,`comanda_id` int(11)
,`produto_id` int(11)
,`quantidade` int(11)
,`preco_unitario` decimal(10,2)
,`subtotal` decimal(10,2)
,`created_at` timestamp
);

-- --------------------------------------------------------

--
-- Estrutura para tabela `configuracoes`
--

CREATE TABLE `configuracoes` (
  `id` int(11) NOT NULL,
  `taxa_gorjeta` decimal(5,2) DEFAULT 0.00,
  `tipo_taxa` enum('fixa','percentual','nenhuma') DEFAULT 'nenhuma',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Despejando dados para a tabela `configuracoes`
--

INSERT INTO `configuracoes` (`id`, `taxa_gorjeta`, `tipo_taxa`, `created_at`) VALUES
(1, 10.00, 'percentual', '2025-09-24 19:00:52');

-- --------------------------------------------------------

--
-- Estrutura para tabela `fornecedores`
--

CREATE TABLE `fornecedores` (
  `id` int(11) NOT NULL,
  `nome` varchar(100) NOT NULL,
  `contato` varchar(100) DEFAULT NULL,
  `telefone` varchar(20) DEFAULT NULL,
  `produtos_fornecidos` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura para tabela `garcons`
--

CREATE TABLE `garcons` (
  `id` int(11) NOT NULL,
  `nome` varchar(100) NOT NULL,
  `codigo` varchar(10) NOT NULL,
  `ativo` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Despejando dados para a tabela `garcons`
--

INSERT INTO `garcons` (`id`, `nome`, `codigo`, `ativo`, `created_at`) VALUES
(1, 'ezequiel', 'G01', 1, '2025-11-02 10:29:01'),
(2, 'fernanda', 'G02', 1, '2025-11-02 10:29:01'),
(3, 'lorrayne', 'G03', 1, '2025-11-02 10:29:01'),
(4, 'daniela', 'G04', 1, '2025-11-02 10:29:01');

-- --------------------------------------------------------

--
-- Estrutura para tabela `inventarios_estoque`
--

CREATE TABLE `inventarios_estoque` (
  `id` int(11) NOT NULL,
  `produto_id` int(11) NOT NULL,
  `quantidade_fisica` int(11) NOT NULL,
  `quantidade_sistema` int(11) NOT NULL,
  `diferenca` int(11) NOT NULL,
  `data_inventario` timestamp NOT NULL DEFAULT current_timestamp(),
  `observacao` text DEFAULT NULL,
  `usuario_id` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Despejando dados para a tabela `inventarios_estoque`
--

INSERT INTO `inventarios_estoque` (`id`, `produto_id`, `quantidade_fisica`, `quantidade_sistema`, `diferenca`, `data_inventario`, `observacao`, `usuario_id`, `created_at`) VALUES
(1, 38, 80, 99, -19, '2025-10-23 22:20:11', '', 1, '2025-10-23 22:20:11'),
(2, 18, 100, 119, -19, '2025-10-24 03:34:11', '', 1, '2025-10-24 03:34:11'),
(3, 43, 30, 30, 0, '2025-10-24 03:37:46', '', 1, '2025-10-24 03:37:46'),
(4, 18, 90, 100, -10, '2025-10-24 05:04:59', '', 1, '2025-10-24 05:04:59'),
(5, 20, 0, 0, 0, '2025-10-29 15:49:23', '', 1, '2025-10-29 15:49:23'),
(6, 11, 100, 0, 100, '2025-11-03 13:29:30', '', 1, '2025-11-03 13:29:30'),
(7, 38, 48, 0, 48, '2025-11-03 15:19:13', '', 1, '2025-11-03 15:19:13');

-- --------------------------------------------------------

--
-- Estrutura para tabela `itens_comanda`
--

CREATE TABLE `itens_comanda` (
  `id` int(11) NOT NULL,
  `comanda_id` int(11) NOT NULL,
  `produto_id` int(11) NOT NULL,
  `quantidade` int(11) NOT NULL DEFAULT 1,
  `preco_unitario` decimal(10,2) NOT NULL,
  `subtotal` decimal(10,2) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Despejando dados para a tabela `itens_comanda`
--

INSERT INTO `itens_comanda` (`id`, `comanda_id`, `produto_id`, `quantidade`, `preco_unitario`, `subtotal`, `created_at`) VALUES
(299, 119, 45, 1, 28.00, 28.00, '2025-11-11 02:33:40'),
(300, 119, 46, 1, 26.00, 26.00, '2025-11-11 02:33:52'),
(301, 120, 11, 1, 15.00, 15.00, '2025-11-11 02:36:28'),
(302, 121, 11, 1, 15.00, 15.00, '2025-11-11 02:38:26'),
(303, 121, 47, 1, 30.00, 30.00, '2025-11-11 02:38:28'),
(304, 121, 45, 1, 28.00, 28.00, '2025-11-11 02:38:29'),
(305, 122, 11, 1, 15.00, 15.00, '2025-11-11 02:38:39'),
(306, 122, 47, 1, 30.00, 30.00, '2025-11-11 02:38:40'),
(307, 122, 45, 1, 28.00, 28.00, '2025-11-11 02:38:40'),
(308, 122, 44, 1, 24.00, 24.00, '2025-11-11 02:38:41'),
(309, 122, 46, 1, 26.00, 26.00, '2025-11-11 02:38:42'),
(310, 123, 11, 1, 15.00, 15.00, '2025-11-11 02:40:37'),
(311, 118, 11, 1, 15.00, 15.00, '2025-11-11 02:41:41'),
(312, 124, 11, 2, 15.00, 30.00, '2025-11-11 02:41:44'),
(313, 118, 47, 1, 30.00, 30.00, '2025-11-11 02:41:51'),
(314, 117, 47, 1, 30.00, 30.00, '2025-11-11 02:41:56'),
(315, 117, 11, 1, 15.00, 15.00, '2025-11-11 02:41:57'),
(316, 125, 11, 1, 15.00, 15.00, '2025-11-11 02:46:35'),
(317, 125, 47, 1, 30.00, 30.00, '2025-11-11 02:46:36'),
(318, 125, 45, 1, 28.00, 28.00, '2025-11-11 02:46:37'),
(319, 127, 11, 1, 15.00, 15.00, '2025-11-11 02:47:00'),
(320, 127, 47, 1, 30.00, 30.00, '2025-11-11 02:47:03'),
(321, 127, 45, 1, 28.00, 28.00, '2025-11-11 02:47:04'),
(322, 128, 11, 1, 15.00, 15.00, '2025-11-11 02:47:16'),
(323, 128, 47, 1, 30.00, 30.00, '2025-11-11 02:47:17'),
(324, 128, 45, 1, 28.00, 28.00, '2025-11-11 02:47:17'),
(325, 129, 45, 1, 28.00, 28.00, '2025-11-11 02:49:27'),
(326, 130, 38, 2, 12.00, 24.00, '2025-11-11 02:51:53'),
(327, 126, 44, 1, 24.00, 24.00, '2025-11-11 02:52:17'),
(328, 131, 38, 1, 12.00, 12.00, '2025-11-11 02:52:57'),
(329, 132, 38, 1, 12.00, 12.00, '2025-11-11 02:54:08'),
(330, 133, 11, 1, 15.00, 15.00, '2025-11-11 02:54:26'),
(331, 134, 11, 1, 15.00, 15.00, '2025-11-11 02:55:46'),
(332, 135, 11, 1, 15.00, 15.00, '2025-11-11 02:57:38'),
(333, 136, 11, 1, 15.00, 15.00, '2025-11-11 03:13:13'),
(335, 138, 11, 1, 15.00, 15.00, '2025-11-11 03:15:30'),
(337, 144, 11, 1, 15.00, 15.00, '2025-11-11 03:18:06'),
(341, 145, 47, 1, 30.00, 30.00, '2025-11-11 03:35:26'),
(342, 145, 11, 1, 15.00, 15.00, '2025-11-11 03:35:28'),
(344, 143, 11, 1, 15.00, 15.00, '2025-11-11 03:42:57'),
(346, 146, 11, 1, 15.00, 15.00, '2025-11-11 03:49:31');

--
-- Acionadores `itens_comanda`
--
DELIMITER $$
CREATE TRIGGER `atualiza_total_comanda_insercao` AFTER INSERT ON `itens_comanda` FOR EACH ROW BEGIN
    UPDATE comandas 
    SET valor_total = (
        SELECT COALESCE(SUM(subtotal), 0) FROM itens_comanda WHERE comanda_id = NEW.comanda_id
    ) + (
        SELECT COALESCE(SUM(subtotal), 0) FROM itens_livres WHERE comanda_id = NEW.comanda_id
    ),
    updated_at = NOW()
    WHERE id = NEW.comanda_id;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estrutura para tabela `itens_livres`
--

CREATE TABLE `itens_livres` (
  `id` int(11) NOT NULL,
  `comanda_id` int(11) NOT NULL,
  `descricao` varchar(255) NOT NULL,
  `valor` decimal(10,2) NOT NULL,
  `quantidade` int(11) NOT NULL DEFAULT 1,
  `subtotal` decimal(10,2) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Acionadores `itens_livres`
--
DELIMITER $$
CREATE TRIGGER `atualiza_total_comanda_itens_livres` AFTER INSERT ON `itens_livres` FOR EACH ROW BEGIN
    UPDATE comandas 
    SET valor_total = (
        SELECT COALESCE(SUM(subtotal), 0) FROM itens_comanda WHERE comanda_id = NEW.comanda_id
    ) + (
        SELECT COALESCE(SUM(subtotal), 0) FROM itens_livres WHERE comanda_id = NEW.comanda_id
    ),
    updated_at = NOW()
    WHERE id = NEW.comanda_id;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estrutura para tabela `movimentacoes_estoque`
--

CREATE TABLE `movimentacoes_estoque` (
  `id` int(11) NOT NULL,
  `produto_id` int(11) NOT NULL,
  `tipo` enum('entrada','saida') NOT NULL,
  `quantidade` int(11) NOT NULL,
  `data_movimentacao` timestamp NOT NULL DEFAULT current_timestamp(),
  `observacao` text DEFAULT NULL,
  `fornecedor_id` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Despejando dados para a tabela `movimentacoes_estoque`
--

INSERT INTO `movimentacoes_estoque` (`id`, `produto_id`, `tipo`, `quantidade`, `data_movimentacao`, `observacao`, `fornecedor_id`, `created_at`) VALUES
(1, 18, 'entrada', 30, '2025-10-27 17:42:09', '\n', NULL, '2025-10-27 17:42:09'),
(2, 17, 'entrada', 30, '2025-10-27 17:42:19', '', NULL, '2025-10-27 17:42:19'),
(3, 28, 'entrada', 30, '2025-10-27 17:42:29', '', NULL, '2025-10-27 17:42:29'),
(4, 28, 'saida', 1, '2025-11-02 08:26:01', 'Venda comanda #68', NULL, '2025-11-02 08:26:01'),
(5, 17, 'saida', 1, '2025-11-02 08:26:35', 'Venda comanda #68', NULL, '2025-11-02 08:26:35'),
(6, 17, 'saida', 1, '2025-11-02 08:29:38', 'Venda comanda #68', NULL, '2025-11-02 08:29:38'),
(7, 18, 'saida', 1, '2025-11-02 09:12:32', 'Venda comanda #67', NULL, '2025-11-02 09:12:32'),
(8, 28, 'saida', 2, '2025-11-02 09:40:43', 'Venda comanda #69', NULL, '2025-11-02 09:40:43'),
(9, 44, 'entrada', 100, '2025-11-02 10:04:30', 'Estoque inicial', NULL, '2025-11-02 10:04:30'),
(10, 45, 'entrada', 100, '2025-11-02 10:05:05', 'Estoque inicial', NULL, '2025-11-02 10:05:05'),
(11, 46, 'entrada', 100, '2025-11-02 10:05:40', 'Estoque inicial', NULL, '2025-11-02 10:05:40'),
(12, 47, 'entrada', 100, '2025-11-02 10:06:06', 'Estoque inicial', NULL, '2025-11-02 10:06:06'),
(13, 28, 'saida', 1, '2025-11-02 10:33:34', 'Venda comanda #71', NULL, '2025-11-02 10:33:34'),
(14, 28, 'saida', 1, '2025-11-02 10:39:29', 'Venda comanda #72', NULL, '2025-11-02 10:39:29'),
(15, 28, 'saida', 1, '2025-11-02 10:50:37', 'Venda comanda #73', NULL, '2025-11-02 10:50:37'),
(16, 45, 'saida', 1, '2025-11-02 10:51:11', 'Venda comanda #74', NULL, '2025-11-02 10:51:11'),
(17, 11, 'entrada', 100, '2025-11-03 13:29:30', 'Ajuste de inventário: ', NULL, '2025-11-03 13:29:30'),
(18, 44, 'saida', 1, '2025-11-03 13:30:44', 'Venda comanda #80', NULL, '2025-11-03 13:30:44'),
(19, 47, 'saida', 3, '2025-11-03 15:12:21', 'Venda comanda #79', NULL, '2025-11-03 15:12:21'),
(20, 11, 'saida', 1, '2025-11-03 15:12:21', 'Venda comanda #79', NULL, '2025-11-03 15:12:21'),
(21, 38, 'entrada', 48, '2025-11-03 15:19:13', 'Ajuste de inventário: ', NULL, '2025-11-03 15:19:13'),
(22, 11, 'saida', 1, '2025-11-04 13:25:20', 'Venda comanda #90', NULL, '2025-11-04 13:25:20'),
(23, 11, 'saida', 1, '2025-11-11 02:57:38', 'Venda - Comanda 135', NULL, '2025-11-11 02:57:38'),
(24, 11, 'saida', 1, '2025-11-11 03:13:13', 'Venda - Comanda 136', NULL, '2025-11-11 03:13:13'),
(25, 11, 'saida', 1, '2025-11-11 03:14:20', 'Venda - Comanda 137', NULL, '2025-11-11 03:14:20'),
(26, 11, '', 1, '2025-11-11 03:15:11', 'Devolução - Item removido da Comanda 137', NULL, '2025-11-11 03:15:11'),
(27, 11, 'saida', 1, '2025-11-11 03:15:30', 'Venda - Comanda 138', NULL, '2025-11-11 03:15:30'),
(28, 11, 'saida', 1, '2025-11-11 03:16:31', 'Venda - Comanda 139', NULL, '2025-11-11 03:16:31'),
(29, 11, '', 1, '2025-11-11 03:16:36', 'Devolução - Item removido da Comanda 139', NULL, '2025-11-11 03:16:36'),
(30, 11, 'saida', 1, '2025-11-11 03:18:06', 'Venda - Comanda 144', NULL, '2025-11-11 03:18:06'),
(31, 11, 'saida', 1, '2025-11-11 03:23:12', 'Venda - Comanda 143', NULL, '2025-11-11 03:23:12'),
(32, 11, '', 1, '2025-11-11 03:23:18', 'Devolução - Item removido da Comanda 143', NULL, '2025-11-11 03:23:18'),
(33, 46, 'saida', 1, '2025-11-11 03:23:36', 'Venda - Comanda 143', NULL, '2025-11-11 03:23:36'),
(34, 46, '', 1, '2025-11-11 03:23:41', 'Devolução - Item removido da Comanda 143', NULL, '2025-11-11 03:23:41'),
(35, 44, 'saida', 1, '2025-11-11 03:33:29', 'Venda - Comanda 143', NULL, '2025-11-11 03:33:29'),
(36, 44, '', 1, '2025-11-11 03:33:34', 'Devolução - Item removido da Comanda 143', NULL, '2025-11-11 03:33:34'),
(37, 47, 'saida', 1, '2025-11-11 03:35:26', 'Venda - Comanda 145', NULL, '2025-11-11 03:35:26'),
(38, 11, 'saida', 1, '2025-11-11 03:35:28', 'Venda - Comanda 145', NULL, '2025-11-11 03:35:28'),
(39, 11, 'saida', 1, '2025-11-11 03:37:04', 'Venda - Comanda 143', NULL, '2025-11-11 03:37:04'),
(40, 11, '', 1, '2025-11-11 03:37:09', 'Devolução - Item removido da Comanda 143', NULL, '2025-11-11 03:37:09'),
(41, 11, 'saida', 1, '2025-11-11 03:42:57', 'Venda - Comanda 143', NULL, '2025-11-11 03:42:57'),
(42, 11, 'saida', 1, '2025-11-11 03:48:42', 'Venda - Comanda 142', NULL, '2025-11-11 03:48:42'),
(43, 11, '', 1, '2025-11-11 03:48:59', 'Devolução - Item removido da Comanda 142', NULL, '2025-11-11 03:48:59'),
(44, 11, 'saida', 1, '2025-11-11 03:49:31', 'Venda - Comanda 146', NULL, '2025-11-11 03:49:31'),
(45, 47, 'saida', 1, '2025-11-11 03:58:19', 'Venda - Comanda 142', NULL, '2025-11-11 03:58:19'),
(46, 47, '', 1, '2025-11-11 03:58:22', 'Devolução - Item removido da Comanda 142', NULL, '2025-11-11 03:58:22'),
(47, 11, 'saida', 1, '2025-11-11 03:58:34', 'Venda - Comanda 142', NULL, '2025-11-11 03:58:34'),
(48, 11, '', 1, '2025-11-11 03:58:56', 'Devolução - Item removido da Comanda 142', NULL, '2025-11-11 03:58:56'),
(49, 11, 'saida', 1, '2025-11-11 03:59:15', 'Venda - Comanda 147', NULL, '2025-11-11 03:59:15'),
(50, 11, '', 1, '2025-11-11 03:59:18', 'Devolução - Item removido da Comanda 147', NULL, '2025-11-11 03:59:18');

-- --------------------------------------------------------

--
-- Estrutura para tabela `produtos`
--

CREATE TABLE `produtos` (
  `id` int(11) NOT NULL,
  `nome` varchar(100) NOT NULL,
  `categoria_id` int(11) NOT NULL,
  `preco` decimal(10,2) NOT NULL,
  `estoque_atual` int(11) DEFAULT 0,
  `estoque_minimo` int(11) DEFAULT 0,
  `imagem` varchar(255) DEFAULT NULL,
  `ativo` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Despejando dados para a tabela `produtos`
--

INSERT INTO `produtos` (`id`, `nome`, `categoria_id`, `preco`, `estoque_atual`, `estoque_minimo`, `imagem`, `ativo`, `created_at`, `updated_at`) VALUES
(1, 'Frango com Bacon', 1, 10.00, 0, 0, NULL, 0, '2025-09-24 19:00:52', '2025-10-26 20:02:51'),
(2, 'espetos variados', 1, 10.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-10-26 20:02:51'),
(3, 'Contra Filé', 1, 10.00, 0, 0, NULL, 0, '2025-09-24 19:00:52', '2025-10-26 20:02:51'),
(4, 'Linguiça de porco', 1, 10.00, 0, 0, NULL, 0, '2025-09-24 19:00:52', '2025-10-26 20:02:51'),
(5, 'Provolone', 1, 10.00, 0, 0, NULL, 0, '2025-09-24 19:00:52', '2025-10-26 20:02:51'),
(6, 'Coração', 1, 10.00, 0, 0, NULL, 0, '2025-09-24 19:00:52', '2025-10-26 20:02:51'),
(7, 'Macarrão M', 1, 10.00, 0, 0, NULL, 0, '2025-09-24 19:00:52', '2025-11-02 09:10:56'),
(8, 'Mandioca M', 1, 10.00, 0, 0, NULL, 0, '2025-09-24 19:00:52', '2025-11-02 09:10:56'),
(9, 'Arroz/Mandioca/Macarrão M', 1, 10.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-11-02 09:10:56'),
(10, 'Salada M', 1, 12.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-11-02 09:10:56'),
(11, 'Feijão Tropeiro M', 1, 15.00, 67, 0, NULL, 1, '2025-09-24 19:00:52', '2025-11-11 03:59:18'),
(12, 'Macarrão G', 1, 20.00, 0, 0, NULL, 0, '2025-09-24 19:00:52', '2025-11-02 09:10:56'),
(13, 'Mandioca G', 1, 20.00, 0, 0, NULL, 0, '2025-09-24 19:00:52', '2025-11-02 09:10:56'),
(14, 'Arroz/Mandioca/Macarrão G', 1, 20.00, 0, 10, NULL, 1, '2025-09-24 19:00:52', '2025-11-03 15:15:06'),
(15, 'Salada G', 1, 22.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-11-02 09:10:56'),
(16, 'Feijão Tropeiro G', 1, 25.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-11-02 09:10:56'),
(17, 'Água Sem Gás', 3, 3.00, 20, 0, NULL, 1, '2025-09-24 19:00:52', '2025-11-07 01:33:10'),
(18, 'Água Com Gás', 3, 3.50, 27, 0, NULL, 1, '2025-09-24 19:00:52', '2025-11-02 09:12:32'),
(19, 'Coca-Cola KS', 3, 5.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-10-26 20:02:51'),
(20, 'Diversas latas 350ml', 3, 6.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-10-29 15:49:23'),
(21, 'Coca-Cola 600ml', 3, 8.00, -1, 0, NULL, 1, '2025-09-24 19:00:52', '2025-10-27 16:46:15'),
(22, 'H2OH', 3, 8.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-10-26 20:02:51'),
(23, 'Mineiro', 3, 8.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-10-26 20:02:51'),
(24, 'Energéticos', 3, 10.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-10-26 20:02:51'),
(25, 'Garrafas 1L', 3, 10.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-10-26 20:02:51'),
(26, 'Garrafas 2L (exceto Coca)', 3, 12.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-10-26 20:02:51'),
(27, 'H2OH 1,5L', 3, 12.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-10-26 20:02:51'),
(28, 'Coca-Cola 2L', 3, 14.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-11-06 21:54:18'),
(29, 'Sucos Life 900ml', 3, 18.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-10-26 20:02:51'),
(30, 'Barrigudinhas', 4, 4.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-10-26 20:02:51'),
(31, 'Latas e Beat\'s', 4, 6.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-10-26 20:02:51'),
(32, 'Skol/Antarctica/Brahama 600ml', 4, 10.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-11-02 10:10:44'),
(33, 'Long Necks', 4, 10.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-10-26 20:02:51'),
(34, 'Chopp', 4, 10.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-10-26 20:02:51'),
(35, 'Original/Budwiser', 4, 12.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-11-02 10:10:05'),
(36, 'Spaten', 4, 12.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-10-26 20:02:51'),
(37, 'Budweiser', 4, 12.00, 0, 0, NULL, 0, '2025-09-24 19:00:52', '2025-11-02 10:09:40'),
(38, 'Amstel 600ml', 4, 12.00, 48, 0, NULL, 1, '2025-09-24 19:00:52', '2025-11-03 15:19:13'),
(39, 'Heineken 600ml', 4, 15.00, 0, 0, NULL, 1, '2025-09-24 19:00:52', '2025-10-26 20:02:51'),
(40, 'teste', 3, 10.00, 0, 0, NULL, 0, '2025-10-21 15:34:16', '2025-10-26 20:02:51'),
(41, 'teste', 4, 10.00, 0, 0, NULL, 0, '2025-10-21 16:00:09', '2025-10-26 20:02:51'),
(42, 'teste', 3, 10.00, 0, 0, NULL, 0, '2025-10-23 05:35:19', '2025-10-26 20:02:51'),
(43, 'teste', 4, 20.00, 0, 0, NULL, 1, '2025-10-24 03:37:30', '2025-10-26 20:02:51'),
(44, 'Marmita com espeto', 1, 24.00, 94, 0, NULL, 1, '2025-11-02 10:04:30', '2025-11-11 03:33:34'),
(45, 'Jantinha com espeto', 1, 28.00, 95, 0, NULL, 1, '2025-11-02 10:05:05', '2025-11-06 21:54:09'),
(46, 'Marmita com bife', 1, 26.00, 98, 0, NULL, 1, '2025-11-02 10:05:40', '2025-11-11 03:23:41'),
(47, 'Jantinha com bife', 1, 30.00, 88, 0, NULL, 1, '2025-11-02 10:06:06', '2025-11-11 03:58:22');

-- --------------------------------------------------------

--
-- Estrutura para tabela `usuarios`
--

CREATE TABLE `usuarios` (
  `id` int(11) NOT NULL,
  `nome` varchar(100) NOT NULL,
  `email` varchar(100) NOT NULL,
  `senha` varchar(255) NOT NULL,
  `perfil` enum('admin','caixa','estoque') NOT NULL DEFAULT 'caixa',
  `ativo` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Despejando dados para a tabela `usuarios`
--

INSERT INTO `usuarios` (`id`, `nome`, `email`, `senha`, `perfil`, `ativo`, `created_at`, `updated_at`) VALUES
(1, 'Administrador', 'admin@sistema.com', '$2y$10$dt9xX1j/h34yV0gZMNeJjO6FK16lUJqBIxerHXFpKvqeSt2hdeQZK', 'admin', 1, '2025-09-24 19:00:52', '2025-11-11 01:45:32'),
(3, 'ezequiel', 'ezequielrod2020@gmail.com', '$2y$10$HoGFKSL8pF2.5X9yHfi3veuvcMm4MhVUBKKmsQfsqcsVEehepu7Xm', 'admin', 1, '2025-11-11 01:43:50', '2025-11-11 01:43:50');

-- --------------------------------------------------------

--
-- Estrutura stand-in para view `view_alertas_perda_estoque`
-- (Veja abaixo para a visão atual)
--
CREATE TABLE `view_alertas_perda_estoque` (
`id` int(11)
,`nome` varchar(100)
,`categoria` varchar(50)
,`estoque_atual` int(11)
,`estoque_minimo` int(11)
,`total_entradas` decimal(32,0)
,`total_vendido` decimal(32,0)
,`diferenca_estoque` decimal(34,0)
);

-- --------------------------------------------------------

--
-- Estrutura stand-in para view `view_comissoes_garcons`
-- (Veja abaixo para a visão atual)
--
CREATE TABLE `view_comissoes_garcons` (
`garcom_id` int(11)
,`garcom_nome` varchar(100)
,`garcom_codigo` varchar(10)
,`total_comandas` bigint(21)
,`valor_total_vendas` decimal(32,2)
,`comissao_calculada` decimal(35,4)
,`data_venda` date
);

-- --------------------------------------------------------

--
-- Estrutura stand-in para view `view_dashboard`
-- (Veja abaixo para a visão atual)
--
CREATE TABLE `view_dashboard` (
`vendas_hoje` bigint(21)
,`faturamento_hoje` decimal(32,2)
,`alertas_estoque` bigint(21)
,`ticket_medio` decimal(14,6)
);

-- --------------------------------------------------------

--
-- Estrutura stand-in para view `view_dashboard_aprimorado`
-- (Veja abaixo para a visão atual)
--
CREATE TABLE `view_dashboard_aprimorado` (
`vendas_hoje` bigint(21)
,`faturamento_hoje` decimal(32,2)
,`vendas_semana` bigint(21)
,`faturamento_semana` decimal(32,2)
,`vendas_mes` bigint(21)
,`faturamento_mes` decimal(32,2)
,`alertas_estoque` bigint(21)
,`alertas_perda` bigint(21)
,`ticket_medio_hoje` decimal(14,6)
,`ticket_medio_semana` decimal(14,6)
);

-- --------------------------------------------------------

--
-- Estrutura stand-in para view `view_estoque_minimo`
-- (Veja abaixo para a visão atual)
--
CREATE TABLE `view_estoque_minimo` (
`id` int(11)
,`nome` varchar(100)
,`estoque_atual` int(11)
,`estoque_minimo` int(11)
,`categoria` varchar(50)
,`quantidade_falta` bigint(12)
);

-- --------------------------------------------------------

--
-- Estrutura stand-in para view `view_produtos_mais_vendidos`
-- (Veja abaixo para a visão atual)
--
CREATE TABLE `view_produtos_mais_vendidos` (
`nome` varchar(100)
,`categoria_id` int(11)
,`categoria` varchar(50)
,`total_vendido` decimal(32,0)
,`valor_total_vendido` decimal(32,2)
);

-- --------------------------------------------------------

--
-- Estrutura stand-in para view `view_produtos_mais_vendidos_detalhado`
-- (Veja abaixo para a visão atual)
--
CREATE TABLE `view_produtos_mais_vendidos_detalhado` (
`id` int(11)
,`nome` varchar(100)
,`categoria_id` int(11)
,`categoria` varchar(50)
,`total_vendido` decimal(32,0)
,`valor_total_vendido` decimal(32,2)
,`total_comandas` bigint(21)
,`media_por_comanda` decimal(14,4)
);

-- --------------------------------------------------------

--
-- Estrutura stand-in para view `view_vendas_mensais`
-- (Veja abaixo para a visão atual)
--
CREATE TABLE `view_vendas_mensais` (
`mes_ano` varchar(7)
,`ano` int(4)
,`mes` int(2)
,`total_comandas` bigint(21)
,`valor_total_vendas` decimal(32,2)
,`total_gorjetas` decimal(32,2)
,`ticket_medio` decimal(14,6)
);

-- --------------------------------------------------------

--
-- Estrutura stand-in para view `view_vendas_periodo`
-- (Veja abaixo para a visão atual)
--
CREATE TABLE `view_vendas_periodo` (
`data_venda` date
,`total_comandas` bigint(21)
,`valor_total_vendas` decimal(32,2)
,`total_gorjetas` decimal(32,2)
,`ticket_medio` decimal(14,6)
);

-- --------------------------------------------------------

--
-- Estrutura stand-in para view `view_vendas_periodo_detalhado`
-- (Veja abaixo para a visão atual)
--
CREATE TABLE `view_vendas_periodo_detalhado` (
`data_venda` date
,`total_comandas` bigint(21)
,`valor_total_vendas` decimal(32,2)
,`total_gorjetas` decimal(32,2)
,`ticket_medio` decimal(14,6)
,`dia` int(2)
,`semana` int(2)
,`mes` int(2)
,`ano` int(4)
);

-- --------------------------------------------------------

--
-- Estrutura para view `comanda_itens`
--
DROP TABLE IF EXISTS `comanda_itens`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `comanda_itens`  AS SELECT `itens_comanda`.`id` AS `id`, `itens_comanda`.`comanda_id` AS `comanda_id`, `itens_comanda`.`produto_id` AS `produto_id`, `itens_comanda`.`quantidade` AS `quantidade`, `itens_comanda`.`preco_unitario` AS `preco_unitario`, `itens_comanda`.`subtotal` AS `subtotal`, `itens_comanda`.`created_at` AS `created_at` FROM `itens_comanda` ;

-- --------------------------------------------------------

--
-- Estrutura para view `view_alertas_perda_estoque`
--
DROP TABLE IF EXISTS `view_alertas_perda_estoque`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_alertas_perda_estoque`  AS SELECT `p`.`id` AS `id`, `p`.`nome` AS `nome`, `cat`.`nome` AS `categoria`, `p`.`estoque_atual` AS `estoque_atual`, `p`.`estoque_minimo` AS `estoque_minimo`, (select coalesce(sum(`me`.`quantidade`),0) from `movimentacoes_estoque` `me` where `me`.`produto_id` = `p`.`id` and `me`.`tipo` = 'entrada') AS `total_entradas`, (select coalesce(sum(`ic`.`quantidade`),0) from (`itens_comanda` `ic` join `comandas` `c` on(`ic`.`comanda_id` = `c`.`id`)) where `ic`.`produto_id` = `p`.`id` and `c`.`status` = 'fechada') AS `total_vendido`, (select coalesce(sum(`movimentacoes_estoque`.`quantidade`),0) from `movimentacoes_estoque` where `movimentacoes_estoque`.`produto_id` = `p`.`id` and `movimentacoes_estoque`.`tipo` = 'entrada') - (select coalesce(sum(`ic`.`quantidade`),0) from (`itens_comanda` `ic` join `comandas` `c` on(`ic`.`comanda_id` = `c`.`id`)) where `ic`.`produto_id` = `p`.`id` and `c`.`status` = 'fechada') - `p`.`estoque_atual` AS `diferenca_estoque` FROM (`produtos` `p` join `categorias` `cat` on(`p`.`categoria_id` = `cat`.`id`)) WHERE `p`.`ativo` = 1 ;

-- --------------------------------------------------------

--
-- Estrutura para view `view_comissoes_garcons`
--
DROP TABLE IF EXISTS `view_comissoes_garcons`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_comissoes_garcons`  AS SELECT `g`.`id` AS `garcom_id`, `g`.`nome` AS `garcom_nome`, `g`.`codigo` AS `garcom_codigo`, count(`c`.`id`) AS `total_comandas`, sum(`c`.`valor_total`) AS `valor_total_vendas`, sum(`c`.`valor_total` * 0.03) AS `comissao_calculada`, cast(`c`.`data_venda` as date) AS `data_venda` FROM (`comandas` `c` join `garcons` `g` on(`c`.`garcom_id` = `g`.`id`)) WHERE `c`.`status` = 'fechada' GROUP BY `g`.`id`, `g`.`nome`, `g`.`codigo`, cast(`c`.`data_venda` as date) ORDER BY cast(`c`.`data_venda` as date) DESC, sum(`c`.`valor_total` * 0.03) DESC ;

-- --------------------------------------------------------

--
-- Estrutura para view `view_dashboard`
--
DROP TABLE IF EXISTS `view_dashboard`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_dashboard`  AS SELECT (select count(0) from `comandas` where cast(`comandas`.`data_venda` as date) = curdate() and `comandas`.`status` = 'fechada') AS `vendas_hoje`, (select coalesce(sum(`comandas`.`valor_total`),0) from `comandas` where cast(`comandas`.`data_venda` as date) = curdate() and `comandas`.`status` = 'fechada') AS `faturamento_hoje`, (select count(0) from `produtos` where `produtos`.`estoque_atual` <= `produtos`.`estoque_minimo` and `produtos`.`ativo` = 1) AS `alertas_estoque`, (select coalesce(avg(`comandas`.`valor_total`),0) from `comandas` where cast(`comandas`.`data_venda` as date) = curdate() and `comandas`.`status` = 'fechada') AS `ticket_medio` ;

-- --------------------------------------------------------

--
-- Estrutura para view `view_dashboard_aprimorado`
--
DROP TABLE IF EXISTS `view_dashboard_aprimorado`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_dashboard_aprimorado`  AS SELECT (select count(0) from `comandas` where cast(`comandas`.`data_venda` as date) = curdate() and `comandas`.`status` = 'fechada') AS `vendas_hoje`, (select coalesce(sum(`comandas`.`valor_total`),0) from `comandas` where cast(`comandas`.`data_venda` as date) = curdate() and `comandas`.`status` = 'fechada') AS `faturamento_hoje`, (select count(0) from `comandas` where yearweek(`comandas`.`data_venda`,0) = yearweek(current_timestamp(),0) and `comandas`.`status` = 'fechada') AS `vendas_semana`, (select coalesce(sum(`comandas`.`valor_total`),0) from `comandas` where yearweek(`comandas`.`data_venda`,0) = yearweek(current_timestamp(),0) and `comandas`.`status` = 'fechada') AS `faturamento_semana`, (select count(0) from `comandas` where year(`comandas`.`data_venda`) = year(current_timestamp()) and month(`comandas`.`data_venda`) = month(current_timestamp()) and `comandas`.`status` = 'fechada') AS `vendas_mes`, (select coalesce(sum(`comandas`.`valor_total`),0) from `comandas` where year(`comandas`.`data_venda`) = year(current_timestamp()) and month(`comandas`.`data_venda`) = month(current_timestamp()) and `comandas`.`status` = 'fechada') AS `faturamento_mes`, (select count(0) from `produtos` where `produtos`.`estoque_atual` <= `produtos`.`estoque_minimo` and `produtos`.`ativo` = 1) AS `alertas_estoque`, (select count(0) from `view_alertas_perda_estoque` where `view_alertas_perda_estoque`.`diferenca_estoque` > 0) AS `alertas_perda`, (select coalesce(avg(`comandas`.`valor_total`),0) from `comandas` where cast(`comandas`.`data_venda` as date) = curdate() and `comandas`.`status` = 'fechada') AS `ticket_medio_hoje`, (select coalesce(avg(`comandas`.`valor_total`),0) from `comandas` where yearweek(`comandas`.`data_venda`,0) = yearweek(current_timestamp(),0) and `comandas`.`status` = 'fechada') AS `ticket_medio_semana` ;

-- --------------------------------------------------------

--
-- Estrutura para view `view_estoque_minimo`
--
DROP TABLE IF EXISTS `view_estoque_minimo`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_estoque_minimo`  AS SELECT `p`.`id` AS `id`, `p`.`nome` AS `nome`, `p`.`estoque_atual` AS `estoque_atual`, `p`.`estoque_minimo` AS `estoque_minimo`, `cat`.`nome` AS `categoria`, `p`.`estoque_minimo`- `p`.`estoque_atual` AS `quantidade_falta` FROM (`produtos` `p` join `categorias` `cat` on(`p`.`categoria_id` = `cat`.`id`)) WHERE `p`.`estoque_atual` <= `p`.`estoque_minimo` AND `p`.`ativo` = 1 ORDER BY `p`.`estoque_minimo`- `p`.`estoque_atual` DESC ;

-- --------------------------------------------------------

--
-- Estrutura para view `view_produtos_mais_vendidos`
--
DROP TABLE IF EXISTS `view_produtos_mais_vendidos`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_produtos_mais_vendidos`  AS SELECT `p`.`nome` AS `nome`, `p`.`categoria_id` AS `categoria_id`, `cat`.`nome` AS `categoria`, sum(`ic`.`quantidade`) AS `total_vendido`, sum(`ic`.`subtotal`) AS `valor_total_vendido` FROM (((`itens_comanda` `ic` join `produtos` `p` on(`ic`.`produto_id` = `p`.`id`)) join `categorias` `cat` on(`p`.`categoria_id` = `cat`.`id`)) join `comandas` `c` on(`ic`.`comanda_id` = `c`.`id`)) WHERE `c`.`status` = 'fechada' GROUP BY `p`.`id` ORDER BY sum(`ic`.`quantidade`) DESC ;

-- --------------------------------------------------------

--
-- Estrutura para view `view_produtos_mais_vendidos_detalhado`
--
DROP TABLE IF EXISTS `view_produtos_mais_vendidos_detalhado`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_produtos_mais_vendidos_detalhado`  AS SELECT `p`.`id` AS `id`, `p`.`nome` AS `nome`, `p`.`categoria_id` AS `categoria_id`, `cat`.`nome` AS `categoria`, sum(`ic`.`quantidade`) AS `total_vendido`, sum(`ic`.`subtotal`) AS `valor_total_vendido`, count(distinct `ic`.`comanda_id`) AS `total_comandas`, avg(`ic`.`quantidade`) AS `media_por_comanda` FROM (((`itens_comanda` `ic` join `produtos` `p` on(`ic`.`produto_id` = `p`.`id`)) join `categorias` `cat` on(`p`.`categoria_id` = `cat`.`id`)) join `comandas` `c` on(`ic`.`comanda_id` = `c`.`id`)) WHERE `c`.`status` = 'fechada' GROUP BY `p`.`id` ORDER BY sum(`ic`.`quantidade`) DESC ;

-- --------------------------------------------------------

--
-- Estrutura para view `view_vendas_mensais`
--
DROP TABLE IF EXISTS `view_vendas_mensais`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_vendas_mensais`  AS SELECT concat(year(`comandas`.`data_venda`),'-',lpad(month(`comandas`.`data_venda`),2,'0')) AS `mes_ano`, year(`comandas`.`data_venda`) AS `ano`, month(`comandas`.`data_venda`) AS `mes`, count(`comandas`.`id`) AS `total_comandas`, sum(`comandas`.`valor_total`) AS `valor_total_vendas`, sum(`comandas`.`taxa_gorjeta`) AS `total_gorjetas`, avg(`comandas`.`valor_total`) AS `ticket_medio` FROM `comandas` WHERE `comandas`.`status` = 'fechada' GROUP BY year(`comandas`.`data_venda`), month(`comandas`.`data_venda`) ORDER BY year(`comandas`.`data_venda`) DESC, month(`comandas`.`data_venda`) DESC ;

-- --------------------------------------------------------

--
-- Estrutura para view `view_vendas_periodo`
--
DROP TABLE IF EXISTS `view_vendas_periodo`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_vendas_periodo`  AS SELECT cast(`comandas`.`data_venda` as date) AS `data_venda`, count(`comandas`.`id`) AS `total_comandas`, sum(`comandas`.`valor_total`) AS `valor_total_vendas`, sum(`comandas`.`taxa_gorjeta`) AS `total_gorjetas`, avg(`comandas`.`valor_total`) AS `ticket_medio` FROM `comandas` WHERE `comandas`.`status` = 'fechada' GROUP BY cast(`comandas`.`data_venda` as date) ;

-- --------------------------------------------------------

--
-- Estrutura para view `view_vendas_periodo_detalhado`
--
DROP TABLE IF EXISTS `view_vendas_periodo_detalhado`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_vendas_periodo_detalhado`  AS SELECT cast(`comandas`.`data_venda` as date) AS `data_venda`, count(`comandas`.`id`) AS `total_comandas`, sum(`comandas`.`valor_total`) AS `valor_total_vendas`, sum(`comandas`.`taxa_gorjeta`) AS `total_gorjetas`, avg(`comandas`.`valor_total`) AS `ticket_medio`, dayofmonth(`comandas`.`data_venda`) AS `dia`, week(`comandas`.`data_venda`) AS `semana`, month(`comandas`.`data_venda`) AS `mes`, year(`comandas`.`data_venda`) AS `ano` FROM `comandas` WHERE `comandas`.`status` = 'fechada' GROUP BY cast(`comandas`.`data_venda` as date) ;

--
-- Índices para tabelas despejadas
--

--
-- Índices de tabela `categorias`
--
ALTER TABLE `categorias`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `nome` (`nome`);

--
-- Índices de tabela `comandas`
--
ALTER TABLE `comandas`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_comandas_data_status` (`data_venda`,`status`),
  ADD KEY `fk_comanda_garcom` (`garcom_id`);

--
-- Índices de tabela `configuracoes`
--
ALTER TABLE `configuracoes`
  ADD PRIMARY KEY (`id`);

--
-- Índices de tabela `fornecedores`
--
ALTER TABLE `fornecedores`
  ADD PRIMARY KEY (`id`);

--
-- Índices de tabela `garcons`
--
ALTER TABLE `garcons`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `codigo` (`codigo`);

--
-- Índices de tabela `inventarios_estoque`
--
ALTER TABLE `inventarios_estoque`
  ADD PRIMARY KEY (`id`),
  ADD KEY `produto_id` (`produto_id`),
  ADD KEY `usuario_id` (`usuario_id`),
  ADD KEY `data_inventario` (`data_inventario`);

--
-- Índices de tabela `itens_comanda`
--
ALTER TABLE `itens_comanda`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_itens_comanda_comanda` (`comanda_id`),
  ADD KEY `idx_itens_comanda_produto` (`produto_id`);

--
-- Índices de tabela `itens_livres`
--
ALTER TABLE `itens_livres`
  ADD PRIMARY KEY (`id`),
  ADD KEY `comanda_id` (`comanda_id`);

--
-- Índices de tabela `movimentacoes_estoque`
--
ALTER TABLE `movimentacoes_estoque`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fornecedor_id` (`fornecedor_id`),
  ADD KEY `idx_movimentacoes_data` (`data_movimentacao`),
  ADD KEY `idx_movimentacoes_produto` (`produto_id`);

--
-- Índices de tabela `produtos`
--
ALTER TABLE `produtos`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_produtos_categoria` (`categoria_id`),
  ADD KEY `idx_produtos_ativo` (`ativo`);

--
-- Índices de tabela `usuarios`
--
ALTER TABLE `usuarios`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`);

--
-- AUTO_INCREMENT para tabelas despejadas
--

--
-- AUTO_INCREMENT de tabela `categorias`
--
ALTER TABLE `categorias`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT de tabela `comandas`
--
ALTER TABLE `comandas`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=148;

--
-- AUTO_INCREMENT de tabela `configuracoes`
--
ALTER TABLE `configuracoes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de tabela `fornecedores`
--
ALTER TABLE `fornecedores`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de tabela `garcons`
--
ALTER TABLE `garcons`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT de tabela `inventarios_estoque`
--
ALTER TABLE `inventarios_estoque`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT de tabela `itens_comanda`
--
ALTER TABLE `itens_comanda`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=351;

--
-- AUTO_INCREMENT de tabela `itens_livres`
--
ALTER TABLE `itens_livres`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de tabela `movimentacoes_estoque`
--
ALTER TABLE `movimentacoes_estoque`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=51;

--
-- AUTO_INCREMENT de tabela `produtos`
--
ALTER TABLE `produtos`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=48;

--
-- AUTO_INCREMENT de tabela `usuarios`
--
ALTER TABLE `usuarios`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- Restrições para tabelas despejadas
--

--
-- Restrições para tabelas `comandas`
--
ALTER TABLE `comandas`
  ADD CONSTRAINT `fk_comanda_garcom` FOREIGN KEY (`garcom_id`) REFERENCES `garcons` (`id`);

--
-- Restrições para tabelas `inventarios_estoque`
--
ALTER TABLE `inventarios_estoque`
  ADD CONSTRAINT `inventarios_estoque_ibfk_1` FOREIGN KEY (`produto_id`) REFERENCES `produtos` (`id`),
  ADD CONSTRAINT `inventarios_estoque_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`);

--
-- Restrições para tabelas `itens_comanda`
--
ALTER TABLE `itens_comanda`
  ADD CONSTRAINT `itens_comanda_ibfk_1` FOREIGN KEY (`comanda_id`) REFERENCES `comandas` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `itens_comanda_ibfk_2` FOREIGN KEY (`produto_id`) REFERENCES `produtos` (`id`);

--
-- Restrições para tabelas `itens_livres`
--
ALTER TABLE `itens_livres`
  ADD CONSTRAINT `itens_livres_ibfk_1` FOREIGN KEY (`comanda_id`) REFERENCES `comandas` (`id`) ON DELETE CASCADE;

--
-- Restrições para tabelas `movimentacoes_estoque`
--
ALTER TABLE `movimentacoes_estoque`
  ADD CONSTRAINT `movimentacoes_estoque_ibfk_1` FOREIGN KEY (`produto_id`) REFERENCES `produtos` (`id`),
  ADD CONSTRAINT `movimentacoes_estoque_ibfk_2` FOREIGN KEY (`fornecedor_id`) REFERENCES `fornecedores` (`id`);

--
-- Restrições para tabelas `produtos`
--
ALTER TABLE `produtos`
  ADD CONSTRAINT `produtos_ibfk_1` FOREIGN KEY (`categoria_id`) REFERENCES `categorias` (`id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
