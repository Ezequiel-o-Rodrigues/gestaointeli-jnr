<?php
require_once '../config/database.php';
require_once '../includes/functions.php';

header('Content-Type: application/json');

$database = new Database();
$db = $database->getConnection();

try {
    // Verificar se a view existe, senão usar query direta
    $query_check = "SHOW TABLES LIKE 'view_alertas_perda_estoque'";
    $stmt_check = $db->prepare($query_check);
    $stmt_check->execute();
    
    if ($stmt_check->rowCount() > 0) {
        $query = "SELECT * FROM view_alertas_perda_estoque WHERE diferenca_estoque > 0 ORDER BY diferenca_estoque DESC";
    } else {
        // Query alternativa caso a view não exista
        $query = "SELECT 
                    p.id,
                    p.nome,
                    cat.nome as categoria,
                    p.estoque_atual,
                    p.estoque_minimo,
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
    }
    
    $stmt = $db->prepare($query);
    $stmt->execute();
    $alertas = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode([
        'success' => true,
        'data' => $alertas,
        'total_alertas' => count($alertas)
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