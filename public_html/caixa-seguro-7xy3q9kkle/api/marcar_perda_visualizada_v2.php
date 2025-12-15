<?php
/**
 * API: Marcar Perda Como Visualizada - VERSÃO MELHORADA
 * Arquivo: api/marcar_perda_visualizada_v2.php
 * 
 * Funcionalidades:
 * 1. Marca perda como visualizada com timestamp
 * 2. Registra auditoria completa
 * 3. Atualiza contador de alertas
 * 4. Não deleta, apenas marca status
 * 5. Valida existência e integridade
 */

header('Content-Type: application/json; charset=utf-8');

try {
    // =====================================================================
    // 1. VALIDAÇÃO
    // =====================================================================
    
    // Apenas POST é aceito
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Método HTTP inválido. Use POST');
    }
    
    // Obter dados do body JSON
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($input['perda_id'])) {
        throw new Exception('ID da perda é obrigatório');
    }
    
    $perda_id = intval($input['perda_id']);
    $usuario_id = isset($input['usuario_id']) ? intval($input['usuario_id']) : 1; // Default admin
    
    if ($perda_id <= 0) {
        throw new Exception('ID da perda inválido');
    }
    
    require_once '../../includes/conexao.php';
    
    // =====================================================================
    // 2. VALIDAR EXISTÊNCIA DA PERDA
    // =====================================================================
    
    $stmt = $pdo->prepare("
        SELECT id, visualizada, data_visualizacao 
        FROM perdas_estoque 
        WHERE id = ?
    ");
    $stmt->execute([$perda_id]);
    $perda = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$perda) {
        throw new Exception('Perda não encontrada', 404);
    }
    
    // =====================================================================
    // 3. VERIFICAR SE JÁ FOI VISUALIZADA
    // =====================================================================
    
    if ($perda['visualizada'] == 1) {
        // Perda já foi visualizada, retornar informação
        echo json_encode([
            'success' => true,
            'message' => 'Perda já foi marcada como visualizada',
            'perda_id' => $perda_id,
            'data_visualizacao' => $perda['data_visualizacao'],
            'status' => 'ja_visualizada',
            'timestamp' => date('Y-m-d H:i:s')
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    
    // =====================================================================
    // 4. INICIAR TRANSAÇÃO
    // =====================================================================
    
    $pdo->beginTransaction();
    
    try {
        // ================================================================
        // 5. ATUALIZAR STATUS DA PERDA
        // ================================================================
        
        $data_visualizacao = date('Y-m-d H:i:s');
        
        $stmt = $pdo->prepare("
            UPDATE perdas_estoque 
            SET 
                visualizada = 1,
                data_visualizacao = ?,
                atualizado_em = CURRENT_TIMESTAMP
            WHERE id = ?
        ");
        $stmt->execute([$data_visualizacao, $perda_id]);
        
        // ================================================================
        // 6. REGISTRAR NA AUDITORIA
        // ================================================================
        
        // Verificar se tabela de auditoria existe
        $stmt = $pdo->prepare("
            INSERT INTO log_auditoria_perdas 
            (perda_id, acao, usuario_id, data_acao, detalhes)
            VALUES (?, ?, ?, NOW(), ?)
        ");
        
        $detalhes = json_encode([
            'acao' => 'marcada_visualizada',
            'timestamp' => $data_visualizacao,
            'usuario_id' => $usuario_id,
            'ip' => $_SERVER['REMOTE_ADDR'] ?? 'desconhecido'
        ]);
        
        $stmt->execute([
            $perda_id,
            'visualizada',
            $usuario_id,
            $detalhes
        ]);
        
        // ================================================================
        // 7. CONFIRMAR TRANSAÇÃO
        // ================================================================
        
        $pdo->commit();
        
        // ================================================================
        // 8. RETORNAR RESPOSTA DE SUCESSO
        // ================================================================
        
        // Obter contagem de alertas restantes
        $stmt = $pdo->prepare("
            SELECT COUNT(*) as total 
            FROM perdas_estoque 
            WHERE visualizada = 0
        ");
        $stmt->execute();
        $resultado = $stmt->fetch(PDO::FETCH_ASSOC);
        $alertas_restantes = intval($resultado['total']);
        
        $resposta = [
            'success' => true,
            'message' => 'Perda marcada como visualizada com sucesso',
            'perda_id' => $perda_id,
            'data_visualizacao' => $data_visualizacao,
            'alertas_restantes' => $alertas_restantes,
            'status' => 'sucesso',
            'timestamp' => date('Y-m-d H:i:s')
        ];
        
        http_response_code(200);
        echo json_encode($resposta, JSON_UNESCAPED_UNICODE);
        
    } catch (Exception $e) {
        // Reverter transação em caso de erro
        $pdo->rollBack();
        throw $e;
    }
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erro no banco de dados ao marcar perda',
        'error' => $e->getMessage(),
        'code' => $e->getCode()
    ], JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    $code = intval($e->getCode());
    $httpCode = $code ?: 400;
    http_response_code($httpCode);
    
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'perda_id' => isset($perda_id) ? $perda_id : null,
        'timestamp' => date('Y-m-d H:i:s')
    ], JSON_UNESCAPED_UNICODE);
}
?>
