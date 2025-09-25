<?php
require_once '../../config/database.php';
require_once '../../includes/functions.php';
require_once '../../includes/header.php';

$database = new Database();
$db = $database->getConnection();

// Buscar produtos com estoque mínimo
$query = "SELECT p.*, c.nome as categoria_nome 
          FROM produtos p 
          JOIN categorias c ON p.categoria_id = c.id 
          WHERE p.ativo = TRUE 
          ORDER BY p.estoque_atual ASC";
$stmt = $db->prepare($query);
$stmt->execute();
$produtos = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Buscar fornecedores
$query_fornecedores = "SELECT * FROM fornecedores ORDER BY nome";
$stmt_fornecedores = $db->prepare($query_fornecedores);
$stmt_fornecedores->execute();
$fornecedores = $stmt_fornecedores->fetchAll(PDO::FETCH_ASSOC);
?>

<div class="estoque-container">
    <h2>📦 Gestão de Estoque</h2>
    
    <div class="alertas-section">
        <h3>⚠️ Alertas de Estoque Mínimo</h3>
        <div class="alertas-grid" id="alertas-grid">
            <?php 
            $alertas_count = 0;
            foreach($produtos as $produto): 
                if ($produto['estoque_atual'] <= $produto['estoque_minimo']):
                    $alertas_count++;
            ?>
            <div class="alerta-card <?= $produto['estoque_atual'] == 0 ? 'critico' : 'aviso' ?>">
                <h4><?= htmlspecialchars($produto['nome']) ?></h4>
                <p>Categoria: <?= htmlspecialchars($produto['categoria_nome']) ?></p>
                <p>Estoque: <strong><?= $produto['estoque_atual'] ?></strong> (Mínimo: <?= $produto['estoque_minimo'] ?>)</p>
                <button class="btn btn-primary btn-sm" onclick="abrirModalEntrada(<?= $produto['id'] ?>)">
                    Registrar Entrada
                </button>
            </div>
            <?php 
                endif;
            endforeach; 
            
            if ($alertas_count == 0): ?>
            <div class="no-alerts">
                <p>✅ Nenhum alerta de estoque no momento</p>
            </div>
            <?php endif; ?>
        </div>
    </div>

    <div class="controles-section">
        <div class="filtros">
            <input type="text" id="filtro-produto" placeholder="Filtrar por nome..." class="form-input">
            <select id="filtro-categoria" class="form-select">
                <option value="">Todas as categorias</option>
                <?php 
                $categorias = getCategorias();
                foreach($categorias as $categoria): ?>
                <option value="<?= $categoria['id'] ?>"><?= htmlspecialchars($categoria['nome']) ?></option>
                <?php endforeach; ?>
            </select>
            <button class="btn" onclick="filtrarProdutos()">Filtrar</button>
        </div>
        
        <button class="btn btn-primary" onclick="abrirModalProduto()">+ Novo Produto</button>
    </div>

    <div class="produtos-section">
        <h3>Lista de Produtos</h3>
        <div class="table-responsive">
            <table class="table" id="tabela-produtos">
                <thead>
                    <tr>
                        <th>Produto</th>
                        <th>Categoria</th>
                        <th>Preço</th>
                        <th>Estoque</th>
                        <th>Mínimo</th>
                        <th>Status</th>
                        <th>Ações</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach($produtos as $produto): ?>
                    <tr data-estoque="<?= $produto['estoque_atual'] ?>" data-minimo="<?= $produto['estoque_minimo'] ?>">
                        <td><?= htmlspecialchars($produto['nome']) ?></td>
                        <td><?= htmlspecialchars($produto['categoria_nome']) ?></td>
                        <td><?= formatarMoeda($produto['preco']) ?></td>
                        <td class="<?= $produto['estoque_atual'] <= $produto['estoque_minimo'] ? 'estoque-baixo' : '' ?>">
                            <?= $produto['estoque_atual'] ?>
                        </td>
                        <td><?= $produto['estoque_minimo'] ?></td>
                        <td>
                            <span class="status <?= $produto['ativo'] ? 'ativo' : 'inativo' ?>">
                                <?= $produto['ativo'] ? 'Ativo' : 'Inativo' ?>
                            </span>
                        </td>
                        <td>
                            <button class="btn btn-sm" onclick="editarProduto(<?= $produto['id'] ?>)">✏️</button>
                            <button class="btn btn-sm btn-primary" onclick="abrirModalEntrada(<?= $produto['id'] ?>)">📥</button>
                            <button class="btn btn-sm btn-danger" onclick="toggleProduto(<?= $produto['id'] ?>, <?= $produto['ativo'] ? 0 : 1 ?>)">
                                <?= $produto['ativo'] ? '❌' : '✅' ?>
                            </button>
                        </td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
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
                    <?php foreach($categorias as $categoria): ?>
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

<script src="estoque.js"></script>
<style>
.estoque-container {
    max-width: 1400px;
}

.alertas-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 1rem;
    margin: 1rem 0;
}

.alerta-card {
    background: white;
    padding: 1rem;
    border-radius: 8px;
    border-left: 4px solid #f39c12;
}

.alerta-card.critico {
    border-left-color: #e74c3c;
    background: #ffeaea;
}

.controles-section {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin: 2rem 0;
    gap: 1rem;
}

.filtros {
    display: flex;
    gap: 1rem;
    align-items: center;
}

.table-responsive {
    overflow-x: auto;
}

.table {
    width: 100%;
    border-collapse: collapse;
    background: white;
}

.table th, .table td {
    padding: 0.75rem;
    text-align: left;
    border-bottom: 1px solid #ddd;
}

.table th {
    background: #f8f9fa;
    font-weight: 600;
}

.estoque-baixo {
    color: #e74c3c;
    font-weight: bold;
}

.status.ativo {
    color: #27ae60;
    font-weight: bold;
}

.status.inativo {
    color: #95a5a6;
}

.btn-sm {
    padding: 0.25rem 0.5rem;
    font-size: 0.875rem;
}

.modal {
    display: none;
    position: fixed;
    z-index: 1000;
    left: 0;
    top: 0;
    width: 100%;
    height: 100%;
    background: rgba(0,0,0,0.5);
}

.modal-content {
    background: white;
    margin: 5% auto;
    padding: 2rem;
    border-radius: 10px;
    width: 90%;
    max-width: 500px;
}

.form-group {
    margin-bottom: 1rem;
}

.form-input, .form-select, .form-textarea {
    width: 100%;
    padding: 0.5rem;
    border: 1px solid #ddd;
    border-radius: 4px;
}

.form-actions {
    display: flex;
    gap: 1rem;
    justify-content: flex-end;
    margin-top: 1.5rem;
}
</style>

<?php require_once '../../includes/footer.php'; ?>