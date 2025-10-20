<?php
// CORRIGIR CAMINHOS - ajuste conforme sua estrutura real
$base_path = ' /gestaointeli-jnr/';

// Usar caminhos absolutos com __DIR__
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../includes/functions.php';

// Iniciar a sessão se necessário
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// INICIALIZAR VARIÁVEIS COM VALORES PADRÃO
$comanda_aberta = null;
$produtos_por_categoria = [];
$total_comanda = 0;
$categorias = [];

try {
    $database = new Database();
    $db = $database->getConnection();

    // Buscar TODOS os produtos ativos com suas categorias
    $query = "SELECT p.*, c.nome as categoria_nome, c.id as categoria_id 
              FROM produtos p 
              JOIN categorias c ON p.categoria_id = c.id 
              WHERE p.ativo = 1 
              ORDER BY c.nome, p.nome";
    $stmt = $db->prepare($query);
    $stmt->execute();
    $produtos = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Agrupar produtos por categoria
    foreach ($produtos as $produto) {
        $categoria_id = $produto['categoria_id'];
        if (!isset($produtos_por_categoria[$categoria_id])) {
            $produtos_por_categoria[$categoria_id] = [
                'categoria_nome' => $produto['categoria_nome'],
                'produtos' => []
            ];
        }
        $produtos_por_categoria[$categoria_id]['produtos'][] = $produto;
    }

    // Buscar comanda aberta atual
    $query_comanda = "SELECT * FROM comandas WHERE status = 'aberta' ORDER BY id DESC LIMIT 1";
    $stmt_comanda = $db->prepare($query_comanda);
    $stmt_comanda->execute();
    $comanda_aberta = $stmt_comanda->fetch(PDO::FETCH_ASSOC);
    
    // Definir total da comanda
    if ($comanda_aberta) {
        $total_comanda = number_format($comanda_aberta['valor_total'] ?? 0, 2, ',', '.');
    }

    // BUSCAR CATEGORIAS PARA O SELECT
    $query_categorias = "SELECT * FROM categorias ORDER BY nome";
    $stmt_categorias = $db->prepare($query_categorias);
    $stmt_categorias->execute();
    $categorias = $stmt_categorias->fetchAll(PDO::FETCH_ASSOC);

} catch (Exception $e) {
    // Log do erro sem quebrar a aplicação
    error_log("Erro ao carregar dados: " . $e->getMessage());
    $produtos_por_categoria = [];
    $comanda_aberta = null;
    $total_comanda = '0,00';
    $categorias = [];
}
?>

