-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Tempo de geração: 21/10/2025 às 18:17
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
(1, 'Espetos', 'Espetos variados', '2025-09-24 19:00:52'),
(2, 'Porções', 'Porções de diferentes tamanhos', '2025-09-24 19:00:52'),
(3, 'Bebidas', 'Bebidas não alcoólicas', '2025-09-24 19:00:52'),
(4, 'Cervejas', 'Cervejas e bebidas alcoólicas', '2025-09-24 19:00:52'),
(5, 'Diversos', 'Outros produtos', '2025-09-24 19:00:52');

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
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Despejando dados para a tabela `comandas`
--

INSERT INTO `comandas` (`id`, `data_venda`, `status`, `valor_total`, `taxa_gorjeta`, `observacoes`, `created_at`, `updated_at`) VALUES
(1, '2025-09-24 19:00:53', 'fechada', 45.00, 4.50, NULL, '2025-09-24 19:00:53', '2025-09-24 19:00:53'),
(2, '2025-09-26 05:13:00', 'fechada', 40.00, 4.00, NULL, '2025-09-26 05:11:55', '2025-09-26 05:13:00'),
(3, '2025-09-26 05:15:01', 'fechada', 100.00, 10.00, NULL, '2025-09-26 05:13:45', '2025-09-26 05:15:01'),
(4, '2025-09-26 05:17:11', 'fechada', 38.00, 3.80, NULL, '2025-09-26 05:16:52', '2025-09-26 05:17:11'),
(5, '2025-09-26 05:20:14', 'fechada', 48.00, 4.80, NULL, '2025-09-26 05:19:57', '2025-09-26 05:20:14'),
(6, '2025-09-26 05:21:38', 'fechada', 36.00, 3.60, NULL, '2025-09-26 05:21:20', '2025-09-26 05:21:38'),
(7, '2025-09-28 20:38:49', 'fechada', 540.00, 54.00, NULL, '2025-09-28 20:38:25', '2025-09-28 20:38:49'),
(8, '2025-09-29 02:15:34', 'fechada', 29.00, 2.90, NULL, '2025-09-29 02:14:53', '2025-09-29 02:15:34'),
(9, '2025-09-30 03:06:02', 'fechada', 74.00, 7.40, NULL, '2025-09-30 03:05:21', '2025-09-30 03:06:02'),
(10, '2025-09-30 03:16:45', 'fechada', 65.00, 6.50, NULL, '2025-09-30 03:14:49', '2025-09-30 03:16:45'),
(11, '2025-10-15 04:15:24', 'fechada', 40.00, 4.00, NULL, '2025-09-30 03:17:22', '2025-10-15 04:15:24'),
(12, '2025-09-30 03:17:31', 'fechada', 42.00, 4.20, NULL, '2025-09-30 03:17:22', '2025-09-30 03:17:31'),
(13, '2025-09-30 12:52:46', 'fechada', 26.00, 2.60, NULL, '2025-09-30 12:52:34', '2025-09-30 12:52:46'),
(14, '2025-10-12 19:14:03', 'fechada', 20.50, 2.05, NULL, '2025-10-12 19:13:58', '2025-10-12 19:14:03'),
(15, '2025-10-14 21:33:50', 'fechada', 29.00, 2.90, NULL, '2025-10-14 21:33:42', '2025-10-14 21:33:50'),
(16, '2025-10-14 21:35:11', 'fechada', 28.00, 2.80, NULL, '2025-10-14 21:35:03', '2025-10-14 21:35:11'),
(17, '2025-10-14 21:58:32', 'fechada', 34.00, 3.40, NULL, '2025-10-14 21:57:52', '2025-10-14 21:58:32'),
(18, '2025-10-15 04:06:53', 'fechada', 69.00, 6.90, NULL, '2025-10-15 03:56:23', '2025-10-15 04:06:53'),
(19, '2025-10-15 04:21:46', 'fechada', 32.00, 3.20, NULL, '2025-10-15 04:21:41', '2025-10-15 04:21:46'),
(20, '2025-10-15 04:25:36', 'fechada', 5.00, 0.50, NULL, '2025-10-15 04:25:29', '2025-10-15 04:25:36'),
(21, '2025-10-15 04:25:48', 'fechada', 5.00, 0.50, NULL, '2025-10-15 04:25:44', '2025-10-15 04:25:48'),
(22, '2025-10-15 04:25:53', 'fechada', 5.00, 0.50, NULL, '2025-10-15 04:25:49', '2025-10-15 04:25:53'),
(23, '2025-10-15 04:46:39', 'aberta', 0.00, 0.00, NULL, '2025-10-15 04:46:39', '2025-10-15 04:46:39'),
(24, '2025-10-15 04:46:41', 'aberta', 0.00, 0.00, NULL, '2025-10-15 04:46:41', '2025-10-15 04:46:41'),
(26, '2025-10-15 04:46:49', 'aberta', 0.00, 0.00, NULL, '2025-10-15 04:46:49', '2025-10-15 04:46:49'),
(27, '2025-10-15 04:46:54', 'aberta', 0.00, 0.00, NULL, '2025-10-15 04:46:54', '2025-10-15 04:46:54'),
(28, '2025-10-15 04:46:59', 'aberta', 0.00, 0.00, NULL, '2025-10-15 04:46:59', '2025-10-15 04:46:59'),
(29, '2025-10-15 04:49:13', 'aberta', 0.00, 0.00, NULL, '2025-10-15 04:49:13', '2025-10-15 04:49:13'),
(30, '2025-10-15 04:51:21', 'aberta', 0.00, 0.00, NULL, '2025-10-15 04:51:21', '2025-10-15 04:51:21'),
(31, '2025-10-15 04:52:22', 'aberta', 0.00, 0.00, NULL, '2025-10-15 04:52:22', '2025-10-15 04:52:22'),
(32, '2025-10-15 04:59:02', 'aberta', 0.00, 0.00, NULL, '2025-10-15 04:59:02', '2025-10-15 04:59:02'),
(33, '2025-10-15 05:01:01', 'aberta', 0.00, 0.00, NULL, '2025-10-15 05:01:01', '2025-10-15 05:01:01'),
(34, '2025-10-15 17:04:39', 'fechada', 6.00, 0.60, NULL, '2025-10-15 05:01:19', '2025-10-15 17:04:39'),
(35, '2025-10-15 16:55:25', 'fechada', 12.00, 1.20, NULL, '2025-10-15 05:09:16', '2025-10-15 16:55:25'),
(36, '2025-10-15 07:22:09', 'fechada', 30.00, 3.00, NULL, '2025-10-15 06:33:24', '2025-10-15 07:22:09'),
(37, '2025-10-15 07:21:05', 'fechada', 28.00, 2.80, NULL, '2025-10-15 07:09:59', '2025-10-15 07:21:05'),
(38, '2025-10-15 16:55:38', 'fechada', 12.00, 1.20, NULL, '2025-10-15 16:55:32', '2025-10-15 16:55:38'),
(39, '2025-10-15 17:03:24', 'fechada', 6.00, 0.60, NULL, '2025-10-15 16:55:40', '2025-10-15 17:03:24'),
(40, '2025-10-15 16:57:03', 'fechada', 28.00, 2.80, NULL, '2025-10-15 16:56:56', '2025-10-15 16:57:03'),
(41, '2025-10-15 21:15:49', 'fechada', 33.00, 3.30, NULL, '2025-10-15 21:15:45', '2025-10-15 21:15:49'),
(42, '2025-10-21 14:08:23', 'fechada', 53.00, 5.30, 'Comanda de teste do sistema', '2025-10-15 21:20:07', '2025-10-21 14:08:23'),
(43, '2025-10-20 15:08:32', 'fechada', 27.00, 2.70, 'Comanda de teste do sistema', '2025-10-15 21:20:10', '2025-10-20 15:08:32'),
(44, '2025-10-20 14:57:47', 'fechada', 26.00, 2.60, 'Comanda de teste do sistema', '2025-10-15 21:22:10', '2025-10-20 14:57:47'),
(45, '2025-10-16 10:51:07', 'fechada', 52.00, 5.20, 'Comanda de teste do sistema', '2025-10-15 21:22:26', '2025-10-16 10:51:07');

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
(1, 1, 1, 2, 10.00, 20.00, '2025-09-24 19:00:53'),
(2, 1, 23, 1, 5.00, 5.00, '2025-09-24 19:00:53'),
(3, 1, 35, 2, 10.00, 20.00, '2025-09-24 19:00:53'),
(4, 2, 24, 1, 10.00, 10.00, '2025-09-26 05:12:29'),
(5, 2, 2, 1, 10.00, 10.00, '2025-09-26 05:12:41'),
(6, 2, 13, 1, 20.00, 20.00, '2025-09-26 05:12:51'),
(7, 3, 32, 1, 10.00, 10.00, '2025-09-26 05:14:19'),
(8, 3, 32, 1, 10.00, 10.00, '2025-09-26 05:14:20'),
(9, 3, 32, 1, 10.00, 10.00, '2025-09-26 05:14:21'),
(10, 3, 32, 1, 10.00, 10.00, '2025-09-26 05:14:21'),
(11, 3, 32, 1, 10.00, 10.00, '2025-09-26 05:14:22'),
(12, 3, 32, 1, 10.00, 10.00, '2025-09-26 05:14:23'),
(13, 3, 32, 1, 10.00, 10.00, '2025-09-26 05:14:24'),
(14, 3, 32, 1, 10.00, 10.00, '2025-09-26 05:14:25'),
(15, 3, 32, 1, 10.00, 10.00, '2025-09-26 05:14:25'),
(16, 3, 32, 1, 10.00, 10.00, '2025-09-26 05:14:26'),
(17, 4, 30, 1, 4.00, 4.00, '2025-09-26 05:16:57'),
(18, 4, 37, 1, 12.00, 12.00, '2025-09-26 05:17:00'),
(19, 4, 35, 1, 12.00, 12.00, '2025-09-26 05:17:02'),
(20, 4, 33, 1, 10.00, 10.00, '2025-09-26 05:17:03'),
(21, 5, 30, 1, 4.00, 4.00, '2025-09-26 05:20:01'),
(22, 5, 33, 1, 10.00, 10.00, '2025-09-26 05:20:04'),
(23, 5, 37, 1, 12.00, 12.00, '2025-09-26 05:20:06'),
(24, 5, 34, 1, 10.00, 10.00, '2025-09-26 05:20:07'),
(25, 5, 35, 1, 12.00, 12.00, '2025-09-26 05:20:08'),
(26, 6, 37, 1, 12.00, 12.00, '2025-09-26 05:21:23'),
(27, 6, 30, 1, 4.00, 4.00, '2025-09-26 05:21:24'),
(28, 6, 3, 1, 10.00, 10.00, '2025-09-26 05:21:33'),
(29, 6, 3, 1, 10.00, 10.00, '2025-09-26 05:21:34'),
(30, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:27'),
(31, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:28'),
(32, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:28'),
(33, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:28'),
(34, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:28'),
(35, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:29'),
(36, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:29'),
(37, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:29'),
(38, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:29'),
(39, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:29'),
(40, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:29'),
(41, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:30'),
(42, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:30'),
(43, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:30'),
(44, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:30'),
(45, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:30'),
(46, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:31'),
(47, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:31'),
(48, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:31'),
(49, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:31'),
(50, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:31'),
(51, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:32'),
(52, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:32'),
(53, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:32'),
(54, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:32'),
(55, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:32'),
(56, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:32'),
(57, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:33'),
(58, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:33'),
(59, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:33'),
(60, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:33'),
(61, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:34'),
(62, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:34'),
(63, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:34'),
(64, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:35'),
(65, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:35'),
(66, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:35'),
(67, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:35'),
(68, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:35'),
(69, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:35'),
(70, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:36'),
(71, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:36'),
(72, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:36'),
(73, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:36'),
(74, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:36'),
(75, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:36'),
(76, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:36'),
(77, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:36'),
(78, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:36'),
(79, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:37'),
(80, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:37'),
(81, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:37'),
(82, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:37'),
(83, 7, 9, 1, 10.00, 10.00, '2025-09-28 20:38:37'),
(84, 8, 17, 1, 3.00, 3.00, '2025-09-29 02:14:57'),
(85, 8, 20, 1, 6.00, 6.00, '2025-09-29 02:15:08'),
(86, 8, 24, 1, 10.00, 10.00, '2025-09-29 02:15:09'),
(87, 8, 33, 1, 10.00, 10.00, '2025-09-29 02:15:27'),
(88, 9, 20, 1, 6.00, 6.00, '2025-09-30 03:05:42'),
(89, 9, 20, 1, 6.00, 6.00, '2025-09-30 03:05:42'),
(90, 9, 20, 1, 6.00, 6.00, '2025-09-30 03:05:42'),
(91, 9, 20, 1, 6.00, 6.00, '2025-09-30 03:05:42'),
(92, 9, 13, 1, 20.00, 20.00, '2025-09-30 03:05:47'),
(93, 9, 13, 1, 20.00, 20.00, '2025-09-30 03:05:48'),
(94, 9, 2, 1, 10.00, 10.00, '2025-09-30 03:05:52'),
(95, 10, 20, 1, 6.00, 6.00, '2025-09-30 03:14:51'),
(96, 10, 24, 1, 10.00, 10.00, '2025-09-30 03:14:52'),
(97, 10, 17, 1, 3.00, 3.00, '2025-09-30 03:14:53'),
(98, 10, 30, 1, 4.00, 4.00, '2025-09-30 03:15:19'),
(99, 10, 37, 1, 12.00, 12.00, '2025-09-30 03:15:20'),
(100, 10, 13, 1, 20.00, 20.00, '2025-09-30 03:15:24'),
(101, 10, 3, 1, 10.00, 10.00, '2025-09-30 03:16:12'),
(102, 12, 20, 1, 6.00, 6.00, '2025-09-30 03:17:24'),
(103, 12, 20, 1, 6.00, 6.00, '2025-09-30 03:17:25'),
(104, 12, 20, 1, 6.00, 6.00, '2025-09-30 03:17:25'),
(105, 12, 20, 1, 6.00, 6.00, '2025-09-30 03:17:26'),
(106, 12, 20, 1, 6.00, 6.00, '2025-09-30 03:17:26'),
(107, 12, 20, 1, 6.00, 6.00, '2025-09-30 03:17:26'),
(108, 12, 20, 1, 6.00, 6.00, '2025-09-30 03:17:27'),
(109, 13, 30, 1, 4.00, 4.00, '2025-09-30 12:52:39'),
(110, 13, 37, 1, 12.00, 12.00, '2025-09-30 12:52:40'),
(111, 13, 33, 1, 10.00, 10.00, '2025-09-30 12:52:41'),
(112, 14, 18, 1, 3.50, 3.50, '2025-10-12 19:14:00'),
(113, 14, 17, 1, 3.00, 3.00, '2025-10-12 19:14:00'),
(114, 14, 28, 1, 14.00, 14.00, '2025-10-12 19:14:01'),
(115, 15, 20, 1, 6.00, 6.00, '2025-10-14 21:33:47'),
(116, 15, 19, 1, 5.00, 5.00, '2025-10-14 21:33:47'),
(117, 15, 21, 1, 8.00, 8.00, '2025-10-14 21:33:48'),
(118, 15, 25, 1, 10.00, 10.00, '2025-10-14 21:33:48'),
(119, 16, 17, 1, 3.00, 3.00, '2025-10-14 21:35:06'),
(120, 16, 19, 1, 5.00, 5.00, '2025-10-14 21:35:07'),
(121, 16, 28, 1, 14.00, 14.00, '2025-10-14 21:35:08'),
(122, 16, 20, 1, 6.00, 6.00, '2025-10-14 21:35:08'),
(123, 17, 3, 1, 10.00, 10.00, '2025-10-14 21:57:56'),
(124, 17, 35, 1, 12.00, 12.00, '2025-10-14 21:58:00'),
(125, 17, 27, 1, 12.00, 12.00, '2025-10-14 21:58:02'),
(126, 11, 21, 1, 8.00, 8.00, '2025-10-15 03:56:07'),
(127, 18, 28, 1, 14.00, 14.00, '2025-10-15 03:57:31'),
(128, 18, 25, 1, 10.00, 10.00, '2025-10-15 03:57:32'),
(129, 18, 38, 1, 12.00, 12.00, '2025-10-15 04:06:34'),
(130, 18, 29, 1, 18.00, 18.00, '2025-10-15 04:06:47'),
(131, 18, 11, 1, 15.00, 15.00, '2025-10-15 04:06:51'),
(132, 11, 6, 1, 10.00, 10.00, '2025-10-15 04:15:21'),
(133, 11, 15, 1, 22.00, 22.00, '2025-10-15 04:15:22'),
(134, 19, 21, 1, 8.00, 8.00, '2025-10-15 04:21:42'),
(135, 19, 28, 1, 14.00, 14.00, '2025-10-15 04:21:42'),
(136, 19, 25, 1, 10.00, 10.00, '2025-10-15 04:21:43'),
(137, 20, 19, 1, 5.00, 5.00, '2025-10-15 04:25:33'),
(138, 21, 19, 1, 5.00, 5.00, '2025-10-15 04:25:45'),
(139, 22, 19, 1, 5.00, 5.00, '2025-10-15 04:25:50'),
(149, 36, 28, 1, 14.00, 14.00, '2025-10-15 07:09:49'),
(150, 37, 28, 1, 14.00, 14.00, '2025-10-15 07:12:25'),
(151, 36, 21, 1, 8.00, 8.00, '2025-10-15 07:22:07'),
(152, 35, 20, 1, 6.00, 6.00, '2025-10-15 16:55:18'),
(153, 38, 20, 1, 6.00, 6.00, '2025-10-15 16:55:35'),
(154, 40, 28, 1, 14.00, 14.00, '2025-10-15 16:56:59'),
(155, 39, 17, 1, 3.00, 3.00, '2025-10-15 17:03:20'),
(156, 34, 17, 1, 3.00, 3.00, '2025-10-15 17:04:37'),
(157, 41, 17, 1, 3.00, 3.00, '2025-10-15 21:15:46'),
(158, 41, 28, 1, 14.00, 14.00, '2025-10-15 21:15:46'),
(159, 41, 21, 1, 8.00, 8.00, '2025-10-15 21:15:47'),
(182, 45, 26, 1, 12.00, 12.00, '2025-10-16 10:51:00'),
(183, 45, 25, 1, 10.00, 10.00, '2025-10-16 10:51:04'),
(184, 45, 24, 1, 10.00, 10.00, '2025-10-16 10:51:04'),
(185, 45, 24, 1, 10.00, 10.00, '2025-10-16 10:51:04'),
(186, 44, 21, 1, 8.00, 8.00, '2025-10-19 23:04:42'),
(187, 44, 21, 1, 8.00, 8.00, '2025-10-20 14:57:43'),
(188, 44, 19, 1, 5.00, 5.00, '2025-10-20 14:57:44'),
(189, 43, 17, 1, 3.00, 3.00, '2025-10-20 15:07:57'),
(190, 43, 28, 1, 14.00, 14.00, '2025-10-20 15:07:58'),
(191, 43, 19, 1, 5.00, 5.00, '2025-10-20 15:08:07'),
(192, 42, 17, 1, 3.00, 3.00, '2025-10-21 13:39:58'),
(193, 42, 28, 1, 14.00, 14.00, '2025-10-21 13:40:00'),
(194, 42, 21, 1, 8.00, 8.00, '2025-10-21 14:08:18'),
(195, 42, 28, 1, 14.00, 14.00, '2025-10-21 14:08:18');

--
-- Acionadores `itens_comanda`
--
DELIMITER $$
CREATE TRIGGER `after_insert_itens_comanda` AFTER INSERT ON `itens_comanda` FOR EACH ROW BEGIN
    UPDATE produtos 
    SET estoque_atual = estoque_atual - NEW.quantidade,
        updated_at = NOW()
    WHERE id = NEW.produto_id;
END
$$
DELIMITER ;
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
(1, 9, 'entrada', 54, '2025-09-28 20:39:22', '', NULL, '2025-09-28 20:39:22'),
(2, 28, 'entrada', 11, '2025-10-15 22:35:47', '', NULL, '2025-10-15 22:35:47'),
(3, 18, 'entrada', 20, '2025-10-21 14:25:24', '', NULL, '2025-10-21 14:25:24'),
(4, 40, 'entrada', 10, '2025-10-21 15:34:16', 'Estoque inicial', NULL, '2025-10-21 15:34:16'),
(5, 17, 'entrada', 10, '2025-10-21 15:59:44', '', NULL, '2025-10-21 15:59:44'),
(6, 41, 'entrada', 10, '2025-10-21 16:00:09', 'Estoque inicial', NULL, '2025-10-21 16:00:09');

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
(1, 'Frango com Bacon', 1, 10.00, 47, 10, NULL, 0, '2025-09-24 19:00:52', '2025-10-21 16:01:45'),
(2, 'espetos variados', 1, 10.00, 48, 10, NULL, 1, '2025-09-24 19:00:52', '2025-10-21 16:01:25'),
(3, 'Contra Filé', 1, 10.00, 43, 10, NULL, 0, '2025-09-24 19:00:52', '2025-10-21 16:01:33'),
(4, 'Linguiça de porco', 1, 10.00, 43, 10, NULL, 0, '2025-09-24 19:00:52', '2025-10-21 16:01:50'),
(5, 'Provolone', 1, 10.00, 43, 10, NULL, 0, '2025-09-24 19:00:52', '2025-10-21 16:01:55'),
(6, 'Coração', 1, 10.00, 49, 10, NULL, 0, '2025-09-24 19:00:52', '2025-10-21 16:01:39'),
(7, 'Macarrão M', 2, 10.00, 30, 5, NULL, 0, '2025-09-24 19:00:52', '2025-10-21 16:03:53'),
(8, 'Mandioca M', 2, 10.00, 30, 5, NULL, 0, '2025-09-24 19:00:52', '2025-10-21 16:03:59'),
(9, 'Arroz/Mandioca/Macarrão M', 2, 10.00, 29, 5, NULL, 1, '2025-09-24 19:00:52', '2025-10-21 16:03:40'),
(10, 'Salada M', 2, 12.00, 30, 5, NULL, 1, '2025-09-24 19:00:52', '2025-09-24 19:00:52'),
(11, 'Feijão Tropeiro M', 2, 15.00, 29, 5, NULL, 1, '2025-09-24 19:00:52', '2025-10-15 04:06:51'),
(12, 'Macarrão G', 2, 20.00, 30, 5, NULL, 0, '2025-09-24 19:00:52', '2025-10-21 16:02:57'),
(13, 'Mandioca G', 2, 20.00, 26, 5, NULL, 0, '2025-09-24 19:00:52', '2025-10-21 16:03:10'),
(14, 'Arroz/Mandioca/Macarrão G', 2, 20.00, 30, 5, NULL, 1, '2025-09-24 19:00:52', '2025-10-21 16:02:46'),
(15, 'Salada G', 2, 22.00, 29, 5, NULL, 1, '2025-09-24 19:00:52', '2025-10-15 04:15:22'),
(16, 'Feijão Tropeiro G', 2, 25.00, 30, 5, NULL, 1, '2025-09-24 19:00:52', '2025-09-24 19:00:52'),
(17, 'Água Sem Gás', 3, 3.00, 100, 20, NULL, 1, '2025-09-24 19:00:52', '2025-10-21 15:59:44'),
(18, 'Água Com Gás', 3, 3.50, 119, 20, NULL, 1, '2025-09-24 19:00:52', '2025-10-21 14:25:24'),
(19, 'Coca-Cola KS', 3, 5.00, 91, 20, NULL, 1, '2025-09-24 19:00:52', '2025-10-20 15:08:07'),
(20, 'Diversas latas 350ml', 3, 6.00, 83, 20, NULL, 1, '2025-09-24 19:00:52', '2025-10-15 16:55:35'),
(21, 'Coca-Cola 600ml', 3, 8.00, 91, 20, NULL, 1, '2025-09-24 19:00:52', '2025-10-21 14:08:18'),
(22, 'H2OH', 3, 8.00, 100, 20, NULL, 1, '2025-09-24 19:00:52', '2025-09-24 19:00:52'),
(23, 'Mineiro', 3, 8.00, 99, 20, NULL, 1, '2025-09-24 19:00:52', '2025-09-24 19:00:53'),
(24, 'Energéticos', 3, 10.00, 94, 20, NULL, 1, '2025-09-24 19:00:52', '2025-10-16 10:51:04'),
(25, 'Garrafas 1L', 3, 10.00, 96, 20, NULL, 1, '2025-09-24 19:00:52', '2025-10-16 10:51:04'),
(26, 'Garrafas 2L (exceto Coca)', 3, 12.00, 98, 20, NULL, 1, '2025-09-24 19:00:52', '2025-10-16 10:51:00'),
(27, 'H2OH 1,5L', 3, 12.00, 98, 20, NULL, 1, '2025-09-24 19:00:52', '2025-10-15 06:36:21'),
(28, 'Coca-Cola 2L', 3, 14.00, 96, 20, NULL, 1, '2025-09-24 19:00:52', '2025-10-21 14:08:18'),
(29, 'Sucos Life 900ml', 3, 18.00, 99, 20, NULL, 1, '2025-09-24 19:00:52', '2025-10-15 04:06:47'),
(30, 'Barrigudinhas', 4, 4.00, 94, 20, NULL, 1, '2025-09-24 19:00:52', '2025-10-15 06:37:01'),
(31, 'Latas e Beat\'s', 4, 6.00, 100, 20, NULL, 1, '2025-09-24 19:00:52', '2025-09-24 19:00:52'),
(32, 'Skol/Antarctica 600ml', 4, 10.00, 90, 20, NULL, 1, '2025-09-24 19:00:52', '2025-09-26 05:14:26'),
(33, 'Long Necks', 4, 10.00, 96, 20, NULL, 1, '2025-09-24 19:00:52', '2025-09-30 12:52:41'),
(34, 'Chopp', 4, 10.00, 99, 20, NULL, 1, '2025-09-24 19:00:52', '2025-09-26 05:20:07'),
(35, 'Original', 4, 12.00, 95, 20, NULL, 1, '2025-09-24 19:00:52', '2025-10-14 21:58:00'),
(36, 'Spaten', 4, 12.00, 100, 20, NULL, 1, '2025-09-24 19:00:52', '2025-09-24 19:00:52'),
(37, 'Budweiser', 4, 12.00, 95, 20, NULL, 1, '2025-09-24 19:00:52', '2025-09-30 12:52:40'),
(38, 'Amstel 600ml', 4, 12.00, 99, 20, NULL, 1, '2025-09-24 19:00:52', '2025-10-15 04:06:34'),
(39, 'Heineken 600ml', 4, 15.00, 100, 20, NULL, 1, '2025-09-24 19:00:52', '2025-09-24 19:00:52'),
(40, 'teste', 3, 10.00, 10, 10, NULL, 0, '2025-10-21 15:34:16', '2025-10-21 15:41:08'),
(41, 'teste', 4, 10.00, 10, 1, NULL, 0, '2025-10-21 16:00:09', '2025-10-21 16:02:02');

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
(1, 'Administrador', 'admin@sistema.com', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', 'admin', 1, '2025-09-24 19:00:52', '2025-09-24 19:00:52'),
(2, 'Caixa 01', 'caixa01@restaurante.com', '59c7c57e6516f4a4ae85214acbd322b724cb755806c4183587a5007c9ca3af23', 'caixa', 1, '2025-09-24 19:00:52', '2025-09-24 19:00:52');

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
-- Estrutura para view `view_dashboard`
--
DROP TABLE IF EXISTS `view_dashboard`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_dashboard`  AS SELECT (select count(0) from `comandas` where cast(`comandas`.`data_venda` as date) = curdate() and `comandas`.`status` = 'fechada') AS `vendas_hoje`, (select coalesce(sum(`comandas`.`valor_total`),0) from `comandas` where cast(`comandas`.`data_venda` as date) = curdate() and `comandas`.`status` = 'fechada') AS `faturamento_hoje`, (select count(0) from `produtos` where `produtos`.`estoque_atual` <= `produtos`.`estoque_minimo` and `produtos`.`ativo` = 1) AS `alertas_estoque`, (select coalesce(avg(`comandas`.`valor_total`),0) from `comandas` where cast(`comandas`.`data_venda` as date) = curdate() and `comandas`.`status` = 'fechada') AS `ticket_medio` ;

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
-- Estrutura para view `view_vendas_periodo`
--
DROP TABLE IF EXISTS `view_vendas_periodo`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_vendas_periodo`  AS SELECT cast(`comandas`.`data_venda` as date) AS `data_venda`, count(`comandas`.`id`) AS `total_comandas`, sum(`comandas`.`valor_total`) AS `valor_total_vendas`, sum(`comandas`.`taxa_gorjeta`) AS `total_gorjetas`, avg(`comandas`.`valor_total`) AS `ticket_medio` FROM `comandas` WHERE `comandas`.`status` = 'fechada' GROUP BY cast(`comandas`.`data_venda` as date) ;

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
  ADD KEY `idx_comandas_data_status` (`data_venda`,`status`);

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
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=46;

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
-- AUTO_INCREMENT de tabela `itens_comanda`
--
ALTER TABLE `itens_comanda`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=196;

--
-- AUTO_INCREMENT de tabela `itens_livres`
--
ALTER TABLE `itens_livres`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de tabela `movimentacoes_estoque`
--
ALTER TABLE `movimentacoes_estoque`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT de tabela `produtos`
--
ALTER TABLE `produtos`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=42;

--
-- AUTO_INCREMENT de tabela `usuarios`
--
ALTER TABLE `usuarios`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- Restrições para tabelas despejadas
--

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
