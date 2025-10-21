<?php
require_once __DIR__ . '/../../config/paths.php';
require_once PathConfig::config('database.php');

?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Gestão de Estoque</title>
    <link rel="stylesheet" href="<?= PathConfig::assets('css/bootstrap.min.css') ?>">
    <link rel="stylesheet" href="<?= PathConfig::modules('estoque/css/estoque.css') ?>">
    <script src="<?= PathConfig::url('js/path-config.js') ?>"></script>
</head>
<body>
    <?php include PathConfig::includes('header.php'); ?>
    
    <div class="container mt-4">
        <h2>Gestão de Estoque</h2>
        
        <div class="row">
            <div class="col-md-12">
                <div id="estoque-container">
                    <!-- Conteúdo será carregado via JavaScript -->
                    <p>Carregando estoque...</p>
                </div>
            </div>
        </div>
    </div>

    <script src="<?= PathConfig::assets('js/bootstrap.bundle.min.js') ?>"></script>
    <script src="<?= PathConfig::modules('estoque/js/estoque.js') ?>"></script>
</body>
</html>

<?php
$database = new Database();
$db = $database->getConnection();

// Buscar categorias com produtos
$query_categorias = "SELECT DISTINCT c.* 
                    FROM categorias c 
                    JOIN produtos p ON c.id = p.categoria_id 
                    WHERE p.ativo = TRUE 
                    ORDER BY c.nome ASC";
$stmt_categorias = $db->prepare($query_categorias);
$stmt_categorias->execute();
$categorias = $stmt_categorias->fetchAll(PDO::FETCH_ASSOC);

// Buscar produtos agrupados por categoria
$query_produtos = "SELECT p.*, c.nome as categoria_nome 
                  FROM produtos p 
                  JOIN categorias c ON p.categoria_id = c.id 
                  WHERE p.ativo = TRUE 
                  ORDER BY c.nome ASC, p.nome ASC";
$stmt_produtos = $db->prepare($query_produtos);
$stmt_produtos->execute();
$produtos = $stmt_produtos->fetchAll(PDO::FETCH_ASSOC);

// Agrupar produtos por categoria
$produtos_por_categoria = [];
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

// Buscar fornecedores
$query_fornecedores = "SELECT * FROM fornecedores ORDER BY nome";
$stmt_fornecedores = $db->prepare($query_fornecedores);
$stmt_fornecedores->execute();
$fornecedores = $stmt_fornecedores->fetchAll(PDO::FETCH_ASSOC);

// Buscar todas as categorias para o filtro
$todas_categorias = getCategorias();
?>

