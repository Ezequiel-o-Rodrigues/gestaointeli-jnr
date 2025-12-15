<?php
/**
 * API: Marcar Perda como Visualizada
 * Arquivo: api/marcar_perda_visualizada.php
 * 
 * Responsabilidades:
 * - Marcar perda como visualizada (visualizada = 1)
 * - Registrar data e hora da visualização
 * - Garantir que não será contabilizada em relatórios futuros
 * - Remover do modal de alertas
 * - Validar se perda existe antes de atualizar
 * 
 * @author Sistema de Gestão
 * @date 2025-12-12
 */

require_once __DIR__ . '/../config/database.php';

header('Content-Type: application/json');

try {
    $database = new Database();
    $db = $database->getConnection();
    
    // Receber dados do POST
    $input = json_decode(file_get_contents('php://input'), true);
    $perda_id = $input['perda_id'] ?? null;
    
    // Validação
    if (!$perda_id) {
        throw new Exception('ID da perda é obrigatório');
    }
    
    // Verificar se a perda existe
    $check_stmt = $db->prepare("
        SELECT id, produto_id, visualizada 
        FROM perdas_estoque 
        WHERE id = ?
    ");
    $check_stmt->execute([$perda_id]);
    $perda = $check_stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$perda) {
        throw new Exception('Perda não encontrada');
    }
    
    // Se já está marcada como visualizada, retornar aviso
    if ($perda['visualizada']) {
        echo json_encode([
            'success' => true,
            'message' => 'Perda já estava marcada como visualizada',
            'already_marked' => true,
            'perda_id' => $perda_id
        ]);
        exit;
    }
    
    // Marcar como visualizada com timestamp
    $stmt = $db->prepare("
        UPDATE perdas_estoque 
        SET visualizada = 1, 
            data_visualizacao = NOW() 
        WHERE id = ?
    ");
    $stmt->execute([$perda_id]);
    
    // Retornar sucesso com informações da perda
    echo json_encode([
        'success' => true,
        'message' => 'Perda marcada como visualizada com sucesso',
        'perda_id' => $perda_id,
        'produto_id' => $perda['produto_id'],
        'data_visualizacao' => date('Y-m-d H:i:s'),
        'timestamp' => date('Y-m-d H:i:s')
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'error_code' => 'MARCAR_PERDA_ERROR',
        'timestamp' => date('Y-m-d H:i:s')
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
}
?>
