<?php
/**
 * Diagnóstico: Teste de Funcionamento do Sistema de Alertas de Perdas
 * Arquivo: teste_alertas_perdas.php
 */

require_once '../config/database.php';

header('Content-Type: application/json');

try {
    $database = new Database();
    $db = $database->getConnection();
    
    $diagnostico = [
        'timestamp' => date('Y-m-d H:i:s'),
        'status' => 'OK',
        'verificacoes' => []
    ];
    
    // 1. Verificar tabela perdas_estoque
    $check_tabela = $db->query("SHOW TABLES LIKE 'perdas_estoque'");
    $diagnostico['verificacoes']['tabela_perdas_estoque'] = $check_tabela->rowCount() > 0 ? 'EXISTS' : 'MISSING';
    
    // 2. Verificar stored procedure
    $check_procedure = $db->query("SHOW PROCEDURE STATUS WHERE Name = 'relatorio_perdas_periodo_correto'");
    $diagnostico['verificacoes']['procedure_relatorio'] = $check_procedure->rowCount() > 0 ? 'EXISTS' : 'MISSING';
    
    // 3. Contar registros em perdas_estoque
    $count_perdas = $db->query("SELECT COUNT(*) as total FROM perdas_estoque")->fetch(PDO::FETCH_ASSOC);
    $diagnostico['verificacoes']['registros_perdas_estoque'] = (int)$count_perdas['total'];
    
    // 4. Contar perdas não visualizadas
    $count_nao_visualizadas = $db->query("SELECT COUNT(*) as total FROM perdas_estoque WHERE visualizada = 0")->fetch(PDO::FETCH_ASSOC);
    $diagnostico['verificacoes']['perdas_nao_visualizadas'] = (int)$count_nao_visualizadas['total'];
    
    // 5. Listar funções
    $functions = $db->query("SHOW FUNCTION STATUS WHERE Db = (SELECT DATABASE())")->fetchAll(PDO::FETCH_COLUMN, 1);
    $diagnostico['verificacoes']['funcoes_sql'] = $functions;
    
    // 6. Listar procedures
    $procedures = $db->query("SHOW PROCEDURE STATUS WHERE Db = (SELECT DATABASE())")->fetchAll(PDO::FETCH_COLUMN, 1);
    $diagnostico['verificacoes']['procedures_sql'] = $procedures;
    
    // 7. Amostra de últimas perdas registradas
    $sample_perdas = $db->query("
        SELECT pe.id, pe.produto_id, p.nome, pe.quantidade_perdida, pe.valor_perda, pe.visualizada, pe.data_identificacao
        FROM perdas_estoque pe
        LEFT JOIN produtos p ON pe.produto_id = p.id
        ORDER BY pe.data_identificacao DESC
        LIMIT 5
    ")->fetchAll(PDO::FETCH_ASSOC);
    $diagnostico['verificacoes']['amostra_perdas'] = $sample_perdas;
    
    echo json_encode($diagnostico, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'trace' => $e->getTraceAsString()
    ]);
}
?>
