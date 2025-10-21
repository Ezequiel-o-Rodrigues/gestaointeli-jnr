<?php
require_once __DIR__ . '/../../config/database.php';

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
function getCategorias() {
    $database = new Database();
    $db = $database->getConnection();
    
    $query = "SELECT * FROM categorias ORDER BY nome";
    $stmt = $db->prepare($query);
    $stmt->execute();
    
    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

$todas_categorias = getCategorias();

// Alertas de Estoque
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
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Gestão de Estoque</title>
    
    <!-- Bootstrap CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    
    <style>
        :root {
            --primary-color: #2c3e50;
            --secondary-color: #34495e;
            --accent-color: #3498db;
            --success-color: #27ae60;
            --warning-color: #f39c12;
            --danger-color: #e74c3c;
        }

        .stock-alert {
            border-left: 4px solid var(--warning-color);
            background: #fff3cd;
        }

        .stock-critical {
            border-left: 4px solid var(--danger-color);
            background: #f8d7da;
        }

        .product-card {
            transition: transform 0.2s;
            border: 1px solid #dee2e6;
        }

        .product-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
        }

        .low-stock {
            color: var(--warning-color);
            font-weight: bold;
        }

        .no-stock {
            color: var(--danger-color);
            font-weight: bold;
        }

        .status-badge {
            padding: 4px 8px;
            border-radius: 12px;
            font-size: 0.8em;
            font-weight: bold;
        }

        .status-normal { background: #d4edda; color: #155724; }
        .status-low { background: #fff3cd; color: #856404; }
        .status-critical { background: #f8d7da; color: #721c24; }
    </style>
</head>
<body>
    <!-- Navigation -->
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark">
        <div class="container">
            <a class="navbar-brand" href="/gestaointeli-jnr/">
                <i class="fas fa-warehouse"></i> Sistema Estoque
            </a>
            <div class="navbar-nav ms-auto">
                <a class="nav-link" href="/gestaointeli-jnr/">
                    <i class="fas fa-home"></i> Início
                </a>
                <a class="nav-link active" href="/gestaointeli-jnr/modules/estoque/">
                    <i class="fas fa-boxes"></i> Estoque
                </a>
                <a class="nav-link" href="/gestaointeli-jnr/modules/caixa/">
                    <i class="fas fa-cash-register"></i> Caixa
                </a>
            </div>
        </div>
    </nav>

    <div class="container-fluid py-4">
        <!-- Header -->
        <div class="row mb-4">
            <div class="col-12">
                <div class="d-flex justify-content-between align-items-center">
                    <h1 class="h3">
                        <i class="fas fa-boxes text-primary"></i> Gestão de Estoque
                    </h1>
                    <button class="btn btn-primary" onclick="estoqueManager.showProductModal()">
                        <i class="fas fa-plus"></i> Novo Produto
                    </button>
                </div>
            </div>
        </div>

        <!-- Alertas -->
        <?php if ($alertas_count > 0): ?>
        <div class="row mb-4">
            <div class="col-12">
                <div class="alert alert-warning">
                    <div class="d-flex justify-content-between align-items-center">
                        <h5 class="alert-heading mb-0">
                            <i class="fas fa-exclamation-triangle"></i> 
                            Alertas de Estoque (<?= $alertas_count ?>)
                        </h5>
                        <span class="badge bg-danger"><?= $alertas_count ?></span>
                    </div>
                    <hr>
                    <div class="row">
                        <?php if (!empty($alertas_criticos)): ?>
                        <div class="col-md-6">
                            <h6><i class="fas fa-skull-crossbones text-danger"></i> Crítico</h6>
                            <?php foreach($alertas_criticos as $produto): ?>
                            <div class="d-flex justify-content-between align-items-center mb-2">
                                <span><?= htmlspecialchars($produto['nome']) ?></span>
                                <div>
                                    <span class="badge bg-danger">Zerado</span>
                                    <button class="btn btn-sm btn-outline-primary ms-2" 
                                            onclick="estoqueManager.showEntryModal(<?= $produto['id'] ?>)">
                                        <i class="fas fa-box"></i>
                                    </button>
                                </div>
                            </div>
                            <?php endforeach; ?>
                        </div>
                        <?php endif; ?>
                        
                        <?php if (!empty($alertas_aviso)): ?>
                        <div class="col-md-6">
                            <h6><i class="fas fa-exclamation-triangle text-warning"></i> Atenção</h6>
                            <?php foreach($alertas_aviso as $produto): ?>
                            <div class="d-flex justify-content-between align-items-center mb-2">
                                <span><?= htmlspecialchars($produto['nome']) ?></span>
                                <div>
                                    <span class="badge bg-warning">Baixo</span>
                                    <button class="btn btn-sm btn-outline-primary ms-2" 
                                            onclick="estoqueManager.showEntryModal(<?= $produto['id'] ?>)">
                                        <i class="fas fa-box"></i>
                                    </button>
                                </div>
                            </div>
                            <?php endforeach; ?>
                        </div>
                        <?php endif; ?>
                    </div>
                </div>
            </div>
        </div>
        <?php endif; ?>

        <!-- Filtros -->
        <div class="row mb-4">
            <div class="col-12">
                <div class="card">
                    <div class="card-header">
                        <h5 class="card-title mb-0">
                            <i class="fas fa-filter"></i> Filtros
                        </h5>
                    </div>
                    <div class="card-body">
                        <div class="row g-3">
                            <div class="col-md-4">
                                <label class="form-label">Categoria</label>
                                <select class="form-select" onchange="estoqueManager.filterProducts()">
                                    <option value="all">Todas as categorias</option>
                                    <?php foreach($todas_categorias as $categoria): ?>
                                    <option value="<?= $categoria['id'] ?>"><?= htmlspecialchars($categoria['nome']) ?></option>
                                    <?php endforeach; ?>
                                </select>
                            </div>
                            <div class="col-md-4">
                                <label class="form-label">Status</label>
                                <select class="form-select" onchange="estoqueManager.filterProducts()">
                                    <option value="all">Todos</option>
                                    <option value="normal">Normal</option>
                                    <option value="low">Baixo</option>
                                    <option value="critical">Crítico</option>
                                </select>
                            </div>
                            <div class="col-md-4">
                                <label class="form-label">Buscar</label>
                                <input type="text" class="form-control" placeholder="Nome do produto..." 
                                       onkeyup="estoqueManager.filterProducts()">
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Lista de Produtos -->
        <div class="row">
            <?php foreach($produtos_por_categoria as $categoria_id => $categoria_data): ?>
            <div class="col-12 mb-4">
                <div class="card">
                    <div class="card-header bg-light">
                        <h5 class="card-title mb-0">
                            <i class="fas fa-tag"></i> <?= htmlspecialchars($categoria_data['categoria_nome']) ?>
                        </h5>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table table-hover mb-0">
                                <thead class="table-light">
                                    <tr>
                                        <th>ID</th>
                                        <th>Produto</th>
                                        <th>Preço</th>
                                        <th>Estoque</th>
                                        <th>Mínimo</th>
                                        <th>Status</th>
                                        <th width="150">Ações</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php foreach($categoria_data['produtos'] as $produto): 
                                        $status_class = '';
                                        $status_text = '';
                                        $stock_class = '';
                                        
                                        if ($produto['estoque_atual'] == 0) {
                                            $status_class = 'status-critical';
                                            $status_text = 'Crítico';
                                            $stock_class = 'no-stock';
                                        } elseif ($produto['estoque_atual'] <= $produto['estoque_minimo']) {
                                            $status_class = 'status-low';
                                            $status_text = 'Baixo';
                                            $stock_class = 'low-stock';
                                        } else {
                                            $status_class = 'status-normal';
                                            $status_text = 'Normal';
                                        }
                                    ?>
                                    <tr class="product-row" 
                                        data-category="<?= $categoria_id ?>" 
                                        data-status="<?= strtolower($status_text) ?>"
                                        data-name="<?= htmlspecialchars(strtolower($produto['nome'])) ?>">
                                        <td><?= $produto['id'] ?></td>
                                        <td>
                                            <strong><?= htmlspecialchars($produto['nome']) ?></strong>
                                        </td>
                                        <td>R$ <?= number_format($produto['preco'], 2, ',', '.') ?></td>
                                        <td class="<?= $stock_class ?>">
                                            <?= $produto['estoque_atual'] ?>
                                        </td>
                                        <td><?= $produto['estoque_minimo'] ?></td>
                                        <td>
                                            <span class="status-badge <?= $status_class ?>">
                                                <?= $status_text ?>
                                            </span>
                                        </td>
                                        <td>
                                            <div class="btn-group btn-group-sm">
                                                <button class="btn btn-outline-primary" 
                                                        onclick="estoqueManager.editProduct(<?= $produto['id'] ?>)"
                                                        title="Editar">
                                                    <i class="fas fa-edit"></i>
                                                </button>
                                                <button class="btn btn-outline-success" 
                                                        onclick="estoqueManager.showEntryModal(<?= $produto['id'] ?>)"
                                                        title="Entrada">
                                                    <i class="fas fa-box"></i>
                                                </button>
                                                <button class="btn btn-outline-<?= $produto['ativo'] ? 'warning' : 'info' ?>" 
                                                        onclick="estoqueManager.toggleProduct(<?= $produto['id'] ?>, <?= $produto['ativo'] ? 0 : 1 ?>)"
                                                        title="<?= $produto['ativo'] ? 'Desativar' : 'Ativar' ?>">
                                                    <i class="fas fa-<?= $produto['ativo'] ? 'eye-slash' : 'eye' ?>"></i>
                                                </button>
                                            </div>
                                        </td>
                                    </tr>
                                    <?php endforeach; ?>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
            <?php endforeach; ?>
        </div>
    </div>

       <!-- Modal Entrada - CORRIGIDO -->
    <div class="modal fade" id="entryModal" tabindex="-1" aria-labelledby="entryModalLabel" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="entryModalLabel">Registrar Entrada</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Fechar"></button>
                </div>
                <div class="modal-body">
                    <form id="entryForm">
                        <input type="hidden" id="entryProductId">
                        <div class="mb-3">
                            <label class="form-label">Produto</label>
                            <div id="entryProductName" class="form-control-plaintext fw-bold"></div>
                        </div>
                        <div class="mb-3">
                            <label for="entryQuantity" class="form-label">Quantidade</label>
                            <input type="number" id="entryQuantity" class="form-control" min="1" required>
                        </div>
                        <div class="mb-3">
                            <label for="entrySupplier" class="form-label">Fornecedor</label>
                            <select id="entrySupplier" class="form-select">
                                <option value="">Selecione...</option>
                                <?php foreach($fornecedores as $fornecedor): ?>
                                <option value="<?= $fornecedor['id'] ?>"><?= htmlspecialchars($fornecedor['nome']) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <div class="mb-3">
                            <label for="entryNotes" class="form-label">Observação</label>
                            <textarea id="entryNotes" class="form-control" rows="3"></textarea>
                        </div>
                    </form>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
                    <button type="button" class="btn btn-primary" onclick="estoqueManager.registerEntry()">
                        Registrar Entrada
                    </button>
                </div>
            </div>
        </div>
    </div>

    <!-- Modal Produto - CORRIGIDO -->
    <div class="modal fade" id="productModal" tabindex="-1" aria-labelledby="productModalLabel" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="productModalLabel">Novo Produto</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Fechar"></button>
                </div>
                <div class="modal-body">
                    <form id="productForm">
                        <input type="hidden" id="productId">
                        <div class="mb-3">
                            <label for="productName" class="form-label">Nome</label>
                            <input type="text" id="productName" class="form-control" required>
                        </div>
                        <div class="mb-3">
                            <label for="productCategory" class="form-label">Categoria</label>
                            <select id="productCategory" class="form-select" required>
                                <option value="">Selecione...</option>
                                <?php foreach($todas_categorias as $categoria): ?>
                                <option value="<?= $categoria['id'] ?>"><?= htmlspecialchars($categoria['nome']) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <div class="mb-3">
                            <label for="productPrice" class="form-label">Preço</label>
                            <input type="number" id="productPrice" class="form-control" step="0.01" min="0" required>
                        </div>
                        <div class="mb-3">
                            <label for="productMinStock" class="form-label">Estoque Mínimo</label>
                            <input type="number" id="productMinStock" class="form-control" min="0" required>
                        </div>
                        <div class="mb-3">
                            <label for="productInitialStock" class="form-label">Estoque Inicial</label>
                            <input type="number" id="productInitialStock" class="form-control" min="0" value="0">
                        </div>
                    </form>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
                    <button type="button" class="btn btn-primary" onclick="estoqueManager.saveProduct()">
                        Salvar Produto
                    </button>
                </div>
            </div>
        </div>
    </div>

    <!-- Bootstrap JS -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    
    <!-- Estoque Manager -->
    <script src="/gestaointeli-jnr/modules/estoque/js/estoque-manager.js"></script>

    <script>
        // Inicializar quando DOM estiver pronto
        document.addEventListener('DOMContentLoaded', function() {
            estoqueManager.init();
        });
   
<!-- ✅ CORRIGIDO: Footer com verificação -->
<?php 
$footer_path = __DIR__ . '/../../includes/footer.php';
if (file_exists($footer_path)) {
    require_once $footer_path;
} else {
    echo '<footer class="bg-dark text-white text-center py-3 mt-5"><div class="container"><p>&copy; 2024 Sistema Estoque</p></div></footer>';
}
?>