<div class="estoque-container">
    <div class="header">
        <h1 class="page-title">📦 Gestão de Estoque</h1>
    </div>

    <!-- Alertas de Estoque Mínimo - AGORA FIXO NO TOPO -->
    <?php 
    $alertas_count = 0;
    $alertas_criticos = [];
    $alertas_aviso = [];
    
    foreach($produtos as $produto): 
        if ($produto['estoque_atual'] <= $produto['estoque_minimo']):
            $alertas_count++;
            if ($produto['estoque_atual'] == 0) {
                $alertas_criticos[] = $produto;
            } else {
                $alertas_aviso[] = $produto;
            }
        endif;
    endforeach; 
    ?>
    
    <?php if ($alertas_count > 0): ?>
    <div class="alertas-fixo">
        <div class="alerta-header">
            <h3>⚠️ Alertas de Estoque</h3>
            <span class="alerta-badge"><?= $alertas_count ?></span>
        </div>
        <div class="alertas-content">
            <?php if (!empty($alertas_criticos)): ?>
            <div class="alerta-grupo critico">
                <h4>🛑 Crítico (Estoque Zerado)</h4>
                <?php foreach($alertas_criticos as $produto): ?>
                <div class="alerta-item">
                    <span class="alerta-nome"><?= htmlspecialchars($produto['nome']) ?></span>
                    <span class="alerta-info">Estoque: <?= $produto['estoque_atual'] ?> (Mín: <?= $produto['estoque_minimo'] ?>)</span>
                    <button class="btn-alerta" onclick="abrirModalEntrada(<?= $produto['id'] ?>)">
                        <i class="fas fa-box"></i> Entrada
                    </button>
                </div>
                <?php endforeach; ?>
            </div>
            <?php endif; ?>
            
            <?php if (!empty($alertas_aviso)): ?>
            <div class="alerta-grupo aviso">
                <h4>⚠️ Atenção (Estoque Baixo)</h4>
                <?php foreach($alertas_aviso as $produto): ?>
                <div class="alerta-item">
                    <span class="alerta-nome"><?= htmlspecialchars($produto['nome']) ?></span>
                    <span class="alerta-info">Estoque: <?= $produto['estoque_atual'] ?> (Mín: <?= $produto['estoque_minimo'] ?>)</span>
                    <button class="btn-alerta" onclick="abrirModalEntrada(<?= $produto['id'] ?>)">
                        <i class="fas fa-box"></i> Entrada
                    </button>
                </div>
                <?php endforeach; ?>
            </div>
            <?php endif; ?>
        </div>
    </div>
    <?php endif; ?>

    <!-- Filtros -->
    <div class="card">
        <h2 class="card-title"><i class="fas fa-filter"></i> Filtros</h2>
        <div class="filter-section">
            <div class="filter-group">
                <label for="filtro-categoria" class="filter-label">Categoria</label>
                <select id="filtro-categoria" class="filter-select" onchange="filtrarProdutos()">
                    <option value="all">Todas as categorias</option>
                    <?php foreach($todas_categorias as $categoria): ?>
                    <option value="<?= $categoria['id'] ?>"><?= htmlspecialchars($categoria['nome']) ?></option>
                    <?php endforeach; ?>
                </select>
            </div>
            
            <div class="filter-group">
                <label for="filtro-status" class="filter-label">Status do Estoque</label>
                <select id="filtro-status" class="filter-select" onchange="filtrarProdutos()">
                    <option value="all">Todos os status</option>
                    <option value="normal">Estoque Normal</option>
                    <option value="baixo">Estoque Baixo</option>
                    <option value="zero">Estoque Zerado</option>
                </select>
            </div>
            
            <div class="filter-group">
                <label for="filtro-produto" class="filter-label">Buscar Produto</label>
                <input type="text" id="filtro-produto" class="filter-input" placeholder="Digite para buscar..." onkeyup="filtrarProdutos()">
            </div>
        </div>
    </div>

    <!-- Lista de Produtos por Categoria -->
    <?php foreach($produtos_por_categoria as $categoria_id => $categoria_data): ?>
    <div class="card" id="categoria-<?= $categoria_id ?>-card">
        <h2 class="card-title"><i class="fas fa-tag"></i> <?= htmlspecialchars($categoria_data['categoria_nome']) ?></h2>
        <div class="item-list">
            <div class="item-row item-header">
                <div>ID</div>
                <div>Nome do Produto</div>
                <div>Preço</div>
                <div>Estoque Atual</div>
                <div>Estoque Mínimo</div>
                <div>Status</div>
                <div>Ações</div>
            </div>
            <?php foreach($categoria_data['produtos'] as $produto): 
                $estoque_status = '';
                if ($produto['estoque_atual'] == 0) {
                    $estoque_status = 'zero';
                } elseif ($produto['estoque_atual'] <= $produto['estoque_minimo']) {
                    $estoque_status = 'baixo';
                } else {
                    $estoque_status = 'normal';
                }
            ?>
            <div class="item-row <?= $estoque_status == 'zero' ? 'inactive' : '' ?>" 
                 data-categoria="<?= $categoria_id ?>" 
                 data-status="<?= $estoque_status ?>"
                 data-search="<?= htmlspecialchars($produto['nome']) ?>">
                <div class="item-id"><?= $produto['id'] ?></div>
                <div class="item-nome"><?= htmlspecialchars($produto['nome']) ?></div>
                <div class="item-preco">R$ <?= number_format($produto['preco'], 2, ',', '.') ?></div>
                <div class="item-estoque <?= $estoque_status == 'baixo' || $estoque_status == 'zero' ? 'estoque-baixo' : '' ?>">
                    <?= $produto['estoque_atual'] ?>
                </div>
                <div class="item-minimo"><?= $produto['estoque_minimo'] ?></div>
                <div class="item-status">
                    <span class="status <?= $estoque_status ?>">
                        <?= $estoque_status == 'zero' ? 'Zerado' : ($estoque_status == 'baixo' ? 'Baixo' : 'Normal') ?>
                    </span>
                </div>
                <div class="action-buttons">
                    <button class="action-btn edit-btn" onclick="editarProduto(<?= $produto['id'] ?>)" title="Editar produto">
                        <i class="fas fa-edit"></i>
                    </button>
                    <button class="action-btn entrada-btn" onclick="abrirModalEntrada(<?= $produto['id'] ?>)" title="Registrar entrada">
                        <i class="fas fa-box"></i>
                    </button>
                    <button class="action-btn toggle-btn" onclick="toggleProduto(<?= $produto['id'] ?>, <?= $produto['ativo'] ? 0 : 1 ?>, this)" 
                            title="<?= $produto['ativo'] ? 'Desativar produto' : 'Ativar produto' ?>">
                        <i class="fas <?= $produto['ativo'] ? 'fa-eye-slash' : 'fa-eye' ?>"></i>
                    </button>
                </div>
            </div>
            <?php endforeach; ?>
        </div>
    </div>
    <?php endforeach; ?>

    <!-- Botão Novo Produto -->
    <div class="card">
        <button class="btn btn-primary" onclick="abrirModalProduto()">
            <i class="fas fa-plus"></i> Novo Produto
        </button>
    </div>
