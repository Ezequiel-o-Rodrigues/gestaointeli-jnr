<?php
/**
 * API: Relatório de Alertas de Perda - VERSÃO CORRIGIDA
 * Arquivo: api/relatorio_alertas_perda_corrigido.php
 * 
 * LÓGICA CORRIGIDA:
 * - Considera TODAS as movimentações de estoque
 * - Evita duplicação de contabilizações
 * - Diferencia entre vendas, perdas identificadas e ajustes
 * - Somente alerta para perdas NÃO IDENTIFICADAS (diferença > 0)
 * 
 * @author Sistema de Gestão
 * @date 2025-12-11
 */

require_once '../config/database.php';
require_once '../includes/functions.php';

header('Content-Type: application/json');

try {
    // =========================================================================
    // 1. VALIDAÇÃO E PREPARAÇÃO
    // =========================================================================
    
    $database = new Database();
    $db = $database->getConnection();
    
    // Garantir que tabelas de suporte existem
    criar_tabelas_suporte($db);
    
    // =========================================================================
    // 2. BUSCAR TODOS OS PRODUTOS ATIVOS
    // =========================================================================
    
    $query_produtos = "
        SELECT 
            p.id,
            p.nome,
            p.preco,
            p.estoque_atual,
            cat.nome as categoria_nome
        FROM produtos p
        INNER JOIN categorias cat ON p.categoria_id = cat.id
        WHERE p.ativo = 1
        ORDER BY p.nome
    ";
    
    $stmt_produtos = $db->prepare($query_produtos);
    $stmt_produtos->execute();
    $produtos = $stmt_produtos->fetchAll(PDO::FETCH_ASSOC);
    
    // =========================================================================
    // 3. PROCESSAR CADA PRODUTO PARA DETECTAR PERDAS
    // =========================================================================
    
    $alertas = [];
    $data_hoje = date('Y-m-d');
    $log_processamento = [];
    
    foreach ($produtos as $produto) {
        $produto_id = $produto['id'];
        
        // ─────────────────────────────────────────────────────────────────
        // 3.1 Calcular estoque teórico (TODAS as movimentações)
        // ─────────────────────────────────────────────────────────────────
        
        $query_estoque_teorico = "
            SELECT COALESCE(SUM(
                CASE 
                    WHEN tipo = 'entrada' THEN quantidade
                    WHEN tipo = 'saida' THEN -quantidade
                    ELSE 0
                END
            ), 0) as estoque_teorico
            FROM movimentacoes_estoque
            WHERE produto_id = :produto_id
        ";
        
        $stmt_teorico = $db->prepare($query_estoque_teorico);
        $stmt_teorico->execute([':produto_id' => $produto_id]);
        $result_teorico = $stmt_teorico->fetch(PDO::FETCH_ASSOC);
        $estoque_teorico = intval($result_teorico['estoque_teorico'] ?? 0);
        
        // ─────────────────────────────────────────────────────────────────
        // 3.2 Obter estoque real atual
        // ─────────────────────────────────────────────────────────────────
        
        $estoque_real = intval($produto['estoque_atual']);
        
        // ─────────────────────────────────────────────────────────────────
        // 3.3 CALCULAR DIFERENÇA (perdas)
        // ─────────────────────────────────────────────────────────────────
        
        $diferenca = $estoque_teorico - $estoque_real;
        
        // ─────────────────────────────────────────────────────────────────
        // 3.4 APENAS ALERTAR SE DIFERENÇA FOR POSITIVA (perda real)
        // ─────────────────────────────────────────────────────────────────
        
        if ($diferenca > 0) {
            
            // ───────────────────────────────────────────────────────────
            // 3.5 Verificar se já existe alerta NÃO VISUALIZADO de hoje
            // ───────────────────────────────────────────────────────────
            
            $query_verificar = "
                SELECT id, visualizada
                FROM perdas_estoque
                WHERE produto_id = :produto_id
                AND visualizada = 0
                AND DATE(data_identificacao) = :data_hoje
                ORDER BY data_identificacao DESC
                LIMIT 1
            ";
            
            $stmt_verificar = $db->prepare($query_verificar);
            $stmt_verificar->execute([
                ':produto_id' => $produto_id,
                ':data_hoje' => $data_hoje
            ]);
            
            $perda_existente = $stmt_verificar->fetch(PDO::FETCH_ASSOC);
            
            // ───────────────────────────────────────────────────────────
            // 3.6 Se NÃO existe alerta de hoje, criar novo
            // ───────────────────────────────────────────────────────────
            
            if (!$perda_existente) {
                
                $valor_perda = $diferenca * floatval($produto['preco']);
                
                // Inserir nova perda em perdas_estoque
                $query_insert = "
                    INSERT INTO perdas_estoque (
                        produto_id,
                        quantidade_perdida,
                        valor_perda,
                        estoque_esperado,
                        estoque_real,
                        motivo,
                        data_identificacao,
                        visualizada
                    ) VALUES (
                        :produto_id,
                        :quantidade_perdida,
                        :valor_perda,
                        :estoque_esperado,
                        :estoque_real,
                        :motivo,
                        NOW(),
                        0
                    )
                ";
                
                $stmt_insert = $db->prepare($query_insert);
                $stmt_insert->execute([
                    ':produto_id' => $produto_id,
                    ':quantidade_perdida' => $diferenca,
                    ':valor_perda' => $valor_perda,
                    ':estoque_esperado' => $estoque_teorico,
                    ':estoque_real' => $estoque_real,
                    ':motivo' => 'Diferença de inventário não identificada'
                ]);
                
                $perda_id = $db->lastInsertId();
                
                // Adicionar ao array de alertas
                $alertas[] = [
                    'id' => $perda_id,
                    'produto_id' => $produto_id,
                    'produto_nome' => $produto['nome'],
                    'categoria_nome' => $produto['categoria_nome'],
                    'quantidade_perdida' => $diferenca,
                    'valor_perda' => round($valor_perda, 2),
                    'estoque_esperado' => $estoque_teorico,
                    'estoque_real' => $estoque_real,
                    'preco_unitario' => floatval($produto['preco']),
                    'data_identificacao' => date('Y-m-d H:i:s'),
                    'status' => 'novo_alerta'
                ];
                
                $log_processamento[] = [
                    'produto_id' => $produto_id,
                    'acao' => 'novo_alerta',
                    'diferenca' => $diferenca,
                    'valor' => $valor_perda
                ];
                
            } else {
                
                // Se já existe alerta não visualizado, apenas retornar na lista
                $valor_perda = $diferenca * floatval($produto['preco']);
                
                $alertas[] = [
                    'id' => $perda_existente['id'],
                    'produto_id' => $produto_id,
                    'produto_nome' => $produto['nome'],
                    'categoria_nome' => $produto['categoria_nome'],
                    'quantidade_perdida' => $diferenca,
                    'valor_perda' => round($valor_perda, 2),
                    'estoque_esperado' => $estoque_teorico,
                    'estoque_real' => $estoque_real,
                    'preco_unitario' => floatval($produto['preco']),
                    'data_identificacao' => null,
                    'status' => 'alerta_existente'
                ];
                
                $log_processamento[] = [
                    'produto_id' => $produto_id,
                    'acao' => 'alerta_existente',
                    'diferenca' => $diferenca,
                    'valor' => $valor_perda
                ];
            }
        }
    }
    
    // =========================================================================
    // 4. CALCULAR TOTALIZADORES
    // =========================================================================
    
    $total_alertas = count($alertas);
    $total_quantidade_perdida = array_sum(array_column($alertas, 'quantidade_perdida'));
    $total_valor_perdido = array_sum(array_column($alertas, 'valor_perda'));
    
    // =========================================================================
    // 5. RETORNAR RESPOSTA ESTRUTURADA
    // =========================================================================
    
    echo json_encode([
        'success' => true,
        'data' => $alertas,
        'total_alertas' => $total_alertas,
        'resumo' => [
            'total_quantidade_perdida' => intval($total_quantidade_perdida),
            'total_valor_perdido' => round($total_valor_perdido, 2),
            'quantidade_produtos_processados' => count($produtos),
            'quantidade_produtos_com_perda' => count($alertas),
            'taxa_produtos_afetados' => round((count($alertas) / count($produtos)) * 100, 2) . '%'
        ],
        'timestamp' => date('Y-m-d H:i:s'),
        'versao_api' => '2.0 - Corrigida',
        'log' => [
            'descricao' => 'Detecção automática com lógica corrigida',
            'operacoes' => $log_processamento
        ]
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    
    // =========================================================================
    // 6. TRATAMENTO DE ERROS
    // =========================================================================
    
    http_response_code(500);
    
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'file' => $e->getFile(),
        'line' => $e->getLine(),
        'timestamp' => date('Y-m-d H:i:s')
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
    // Registrar erro em log
    error_log("[ALERTA_PERDA] Erro na detecção automática: " . $e->getMessage());
}

// =============================================================================
// FUNÇÕES AUXILIARES
// =============================================================================

/**
 * Garantir que as tabelas de suporte existem
 */
function criar_tabelas_suporte(&$db) {
    
    // Criar tabela tipos_ajuste_estoque
    $sql_tipos = "
        CREATE TABLE IF NOT EXISTS tipos_ajuste_estoque (
            id INT PRIMARY KEY AUTO_INCREMENT,
            nome VARCHAR(50) NOT NULL UNIQUE,
            tipo ENUM('entrada', 'saida') NOT NULL,
            descricao TEXT,
            ativo TINYINT(1) DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ";
    
    try {
        $db->exec($sql_tipos);
    } catch (Exception $e) {
        // Tabela pode já existir, ignorar erro
    }
    
    // Inserir tipos padrão se não existirem
    $tipos_padrao = [
        ['Compra', 'entrada'],
        ['Venda', 'saida'],
        ['Perda Identificada', 'saida'],
        ['Ajuste', 'saida']
    ];
    
    $stmt = $db->prepare("INSERT IGNORE INTO tipos_ajuste_estoque (nome, tipo) VALUES (:nome, :tipo)");
    
    foreach ($tipos_padrao as $tipo) {
        try {
            $stmt->execute([':nome' => $tipo[0], ':tipo' => $tipo[1]]);
        } catch (Exception $e) {
            // Ignorar duplicatas
        }
    }
}

?>
