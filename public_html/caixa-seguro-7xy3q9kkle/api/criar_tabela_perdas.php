<?php
require_once __DIR__ . '/../config/database.php';

header('Content-Type: application/json');

try {
    $database = new Database();
    $db = $database->getConnection();
    
    // Criar tabela de perdas_estoque se não existir
    $sql = "
        CREATE TABLE IF NOT EXISTS perdas_estoque (
            id INT AUTO_INCREMENT PRIMARY KEY,
            produto_id INT NOT NULL,
            quantidade_perdida INT NOT NULL,
            valor_perda DECIMAL(10,2) NOT NULL DEFAULT 0.00,
            motivo VARCHAR(255) DEFAULT 'Diferença de inventário',
            data_identificacao DATETIME DEFAULT CURRENT_TIMESTAMP,
            visualizada TINYINT(1) DEFAULT 0,
            data_visualizacao DATETIME NULL,
            observacoes TEXT NULL,
            FOREIGN KEY (produto_id) REFERENCES produtos(id) ON DELETE CASCADE
        )
    ";
    
    $db->exec($sql);
    
    echo json_encode([
        'success' => true, 
        'message' => 'Tabela perdas_estoque criada/verificada com sucesso'
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false, 
        'message' => 'Erro ao criar tabela: ' . $e->getMessage()
    ]);
}
?>