</div>


<!-- Modal Registrar Entrada -->
<div id="modal-entrada" class="modal">
    <div class="modal-content">
        <span class="close" onclick="fecharModalEntrada()">&times;</span>
        <h3>Registrar Entrada no Estoque</h3>
        <form id="form-entrada">
            <input type="hidden" id="produto_id_entrada">
            <div class="form-group">
                <label>Produto:</label>
                <span id="nome-produto-entrada" class="form-readonly"></span>
            </div>
            <div class="form-group">
                <label>Quantidade:</label>
                <input type="number" id="quantidade_entrada" min="1" required class="form-input">
            </div>
            <div class="form-group">
                <label>Fornecedor:</label>
                <select id="fornecedor_entrada" class="form-select">
                    <option value="">Selecione um fornecedor</option>
                    <?php foreach($fornecedores as $fornecedor): ?>
                    <option value="<?= $fornecedor['id'] ?>"><?= htmlspecialchars($fornecedor['nome']) ?></option>
                    <?php endforeach; ?>
                </select>
            </div>
            <div class="form-group">
                <label>Observação:</label>
                <textarea id="observacao_entrada" class="form-textarea"></textarea>
            </div>
            <div class="form-actions">
                <button type="button" class="btn" onclick="fecharModalEntrada()">Cancelar</button>
                <button type="submit" class="btn btn-primary">Registrar Entrada</button>
            </div>
        </form>
    </div>
</div>

<!-- Modal Novo Produto -->
<div id="modal-produto" class="modal">
    <div class="modal-content">
        <span class="close" onclick="fecharModalProduto()">&times;</span>
        <h3 id="titulo-modal-produto">Novo Produto</h3>
        <form id="form-produto">
            <input type="hidden" id="produto_id">
            <div class="form-group">
                <label>Nome:</label>
                <input type="text" id="nome_produto" required class="form-input">
            </div>
            <div class="form-group">
                <label>Categoria:</label>
                <select id="categoria_produto" required class="form-select">
                    <option value="">Selecione uma categoria</option>
                    <?php foreach($todas_categorias as $categoria): ?>
                    <option value="<?= $categoria['id'] ?>"><?= htmlspecialchars($categoria['nome']) ?></option>
                    <?php endforeach; ?>
                </select>
            </div>
            <div class="form-group">
                <label>Preço:</label>
                <input type="number" id="preco_produto" step="0.01" min="0" required class="form-input">
            </div>
            <div class="form-group">
                <label>Estoque Mínimo:</label>
                <input type="number" id="estoque_minimo_produto" min="0" required class="form-input">
            </div>
            <div class="form-group">
                <label>Estoque Inicial:</label>
                <input type="number" id="estoque_inicial_produto" min="0" class="form-input">
            </div>
            <div class="form-actions">
                <button type="button" class="btn" onclick="fecharModalProduto()">Cancelar</button>
                <button type="submit" class="btn btn-primary">Salvar Produto</button>
            </div>
        </form>
    </div>
</div>

<!-- Toast para mensagens -->
<div id="toast-container"></div>

