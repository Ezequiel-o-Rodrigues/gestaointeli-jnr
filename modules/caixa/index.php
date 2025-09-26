<?php
// CORRIGIR CAMINHOS - ajuste conforme sua estrutura real
$base_path = '/cardapio_jnr/gestaointeli-jnr/gestaointeli-jnr/';

// Usar caminhos absolutos com __DIR__
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../includes/functions.php';

// Iniciar a sessão se necessário
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

$database = new Database();
$db = $database->getConnection();

// Buscar categorias
$query = "SELECT * FROM categorias ORDER BY nome";
$stmt = $db->prepare($query);
$stmt->execute();
$categorias = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Buscar comanda aberta atual
$comanda_aberta = null;
$query_comanda = "SELECT * FROM comandas WHERE status = 'aberta' ORDER BY id DESC LIMIT 1";
$stmt_comanda = $db->prepare($query_comanda);
$stmt_comanda->execute();
$comanda_aberta = $stmt_comanda->fetch(PDO::FETCH_ASSOC);
?>

<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Caixa - Sistema Restaurante</title>
    <link rel="stylesheet" href="<?php echo $base_path; ?>css/style.css">
    <style>
        /* Estilos específicos para o caixa */
        .caixa-container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }

        .caixa-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 2rem;
            padding: 1.5rem;
            background: white;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }

        .comanda-info {
            display: flex;
            align-items: center;
            gap: 1rem;
        }

        .caixa-content {
            display: grid;
            grid-template-columns: 2fr 1fr;
            gap: 2rem;
        }

        .categorias-section, .produtos-section {
            background: white;
            padding: 1.5rem;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }

        .comanda-section {
            background: white;
            padding: 1.5rem;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }

        .categorias-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin-top: 1rem;
        }

        .categoria-card {
            padding: 1.5rem;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            text-align: center;
            cursor: pointer;
            transition: all 0.3s;
        }

        .categoria-card:hover {
            border-color: #3498db;
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }

        .produtos-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 1rem;
            margin: 1rem 0;
        }

        .produto-card {
            padding: 1rem;
            border: 1px solid #ddd;
            border-radius: 8px;
            text-align: center;
            cursor: pointer;
            transition: all 0.3s;
        }

        .produto-card:hover {
            border-color: #3498db;
            background: #f8f9fa;
        }

        .preco {
            font-weight: bold;
            color: #27ae60;
            margin: 0.5rem 0;
        }

        .itens-comanda {
            max-height: 300px;
            overflow-y: auto;
            margin: 1rem 0;
            border: 1px solid #eee;
            border-radius: 5px;
            padding: 1rem;
        }

        .item-comanda {
            display: flex;
            justify-content: space-between;
            padding: 0.5rem;
            border-bottom: 1px solid #eee;
        }

        .item-comanda:last-child {
            border-bottom: none;
        }

        .total-section {
            background: #f8f9fa;
            padding: 1rem;
            border-radius: 5px;
            margin-top: 1rem;
        }

        .totais div {
            display: flex;
            justify-content: space-between;
            margin: 0.5rem 0;
            font-size: 1.1rem;
        }

        .empty-message {
            text-align: center;
            color: #95a5a6;
            font-style: italic;
            padding: 2rem;
        }

        .btn {
            padding: 0.75rem 1.5rem;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 1rem;
            transition: background 0.3s;
            text-decoration: none;
            display: inline-block;
        }

        .btn-primary {
            background: #3498db;
            color: white;
        }

        .btn-primary:hover {
            background: #2980b9;
        }

        .btn-success {
            background: #27ae60;
            color: white;
        }

        .btn-success:hover {
            background: #219a52;
        }

        .btn:disabled {
            background: #bdc3c7;
            cursor: not-allowed;
        }
    </style>
