<?php
require_once '../config/database.php';
require_once '../includes/functions.php';

header('Content-Type: application/json');

$database = new Database();
$db = $database->getConnection();

try {
    // Criar tabela de perdas se não existir
    $db->exec("
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
    ");
    
    // Query para detectar perdas não visualizadas
    $query = "SELECT 
                p.id as produto_id,
                p.nome,
                cat.nome as categoria,
                p.estoque_atual,
                p.estoque_minimo,
                p.preco,
                (SELECT COALESCE(SUM(quantidade), 0) 
                 FROM movimentacoes_estoque me 
                 WHERE me.produto_id = p.id AND me.tipo = 'entrada') as total_entradas,
                (SELECT COALESCE(SUM(ic.quantidade), 0) 
                 FROM itens_comanda ic 
                 JOIN comandas c ON ic.comanda_id = c.id 
                 WHERE ic.produto_id = p.id AND c.status = 'fechada') as total_vendido,
                ((SELECT COALESCE(SUM(quantidade), 0) FROM movimentacoes_estoque WHERE produto_id = p.id AND tipo = 'entrada') - 
                 (SELECT COALESCE(SUM(ic.quantidade), 0) FROM itens_comanda ic JOIN comandas c ON ic.comanda_id = c.id WHERE ic.produto_id = p.id AND c.status = 'fechada') - 
                 p.estoque_atual) as diferenca_estoque
              FROM produtos p
              JOIN categorias cat ON p.categoria_id = cat.id
              WHERE p.ativo = 1
              HAVING diferenca_estoque > 0
              ORDER BY diferenca_estoque DESC";
    
    $stmt = $db->prepare($query);
    $stmt->execute();
    $perdas_detectadas = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    $alertas_com_id = [];
    
    // Para cada perda detectada, verificar se já existe na tabela perdas_estoque
    foreach ($perdas_detectadas as $perda) {
        // Verificar se já existe uma perda não visualizada para este produto
        $stmt_check = $db->prepare("
            SELECT id FROM perdas_estoque 
            WHERE produto_id = ? AND visualizada = 0 
            ORDER BY data_identificacao DESC LIMIT 1
        ");
        $stmt_check->execute([$perda['produto_id']]);
        $perda_existente = $stmt_check->fetch(PDO::FETCH_ASSOC);
        
        if ($perda_existente) {
            // Usar ID da perda existente
            $perda['id'] = $perda_existente['id'];
        } else {
            // Criar nova entrada na tabela perdas_estoque
            $valor_perda = $perda['diferenca_estoque'] * $perda['preco'];
            $stmt_insert = $db->prepare("
                INSERT INTO perdas_estoque (produto_id, quantidade_perdida, valor_perda, motivo) 
                VALUES (?, ?, ?, 'Diferença de inventário detectada automaticamente')
            ");
            $stmt_insert->execute([
                $perda['produto_id'], 
                $perda['diferenca_estoque'], 
                $valor_perda
            ]);
            $perda['id'] = $db->lastInsertId();
        }
        
        $perda['valor_perda'] = $perda['diferenca_estoque'] * $perda['preco'];
        $alertas_com_id[] = $perda;
    }
    
    echo json_encode([
        'success' => true,
        'data' => $alertas_com_id,
        'total_alertas' => count($alertas_com_id)
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Erro ao carregar alertas: ' . $e->getMessage(),
        'data' => [],
        'total_alertas' => 0
    ]);
}
?>