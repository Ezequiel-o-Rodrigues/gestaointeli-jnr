<?php
// api/gerar_comprovante.php
require_once __DIR__ . '/../config/database.php';

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    $comanda_id = $input['comanda_id'] ?? null;
    
    if (!$comanda_id) {
        echo json_encode(['success' => false, 'message' => 'Comanda ID não informado']);
        exit;
    }
    
    try {
        $database = new Database();
        $db = $database->getConnection();
        
        // Buscar dados completos da comanda
        $query = "
            SELECT 
                c.id as comanda_id,
                c.valor_total,
                c.taxa_gorjeta,
                c.data_venda,
                g.nome as garcom_nome,
                g.codigo as garcom_codigo,
                GROUP_CONCAT(CONCAT(p.nome, '|', ic.quantidade, '|', ic.preco_unitario, '|', ic.subtotal) SEPARATOR ';') as itens
            FROM comandas c
            LEFT JOIN garcons g ON c.garcom_id = g.id
            LEFT JOIN itens_comanda ic ON c.id = ic.comanda_id
            LEFT JOIN produtos p ON ic.produto_id = p.id
            WHERE c.id = :comanda_id
            GROUP BY c.id
        ";
        
        $stmt = $db->prepare($query);
        $stmt->bindParam(':comanda_id', $comanda_id);
        $stmt->execute();
        $comanda = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$comanda) {
            throw new Exception('Comanda não encontrada');
        }
        
        // Gerar conteúdo do comprovante
        $conteudo = gerarConteudoComprovante($comanda);
        
        // Salvar comprovante no banco
        $query_insert = "
            INSERT INTO comprovantes_venda (comanda_id, conteudo, tipo) 
            VALUES (:comanda_id, :conteudo, 'cliente')
        ";
        
        $stmt_insert = $db->prepare($query_insert);
        $stmt_insert->bindParam(':comanda_id', $comanda_id);
        $stmt_insert->bindParam(':conteudo', $conteudo);
        $stmt_insert->execute();
        
        $comprovante_id = $db->lastInsertId();
        
        echo json_encode([
            'success' => true,
            'comprovante_id' => $comprovante_id,
            'conteudo' => $conteudo,
            'message' => 'Comprovante gerado com sucesso'
        ]);
        
    } catch (Exception $e) {
        error_log("Erro ao gerar comprovante: " . $e->getMessage());
        echo json_encode(['success' => false, 'message' => 'Erro ao gerar comprovante: ' . $e->getMessage()]);
    }
} else {
    echo json_encode(['success' => false, 'message' => 'Método não permitido']);
}

function gerarConteudoComprovante($comanda) {
    $itens = explode(';', $comanda['itens']);
    $linhas = [];
    
    // Comandos ESC/POS
    $reset = "\x1B\x40"; // Reset printer
    $center = "\x1B\x61\x01"; // Center align
    $left = "\x1B\x61\x00"; // Left align
    $bold_on = "\x1B\x45\x01"; // Bold on
    $bold_off = "\x1B\x45\x00"; // Bold off
    $cut = "\x1B\x69"; // Partial cut
    
    // Cabeçalho
    $linhas[] = $reset . $center . $bold_on . "ESPETINHO DO JUNIOR" . $bold_off . $left;
    $linhas[] = str_repeat("-", 48);
    $linhas[] = "Comanda: #" . $comanda['comanda_id'];
    $linhas[] = "Data: " . date('d/m/Y H:i', strtotime($comanda['data_venda']));
    $linhas[] = "Garçom: " . ($comanda['garcom_nome'] ? $comanda['garcom_nome'] . " (" . $comanda['garcom_codigo'] . ")" : "Não informado");
    $linhas[] = str_repeat("-", 48);
    $linhas[] = "QTD  DESCRICAO";
    $linhas[] = "     VALOR UNIT.   SUBTOTAL";
    $linhas[] = str_repeat("-", 48);
    
    // Itens
    foreach ($itens as $item) {
        if (empty($item)) continue;
        
        list($nome, $quantidade, $preco_unitario, $subtotal) = explode('|', $item);
        
        // Formatar nome do produto
        $nome_linhas = str_split($nome, 25);
        
        $linhas[] = str_pad($quantidade, 4) . " " . $nome_linhas[0];
        $linhas[] = "     R$ " . str_pad(number_format($preco_unitario, 2, ',', '.'), 8) . 
                   "   R$ " . number_format($subtotal, 2, ',', '.');
        
        // Linhas adicionais do nome
        for ($i = 1; $i < count($nome_linhas); $i++) {
            $linhas[] = "     " . $nome_linhas[$i];
        }
        
        $linhas[] = ""; // Linha em branco
    }
    
    // Rodapé
    $linhas[] = str_repeat("-", 48);
    $linhas[] = "SUBTOTAL: R$ " . number_format($comanda['valor_total'] - $comanda['taxa_gorjeta'], 2, ',', '.');
    $linhas[] = "GORJETA:  R$ " . number_format($comanda['taxa_gorjeta'], 2, ',', '.');
    $linhas[] = str_repeat("=", 48);
    $linhas[] = $bold_on . "TOTAL:    R$ " . number_format($comanda['valor_total'], 2, ',', '.') . $bold_off;
    $linhas[] = str_repeat("=", 48);
    $linhas[] = "";
    $linhas[] = $center . "OBRIGADO PELA PREFERÊNCIA!";
    $linhas[] = $center . "VOLTE SEMPRE!";
    $linhas[] = "";
    $linhas[] = $center . date('d/m/Y H:i:s');
    $linhas[] = "\n\n\n\n\n"; // Avançar papel
    $linhas[] = $cut; // Cortar papel
    
    return implode("\n", $linhas);
}
?>