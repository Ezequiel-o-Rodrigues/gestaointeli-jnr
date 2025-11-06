<?php
// finalizar_comanda.php - VERSÃO SIMPLIFICADA
session_start();
header('Content-Type: application/json');

// Caminhos relativos simples - todos os arquivos API estão na mesma pasta
require_once '../config/database.php';
require_once '../includes/functions.php';

try {
    // Ler dados do POST
    $input = json_decode(file_get_contents('php://input'), true);
    $comanda_id = $input['comanda_id'] ?? null;

    if (!$comanda_id) {
        throw new Exception('Comanda não informada');
    }

    $database = new Database();
    $db = $database->getConnection();

    // 1. Buscar itens da comanda
    $query_itens = "SELECT ci.produto_id, ci.quantidade, p.estoque_atual, p.nome 
                   FROM itens_comanda ci 
                   JOIN produtos p ON ci.produto_id = p.id 
                   WHERE ci.comanda_id = ?";
    $stmt_itens = $db->prepare($query_itens);
    $stmt_itens->execute([$comanda_id]);
    $itens = $stmt_itens->fetchAll(PDO::FETCH_ASSOC);

    if (empty($itens)) {
        throw new Exception('Comanda vazia');
    }

    // 2. Verificar estoque
    foreach ($itens as $item) {
        if ($item['estoque_atual'] < $item['quantidade']) {
            throw new Exception('Estoque insuficiente: ' . $item['nome'] . 
                              ' (Disponível: ' . $item['estoque_atual'] . ')');
        }
    }

    // 3. Baixar estoque (APENAS AQUI - NA FINALIZAÇÃO)
    foreach ($itens as $item) {
        // Baixar estoque
        $query_baixa = "UPDATE produtos SET estoque_atual = estoque_atual - ? WHERE id = ?";
        $stmt_baixa = $db->prepare($query_baixa);
        $stmt_baixa->execute([$item['quantidade'], $item['produto_id']]);

        // Registrar movimentação (opcional)
        $query_mov = "INSERT INTO movimentacoes_estoque 
                     (produto_id, tipo, quantidade, observacao) 
                     VALUES (?, 'saida', ?, 'Venda comanda #$comanda_id')";
        $stmt_mov = $db->prepare($query_mov);
        $stmt_mov->execute([$item['produto_id'], $item['quantidade']]);
    }

    // 4. Finalizar comanda
    $query_finalizar = "UPDATE comandas SET status = 'finalizada', data_finalizacao = NOW() WHERE id = ?";
    $stmt_finalizar = $db->prepare($query_finalizar);
    $stmt_finalizar->execute([$comanda_id]);

    echo json_encode([
        'success' => true,
        'message' => 'Comanda finalizada com sucesso!',
        'comanda_id' => $comanda_id
    ]);

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>