<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Caixa - Sistema Restaurante</title>
    <link rel="stylesheet" href="<?php echo $base_path; ?>css/style.css">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #f8f9fa;
            color: #333;
            height: 100vh;
        }

        /* CABEÇALHO */
        .mini-header {
            background: #2c3e50;
            color: white;
            padding: 8px 15px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            height: 50px;
        }

        .mini-header h1 {
            font-size: 1.2rem;
            font-weight: 600;
        }

        .btn-voltar {
            background: #34495e;
            color: white;
            border: none;
            padding: 6px 12px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 0.85rem;
            text-decoration: none;
        }

        /* COMANDA HORIZONTAL - NOVO LAYOUT */
        .comanda-horizontal {
            background: white;
            border-bottom: 2px solid #3498db;
            padding: 8px 15px;
            display: flex;
            align-items: center;
            gap: 15px;
            height: 70px;
            flex-shrink: 0;
        }

        .comanda-info-horizontal {
            display: flex;
            align-items: center;
            gap: 10px;
            min-width: 120px;
        }

        .comanda-numero {
            font-weight: bold;
            color: #2c3e50;
            font-size: 1rem;
        }

        .itens-comanda-horizontal {
            flex: 1;
            display: flex;
            gap: 8px;
            overflow-x: auto;
            padding: 5px 0;
            min-height: 50px;
            align-items: center;
        }

        .item-comanda-horizontal {
            background: #ecf0f1;
            border: 1px solid #bdc3c7;
            border-radius: 20px;
            padding: 6px 12px;
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: 0.8rem;
            white-space: nowrap;
            flex-shrink: 0;
        }

        .item-nome {
            font-weight: 600;
            color: #2c3e50;
        }

        .item-quantidade {
            background: #3498db;
            color: white;
            border-radius: 50%;
            width: 20px;
            height: 20px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 0.7rem;
            font-weight: bold;
        }

        .item-preco {
            font-weight: bold;
            color: #27ae60;
        }

        .btn-remover {
            background: #e74c3c;
            color: white;
            border: none;
            border-radius: 50%;
            width: 18px;
            height: 18px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 0.7rem;
            cursor: pointer;
            padding: 0;
        }

        .btn-remover:hover {
            background: #c0392b;
        }

        .total-comanda {
            font-weight: bold;
            color: #2c3e50;
            font-size: 1rem;
            min-width: 100px;
            text-align: right;
        }

        .empty-comanda {
            color: #95a5a6;
            font-style: italic;
            font-size: 0.85rem;
        }

        /* BOTÕES DE AÇÃO */
        .botoes-comanda {
            display: flex;
            gap: 8px;
            align-items: center;
        }

        .btn {
            padding: 6px 12px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 0.8rem;
            height: 32px;
        }

        .btn-primary {
            background: #3498db;
            color: white;
        }

        .btn-success {
            background: #27ae60;
            color: white;
        }

        .btn:disabled {
            background: #bdc3c7;
            cursor: not-allowed;
        }

        /* CONTEÚDO PRINCIPAL - MAIS ESPAÇO PARA PRODUTOS */
        .conteudo-principal {
            height: calc(100vh - 120px);
            display: flex;
            flex-direction: column;
            padding: 0;
        }

        /* FILTROS */
        .filtros-container {
            background: white;
            padding: 8px 12px;
            border-bottom: 1px solid #e0e0e0;
            display: flex;
            gap: 10px;
            align-items: center;
            flex-wrap: wrap;
        }

        .search-input {
            flex: 1;
            min-width: 150px;
            padding: 6px 10px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-size: 0.85rem;
            height: 32px;
        }

        .categoria-filtro {
            padding: 6px 8px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-size: 0.85rem;
            background: white;
            height: 32px;
            min-width: 120px;
        }

        .contador-produtos {
            color: #7f8c8d;
            font-size: 0.8rem;
            white-space: nowrap;
        }

        /* PRODUTOS */
        .produtos-scroll-container {
            flex: 1;
            overflow-y: auto;
            padding: 8px;
            height: 100%;
        }

        .categoria-produtos {
            margin-bottom: 15px;
        }

        .categoria-titulo {
            background: linear-gradient(135deg, #3498db, #2980b9);
            color: white;
            padding: 6px 10px;
            border-radius: 4px;
            margin-bottom: 8px;
            font-size: 0.9rem;
            font-weight: 600;
        }

        .produtos-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
            gap: 6px;
            margin-bottom: 8px;
        }

        .produto-card {
            padding: 8px;
            border: 1px solid #e0e0e0;
            border-radius: 6px;
            text-align: center;
            cursor: pointer;
            transition: all 0.2s;
            background: white;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            min-height: 80px;
        }

        .produto-card:hover {
            border-color: #3498db;
            transform: translateY(-1px);
            box-shadow: 0 2px 8px rgba(52, 152, 219, 0.2);
        }

        .produto-nome {
            font-weight: 600;
            font-size: 0.75rem;
            line-height: 1.2;
            margin-bottom: 4px;
            color: #2c3e50;
        }

        .produto-preco {
            font-weight: bold;
            color: #27ae60;
            font-size: 0.8rem;
            margin: 3px 0;
        }

        .produto-estoque {
            font-size: 0.7rem;
            color: #7f8c8d;
        }

        .estoque-baixo {
            color: #e74c3c;
            font-weight: bold;
        }

        /* SCROLL HORIZONTAL PARA COMANDA */
        .itens-comanda-horizontal::-webkit-scrollbar {
            height: 4px;
        }

        .itens-comanda-horizontal::-webkit-scrollbar-track {
            background: #f1f1f1;
            border-radius: 2px;
        }

        .itens-comanda-horizontal::-webkit-scrollbar-thumb {
            background: #c1c1c1;
            border-radius: 2px;
        }

        @media (max-width: 768px) {
            .comanda-horizontal {
                flex-direction: column;
                height: auto;
                padding: 8px;
                gap: 8px;
            }
            
            .itens-comanda-horizontal {
                order: 2;
                width: 100%;
            }
            
            .botoes-comanda {
                order: 1;
                width: 100%;
                justify-content: space-between;
            }
            
            .produtos-grid {
                grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));
            }
        }
    </style>
