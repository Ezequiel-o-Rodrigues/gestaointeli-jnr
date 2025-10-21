<?php
// ✅ CORRIGIDO
require_once __DIR__ . '/../config/paths.php';
require_once PathConfig::config('database.php'); 
header('Content-Type: application/json; charset=utf-8');

$data = json_decode(file_get_contents('php://input'), true);

try {
    $database = new Database();
    $db = $database->getConnection();
    
    // Primeiro buscar o preço do produto
    $query_preco = "SELECT preco FROM produtos WHERE id = ?";
    $stmt_preco = $db->prepare($query_preco);
    $stmt_preco->execute([$data['produto_id']]);
    $produto = $stmt_preco->fetch(PDO::FETCH_ASSOC);
    
    if (!$produto) {
        throw new Exception('Produto não encontrado');
    }
    
    $preco_unitario = $produto['preco'];
    $subtotal = $preco_unitario * $data['quantidade'];
    
    // Inserir item na comanda
    $query = "INSERT INTO itens_comanda (comanda_id, produto_id, quantidade, preco_unitario, subtotal) 
              VALUES (?, ?, ?, ?, ?)";
    $stmt = $db->prepare($query);
    $stmt->execute([
        $data['comanda_id'],
        $data['produto_id'],
        $data['quantidade'],
        $preco_unitario,
        $subtotal
    ]);
    
    // ATUALIZAR TOTAL DA COMANDA
    $query_update = "UPDATE comandas SET valor_total = valor_total + ? WHERE id = ?";
    $stmt_update = $db->prepare($query_update);
    $stmt_update->execute([$subtotal, $data['comanda_id']]);
    
    echo json_encode([
        'success' => true,
        'message' => 'Item adicionado com sucesso',
        'item_id' => $db->lastInsertId()
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erro: ' . $e->getMessage()
    ]);
}
?>