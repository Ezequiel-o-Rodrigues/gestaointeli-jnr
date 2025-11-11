<?php
// API: finalizar_comanda.php
// Retorna JSON limpo; usa Database class
ini_set('display_errors', 0);
error_reporting(E_ALL);
header('Content-Type: application/json; charset=utf-8');
require_once __DIR__ . '/../config/database.php';

// Buffer para evitar qualquer saída acidental
if (!ob_get_level()) ob_start();

$data = json_decode(file_get_contents('php://input'), true);

try {
    $comanda_id = $data['comanda_id'] ?? null;

    if (!$comanda_id) {
        throw new Exception('Comanda ID não informado');
    }

    // Conectar ao banco
    $database = new Database();
    $db = $database->getConnection();

    // Rodar transação: calcular total, atualizar comanda, registrar movimentação e baixar estoque
    $db->beginTransaction();

    // Calcular total da comanda (itens_comanda + itens_livres)
    $stmt = $db->prepare("SELECT COALESCE(SUM(subtotal),0) as total FROM (SELECT subtotal FROM itens_comanda WHERE comanda_id = ? UNION ALL SELECT subtotal FROM itens_livres WHERE comanda_id = ?) t");
    $stmt->execute([$comanda_id, $comanda_id]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    $total_comanda = floatval($row['total'] ?? 0);

    // Obter configuração de taxa
    $stmt = $db->prepare("SELECT taxa_gorjeta, tipo_taxa FROM configuracoes ORDER BY id DESC LIMIT 1");
    $stmt->execute();
    $conf = $stmt->fetch(PDO::FETCH_ASSOC);
    $taxa_config = floatval($conf['taxa_gorjeta'] ?? 0);
    $tipo_taxa = $conf['tipo_taxa'] ?? 'nenhuma';

    if ($tipo_taxa === 'percentual' && $taxa_config > 0) {
        $taxa_gorjeta = ($total_comanda * $taxa_config) / 100;
    } elseif ($tipo_taxa === 'fixa' && $taxa_config > 0) {
        $taxa_gorjeta = $taxa_config;
    } else {
        $taxa_gorjeta = 0;
    }

    // Atualizar comanda
    $stmt = $db->prepare("UPDATE comandas SET status = 'fechada', valor_total = ?, taxa_gorjeta = ?, data_venda = NOW() WHERE id = ?");
    $stmt->execute([$total_comanda, $taxa_gorjeta, $comanda_id]);

    // Baixar estoque: para cada item em itens_comanda, inserir movimentacao tipo 'saida' e decrementar estoque
    $stmt = $db->prepare("SELECT ic.produto_id, ic.quantidade FROM itens_comanda ic WHERE ic.comanda_id = ?");
    $stmt->execute([$comanda_id]);
    $itens = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $mov_stmt = $db->prepare("INSERT INTO movimentacoes_estoque (produto_id, tipo, quantidade, observacao, data_movimentacao, created_at) VALUES (?, 'saida', ?, ?, NOW(), NOW())");
    $update_prod = $db->prepare("UPDATE produtos SET estoque_atual = estoque_atual - ?, updated_at = NOW() WHERE id = ?");

    foreach ($itens as $item) {
        $pid = (int)$item['produto_id'];
        $qtd = (int)$item['quantidade'];
        // registrar movimentação
        $mov_stmt->execute([$pid, $qtd, 'Venda - comanda ' . $comanda_id]);
        // decrementar estoque (não bloqueamos negativo aqui)
        $update_prod->execute([$qtd, $pid]);
    }

    $db->commit();

    // Limpar buffer e enviar JSON
    while (ob_get_level()) ob_end_clean();
    echo json_encode([
        'success' => true,
        'message' => 'Comanda finalizada e estoque baixado com sucesso',
        'valor_total' => $total_comanda,
        'taxa_gorjeta' => $taxa_gorjeta
    ], JSON_UNESCAPED_UNICODE);
    exit;

} catch (Exception $e) {
    while (ob_get_level()) ob_end_clean();
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

?>