<style>
/* Reset e Variáveis */
:root {
    --bg-dark: #ffffffff;
    --bg-panel: #2c3e50;
    --text-primary: #ffffffff;
    --text-secondary: #ffffffff;
    --accent-color: #4a6fa5;
    --border-color: #2c3e50;
    --success-color: #27ae60;
    --warning-color: #f39c12;
    --card-bg: #2c3e50c7;/* Fundo semi-transparente */
    --danger-color: #e74c3c;
    --inactive-color: #f00303ff;
}

* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    background-color: var(--bg-dark);
    color: var(--text-primary);
    background-image: linear-gradient(to bottom right, #fcfcfcff);
    min-height: 100vh;
    line-height: 1.6;
}

.estoque-container {
    max-width: 1400px;
    margin: 0 auto;
    padding: 20px;
}

/* Header */
.header {
    text-align: center;
    margin-bottom: 30px;
    padding-bottom: 20px;
    border-bottom: 1px solid var(--border-color);
}

.page-title {
    color: var(--text-primary);
    margin: 0 0 20px 0;
    font-size: 2.5rem;
    background: linear-gradient(to right, #dbd0d0ff, #fafafaff);
    -webkit-background-clip: text;
    background-clip: text;
    -webkit-text-fill-color: transparent;
    text-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
}

/* Alertas Fixos */
.alertas-fixo {
    background: linear-gradient(135deg, #2c3e50, #34495e);
    border-radius: 10px;
    margin-bottom: 25px;
    border-left: 5px solid var(--warning-color);
    box-shadow: 0 8px 20px rgba(0, 0, 0, 0.3);
    overflow: hidden;
}

.alerta-header {
    background: rgba(0, 0, 0, 0.3);
    padding: 15px 25px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    border-bottom: 1px solid var(--border-color);
}

.alerta-header h3 {
    margin: 0;
    color: var(--text-primary);
    font-size: 1.3rem;
}

.alerta-badge {
    background: var(--danger-color);
    color: white;
    padding: 5px 12px;
    border-radius: 20px;
    font-weight: bold;
    font-size: 0.9rem;
}

.alertas-content {
    padding: 20px 25px;
}

.alerta-grupo {
    margin-bottom: 20px;
}

.alerta-grupo:last-child {
    margin-bottom: 0;
}

.alerta-grupo.critico h4 {
    color: var(--danger-color);
    margin-bottom: 10px;
    font-size: 1.1rem;
}

.alerta-grupo.aviso h4 {
    color: var(--warning-color);
    margin-bottom: 10px;
    font-size: 1.1rem;
}

.alerta-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 10px 0;
    border-bottom: 1px solid rgba(255, 255, 255, 1);
}

.alerta-item:last-child {
    border-bottom: none;
}

.alerta-nome {
    font-weight: 600;
    color: var(--text-primary);
    flex: 1;
}

.alerta-info {
    color: var(--text-secondary);
    margin: 0 15px;
    font-size: 0.9rem;
}

.btn-alerta {
    background: var(--accent-color);
    color: white;
    border: none;
    padding: 6px 12px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.8rem;
    display: flex;
    align-items: center;
    gap: 5px;
    transition: all 0.3s;
}

.btn-alerta:hover {
    background: #3a5a8c;
    transform: translateY(-1px);
}

/* Cards */
.card {
    background-color: var(--card-bg);
    border-radius: 10px;
    padding: 25px;
    margin-bottom: 25px;
    border-left: 5px solid var(--accent-color);
    box-shadow: 0 8px 20px rgba(0, 0, 0, 0.3);
    backdrop-filter: blur(10px);
    transition: transform 0.3s ease, box-shadow 0.3s ease;
}

.card:hover {
    transform: translateY(-3px);
    box-shadow: 0 12px 25px rgba(0, 0, 0, 0.4);
}

.card-title {
    margin-top: 0;
    margin-bottom: 25px;
    font-size: 1.4rem;
    color: var(--text-primary);
    display: flex;
    align-items: center;
    gap: 12px;
    padding-bottom: 15px;
    border-bottom: 1px solid var(--border-color);
}

/* Lista de Itens */
.item-list {
    border: 1px solid var(--border-color);
    border-radius: 8px;
    overflow: hidden;
    background:  #34495e; 
}

.item-row {
    display: grid;
    grid-template-columns: 60px 2fr 1fr 1fr 1fr 1fr 140px;
    padding: 15px 20px;
    border-bottom: 1px solid var(--border-color);
    align-items: center;
    color: var(--text-primary);
    font-size: 0.95rem;
}

.item-row.item-header {
    background-color: var(--bg-panel);
    font-weight: bold;
    color: var(--accent-color);
    font-size: 0.9rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

.item-row:nth-child(even) {
    background-color: rgba(40, 40, 60, 0.3);
}

.item-row.inactive {
    opacity: 0.7;
    background-color: rgba(108, 117, 125, 0.2);
}

/* Cores específicas para células */
.item-id {
    color: var(--text-secondary);
    font-weight: 600;
}

.item-nome {
    color: var(--text-primary);
    font-weight: 500;
}

.item-preco {
    color: var(--success-color);
    font-weight: 600;
}

.item-estoque {
    font-weight: 600;
}

.item-minimo {
    color: var(--text-secondary);
}

.estoque-baixo {
    color: var(--warning-color) !important;
}

/* Status */
.item-status .status {
    padding: 6px 12px;
    border-radius: 20px;
    font-size: 0.8rem;
    font-weight: bold;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

.status.normal {
    background: rgba(39, 174, 96, 0.2);
    color: var(--success-color);
    border: 1px solid rgba(39, 174, 96, 0.3);
}

.status.baixo {
    background: rgba(243, 156, 18, 0.2);
    color: var(--warning-color);
    border: 1px solid rgba(243, 156, 18, 0.3);
}

.status.zero {
    background: rgba(231, 76, 60, 0.2);
    color: var(--danger-color);
    border: 1px solid rgba(231, 76, 60, 0.3);
}

/* Botões de Ação */
.action-buttons {
    display: flex;
    gap: 8px;
    justify-content: center;
}

.action-btn {
    background: none;
    border: none;
    cursor: pointer;
    font-size: 16px;
    padding: 8px;
    border-radius: 6px;
    transition: all 0.3s;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 36px;
    height: 36px;
}

.action-btn:hover {
    transform: scale(1.1);
}

.edit-btn {
    color: var(--accent-color);
    background: rgba(74, 111, 165, 0.1);
}

.edit-btn:hover {
    background: rgba(74, 111, 165, 0.2);
}

.entrada-btn {
    color: var(--success-color);
    background: rgba(39, 174, 96, 0.1);
}

.entrada-btn:hover {
    background: rgba(39, 174, 96, 0.2);
}

.toggle-btn {
    color: var(--warning-color);
    background: rgba(243, 156, 18, 0.1);
}

.toggle-btn:hover {
    background: rgba(243, 156, 18, 0.2);
}

.action-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
    transform: none;
}

/* Filtros */
.filter-section {
    display: flex;
    gap: 20px;
    margin-bottom: 10px;
    flex-wrap: wrap;
}

.filter-group {
    display: flex;
    flex-direction: column;
    gap: 8px;
}

.filter-label {
    font-size: 0.9rem;
    color: var(--text-secondary);
    font-weight: 500;
}

.filter-select, .filter-input {
    padding: 10px 12px;
    border-radius: 6px;
    border: 1px solid var(--border-color);
    background-color: rgba(22, 33, 62, 0.8);
    color: var(--text-primary);
    min-width: 200px;
    font-size: 0.95rem;
    transition: all 0.3s;
}

.filter-select:focus, .filter-input:focus {
    outline: none;
    border-color: var(--accent-color);
    box-shadow: 0 0 0 2px rgba(74, 111, 165, 0.2);
}

/* Botões Principais */
.btn {
    padding: 12px 24px;
    border-radius: 8px;
    border: none;
    cursor: pointer;
    font-weight: 600;
    transition: all 0.3s;
    font-size: 1rem;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 10px;
    text-decoration: none;
}

.btn-primary {
    background: linear-gradient(135deg, #4a6fa5, #5a86c1);
    color: white;
    box-shadow: 0 4px 12px rgba(74, 111, 165, 0.4);
}

.btn-primary:hover {
    background: linear-gradient(135deg, #3a5a8c, #4a6fa5);
    box-shadow: 0 6px 18px rgba(74, 111, 165, 0.6);
    transform: translateY(-2px);
}

/* Modais */
.modal {
    display: none;
    position: fixed;
    z-index: 1000;
    left: 0;
    top: 0;
    width: 100%;
    height: 100%;
    background: rgba(0,0,0,0.7);
    backdrop-filter: blur(5px);
}

.modal-content {
    background: var(--card-bg);
    margin: 5% auto;
    padding: 2rem;
    border-radius: 12px;
    width: 90%;
    max-width: 500px;
    color: var(--text-primary);
    border-left: 5px solid var(--accent-color);
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.5);
}

.close {
    color: var(--text-secondary);
    float: right;
    font-size: 28px;
    font-weight: bold;
    cursor: pointer;
    transition: color 0.3s;
}

.close:hover {
    color: var(--text-primary);
}

.form-group {
    margin-bottom: 1.5rem;
}

.form-group label {
    display: block;
    margin-bottom: 8px;
    color: var(--text-primary);
    font-weight: 500;
}

.form-input, .form-select, .form-textarea {
    width: 100%;
    padding: 12px;
    border: 1px solid var(--border-color);
    border-radius: 6px;
    background-color: rgba(22, 33, 62, 0.8);
    color: var(--text-primary);
    font-size: 1rem;
    transition: all 0.3s;
}

.form-input:focus, .form-select:focus, .form-textarea:focus {
    outline: none;
    border-color: var(--accent-color);
    box-shadow: 0 0 0 2px rgba(74, 111, 165, 0.2);
}

.form-readonly {
    padding: 12px;
    background: rgba(255,255,255,0.05);
    border-radius: 6px;
    display: inline-block;
    color: var(--text-primary);
    border: 1px solid var(--border-color);
}

.form-actions {
    display: flex;
    gap: 1rem;
    justify-content: flex-end;
    margin-top: 2rem;
}

/* Toast */
.toast {
    position: fixed;
    bottom: 20px;
    left: 50%;
    transform: translateX(-50%);
    padding: 16px 24px;
    border-radius: 8px;
    color: white;
    opacity: 0;
    transition: all 0.3s ease;
    z-index: 1000;
    background-color: var(--bg-panel);
    border-left: 4px solid;
    box-shadow: 0 8px 20px rgba(0, 0, 0, 0.3);
    font-weight: 500;
}

.toast.success {
    border-left-color: var(--success-color);
    background: linear-gradient(135deg, var(--bg-panel), #1e3c2a);
}

.toast.error {
    border-left-color: var(--danger-color);
    background: linear-gradient(135deg, var(--bg-panel), #3c1e1e);
}

.toast.warning {
    border-left-color: var(--warning-color);
    background: linear-gradient(135deg, var(--bg-panel), #3c2e1e);
}

.toast.show {
    opacity: 1;
    bottom: 30px;
}

.fa-spinner {
    animation: fa-spin 1s infinite linear;
}

@keyframes fa-spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
}

/* Responsividade */
@media (max-width: 1200px) {
    .item-row {
        grid-template-columns: 50px 2fr 1fr 1fr 1fr 1fr 120px;
        font-size: 0.9rem;
        padding: 12px 15px;
    }
}

@media (max-width: 768px) {
    .estoque-container {
        padding: 15px;
    }
    
    .filter-section {
        flex-direction: column;
    }
    
    .filter-select, .filter-input {
        min-width: 100%;
    }
    
    .item-list {
        overflow-x: auto;
    }
    
    .item-row {
        grid-template-columns: 50px 200px 100px 80px 80px 100px 100px;
        min-width: 710px;
    }
    
    .action-buttons {
        flex-direction: column;
        gap: 5px;
    }
    
    .action-btn {
        width: 32px;
        height: 32px;
        font-size: 14px;
    }
}

}

/* Animações */
@keyframes fa-spin {
0% { transform: rotate(0deg); }
100% { transform: rotate(360deg); }
}

.fa-spinner {
animation: fa-spin 1s infinite linear;
}

/* Melhorias para emojis nos botões */
.action-btn::before {
font-size: 14px;
}

.edit-btn::before {
content: "✏️";
}

.entrada-btn::before {
content: "📥";
}

.toggle-btn::before {
content: "🔄";
}

.btn-alerta::before {
content: "🛒";
margin-right: 4px;
}

.btn-voltar::before {
content: "←";
margin-right: 4px;
}

.btn-primary::before {
content: "➕";
}
</style>

<?php require_once PathConfig::includes('footer.php'); ?>