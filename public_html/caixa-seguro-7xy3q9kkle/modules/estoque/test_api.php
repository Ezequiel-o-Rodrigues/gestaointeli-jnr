<?php
// Teste simples de API
header('Content-Type: application/json');

$produto_id = $_GET['id'] ?? null;

if (!$produto_id) {
    echo json_encode(['success' => false, 'message' => 'ID não informado']);
    exit;
}

// Simular dados do produto
echo json_encode([
    'success' => true,
    'produto' => [
        'id' => $produto_id,
        'nome' => 'Produto Teste',
        'estoque_atual' => 10
    ]
]);
?>