</head>
<body>
    <header class="header">
        <div class="container">
            <h1>🍽️ Sistema Restaurante - Caixa</h1>
            <nav class="main-nav">
                <a href="<?php echo $base_path; ?>index.php">🏠 Início</a>
                <a href="<?php echo $base_path; ?>modules/caixa/">💰 Caixa</a>
                <a href="<?php echo $base_path; ?>modules/estoque/">📦 Estoque</a>
                <a href="<?php echo $base_path; ?>modules/relatorios/">📊 Relatórios</a>
                <a href="<?php echo $base_path; ?>modules/admin/">⚙️ Admin</a>
            </nav>
        </div>
    </header>

    <main class="container">
        <div class="caixa-container">
            <div class="caixa-header">
                <h2>💰 Sistema de Caixa</h2>
                <div class="comanda-info">
                    <span id="numero-comanda">Comanda: <?php echo $comanda_aberta ? '#' . $comanda_aberta['id'] : '--'; ?></span>
                    <button class="btn btn-primary" onclick="novaComanda()">Nova Comanda</button>
                </div>
            </div>

            <div class="caixa-content">
                <div>
                    <div class="categorias-section" id="categorias-section">
                        <h3>Categorias de Produtos</h3>
                        <div class="categorias-grid" id="categorias-grid">
                            <?php foreach($categorias as $categoria): ?>
                            <div class="categoria-card" onclick="carregarProdutos(<?= $categoria['id'] ?>, '<?= htmlspecialchars($categoria['nome']) ?>')">
                                <h4><?= htmlspecialchars($categoria['nome']) ?></h4>
                                <p><?= htmlspecialchars($categoria['descricao']) ?></p>
                            </div>
                            <?php endforeach; ?>
                        </div>
                    </div>

                    <div class="produtos-section" id="produtos-section" style="display: none;">
                        <h3 id="titulo-produtos">Produtos da Categoria</h3>
                        <div class="produtos-grid" id="produtos-grid"></div>
                        <button class="btn" onclick="voltarCategorias()" style="margin-top: 1rem;">← Voltar para Categorias</button>
                    </div>
                </div>

                <div class="comanda-section">
                    <h3>Comanda Atual</h3>
                    <div class="itens-comanda" id="itens-comanda">
                        <?php if($comanda_aberta): ?>
                            <?php
                            // Buscar itens da comanda
                            $query_itens = "SELECT ic.*, p.nome as produto_nome 
                                          FROM itens_comanda ic 
                                          JOIN produtos p ON ic.produto_id = p.id 
                                          WHERE ic.comanda_id = ?";
                            $stmt_itens = $db->prepare($query_itens);
                            $stmt_itens->execute([$comanda_aberta['id']]);
                            $itens = $stmt_itens->fetchAll(PDO::FETCH_ASSOC);
                            
                            if(count($itens) > 0): ?>
                                <?php foreach($itens as $item): ?>
                                <div class="item-comanda">
                                    <span><?= htmlspecialchars($item['produto_nome']) ?> x<?= $item['quantidade'] ?></span>
                                    <span>R$ <?= number_format($item['subtotal'], 2, ',', '.') ?></span>
                                </div>
                                <?php endforeach; ?>
                            <?php else: ?>
                                <p class="empty-message">Nenhum item adicionado</p>
                            <?php endif; ?>
                        <?php else: ?>
                            <p class="empty-message">Nenhuma comanda aberta</p>
                        <?php endif; ?>
                    </div>
                    
                    <div class="total-section">
                        <div class="totais">
                            <div>Subtotal: <span id="subtotal">R$ <?php echo $comanda_aberta ? number_format($comanda_aberta['valor_total'], 2, ',', '.') : '0,00'; ?></span></div>
                            <div>Taxa: <span id="taxa">R$ 0,00</span></div>
                            <div><strong>Total: <span id="total">R$ <?php echo $comanda_aberta ? number_format($comanda_aberta['valor_total'], 2, ',', '.') : '0,00'; ?></span></strong></div>
                        </div>
                        <button class="btn btn-success" onclick="finalizarComanda()" 
                                <?php echo (!$comanda_aberta || $comanda_aberta['valor_total'] == 0) ? 'disabled' : ''; ?> 
                                id="btn-finalizar" style="width: 100%; margin-top: 1rem;">
                            Finalizar Venda
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </main>

    

    <!-- Incluir o arquivo JavaScript externo (se existir) -->
    <script src="<?php echo $base_path; ?>modules/caixa/caixa.js"></script>

</body>
</html>