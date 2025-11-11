<?php
header('Content-Type: application/json');
require_once '../config/database.php';

$data = json_decode(file_get_contents('php://input'), true);

try {
    $comanda_id = $data['comanda_id'] ?? null;
    
    if (!$comanda_id) {
        throw new Exception('Comanda ID não informado');
    }
    
    // Verificar estoque para todos os itens da comanda
    $stmt = $pdo->prepare("
        SELECT 
            p.id,
            p.nome,
            p.estoque_atual,
            ic.quantidade as quantidade_solicitada,
            (p.estoque_atual - ic.quantidade) as estoque_apos
        FROM itens_comanda ic
        JOIN produtos p ON ic.produto_id = p.id
        WHERE ic.comanda_id = ?
    ");
    $stmt->execute([$comanda_id]);
    $itens = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    $problemas = [];
    foreach ($itens as $item) {
        if ($item['estoque_apos'] < 0) {
            $problemas[] = [
                'produto' => $item['nome'],
                'estoque_atual' => $item['estoque_atual'],
                'quantidade_solicitada' => $item['quantidade_solicitada'],
                'deficit' => abs($item['estoque_apos'])
            ];
        }
    }
    
    echo json_encode([
        'success' => true,
        'estoque_suficiente' => empty($problemas),
        'problemas' => $problemas,
        'itens_verificados' => count($itens)
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>