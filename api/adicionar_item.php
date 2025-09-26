<?php
require_once '../config/database.php';

header('Content-Type: application/json');

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
    
    echo json_encode([
        'success' => true,
        'message' => 'Item adicionado com sucesso',
        'item_id' => $db->lastInsertId()
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Erro: ' . $e->getMessage()
    ]);
}
?>