</head>
<body>
    <!-- CABEÇALHO -->
    <div class="mini-header">
        <h1>💰 Caixa Rápido</h1>
        <a href="<?php echo $base_path; ?>index.php" class="btn-voltar">🏠 Início</a>
    </div>

    <!-- COMANDA HORIZONTAL - NOVA POSIÇÃO -->
    <div class="comanda-horizontal">
        <div class="comanda-info-horizontal">
            <span class="comanda-numero" id="numero-comanda">
                <?php echo $comanda_aberta ? '#' . $comanda_aberta['id'] : '--'; ?>
            </span>
            <button class="btn btn-primary" onclick="novaComanda()">Nova</button>
        </div>
        
        <div class="itens-comanda-horizontal" id="itens-comanda">
            <div class="empty-comanda">
                <?php echo $comanda_aberta ? 'Carregando itens...' : 'Nenhuma comanda aberta'; ?>
            </div>
        </div>
        
        <div class="botoes-comanda">
            <span class="total-comanda" id="total-comanda">
                R$ <?php echo $total_comanda; ?>
            </span>
            <button class="btn btn-success" onclick="finalizarComanda()" id="btn-finalizar" 
                    <?php echo (!$comanda_aberta) ? 'disabled' : ''; ?>>
                💰 Finalizar
            </button>
        </div>
    </div>

    <!-- CONTEÚDO PRINCIPAL - MAIS ESPAÇO PARA PRODUTOS -->
    <div class="conteudo-principal">
        <div class="filtros-container">
            <input type="text" id="search-produto" class="search-input" placeholder="🔍 Buscar..." onkeyup="filtrarProdutos()">
            <select id="filtro-categoria" class="categoria-filtro" onchange="filtrarProdutos()">
                <option value="">Todas categorias</option>
                <?php foreach($categorias as $categoria): ?>
                <option value="<?= $categoria['id'] ?>"><?= htmlspecialchars($categoria['nome']) ?></option>
                <?php endforeach; ?>
            </select>
            <span id="contador-produtos" class="contador-produtos"></span>
        </div>

        <div class="produtos-scroll-container" id="produtos-container">
            <?php if (!empty($produtos_por_categoria)): ?>
                <?php foreach($produtos_por_categoria as $categoria_id => $categoria_data): ?>
                <div class="categoria-produtos" data-categoria="<?= $categoria_id ?>">
                    <div class="categoria-titulo">
                        <?= htmlspecialchars($categoria_data['categoria_nome']) ?>
                        <span class="contador-categoria">(<?= count($categoria_data['produtos']) ?>)</span>
                    </div>
                    <div class="produtos-grid">
                        <?php foreach($categoria_data['produtos'] as $produto): ?>
                        <div class="produto-card" 
                             data-produto-id="<?= $produto['id'] ?>"
                             data-produto-nome="<?= htmlspecialchars($produto['nome']) ?>"
                             data-produto-preco="<?= $produto['preco'] ?>"
                             data-produto-categoria="<?= $categoria_id ?>"
                             data-produto-estoque="<?= $produto['estoque_atual'] ?>"
                             onclick="adicionarProduto(<?= $produto['id'] ?>, '<?= htmlspecialchars(addslashes($produto['nome'])) ?>', <?= $produto['preco'] ?>)">
                            
                            <div class="produto-nome"><?= htmlspecialchars($produto['nome']) ?></div>
                            <div class="produto-preco">R$ <?= number_format($produto['preco'], 2, ',', '.') ?></div>
                            <div class="produto-estoque <?= $produto['estoque_atual'] <= $produto['estoque_minimo'] ? 'estoque-baixo' : '' ?>">
                                Est: <?= $produto['estoque_atual'] ?>
                            </div>
                        </div>
                        <?php endforeach; ?>
                    </div>
                </div>
                <?php endforeach; ?>
            <?php else: ?>
                <div style="text-align: center; padding: 40px; color: #7f8c8d;">
                    <div style="font-size: 3rem; margin-bottom: 10px;">📦</div>
                    <h3>Nenhum produto cadastrado</h3>
                    <p>Cadastre produtos no sistema primeiro</p>
                </div>
            <?php endif; ?>
        </div>
    </div>

    <!-- JavaScript -->
    <script>
        // Passar variáveis PHP para JavaScript
        window.appConfig = {
            comandaAtualId: <?php echo isset($comanda_aberta) && $comanda_aberta ? $comanda_aberta['id'] : 'null'; ?>,
            basePath: '<?php echo $base_path; ?>'
        };
    </script>
    <script src="<?php echo $base_path; ?>modules/caixa/caixa.js"></script>
</body>
</html>