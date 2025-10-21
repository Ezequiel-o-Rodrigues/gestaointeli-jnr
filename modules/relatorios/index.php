<?php
require_once '../../config/database.php';
require_once '../../includes/functions.php';
require_once '../../includes/header.php';

$database = new Database();
$db = $database->getConnection();

// Dados para o dashboard - usando view aprimorada se existir, senão usa a básica
try {
    $query_dashboard = "SHOW TABLES LIKE 'view_dashboard_aprimorado'";
    $stmt_check = $db->prepare($query_dashboard);
    $stmt_check->execute();
    
    if ($stmt_check->rowCount() > 0) {
        $query_dashboard = "SELECT * FROM view_dashboard_aprimorado";
    } else {
        $query_dashboard = "SELECT * FROM view_dashboard";
    }
    
    $stmt_dashboard = $db->prepare($query_dashboard);
    $stmt_dashboard->execute();
    $dashboard = $stmt_dashboard->fetch(PDO::FETCH_ASSOC);
    
} catch (Exception $e) {
    // Fallback para dados básicos
    $dashboard = [
        'vendas_hoje' => 0,
        'faturamento_hoje' => 0,
        'alertas_estoque' => 0,
        'ticket_medio' => 0
    ];
}

// Produtos mais vendidos
try {
    $query_top_produtos = "SELECT * FROM view_produtos_mais_vendidos LIMIT 10";
    $stmt_top_produtos = $db->prepare($query_top_produtos);
    $stmt_top_produtos->execute();
    $top_produtos = $stmt_top_produtos->fetchAll(PDO::FETCH_ASSOC);
} catch (Exception $e) {
    $top_produtos = [];
}

// Alertas de perda
try {
    $query_alertas = "SHOW TABLES LIKE 'view_alertas_perda_estoque'";
    $stmt_check_alerta = $db->prepare($query_alertas);
    $stmt_check_alerta->execute();
    
    if ($stmt_check_alerta->rowCount() > 0) {
        $query_alertas = "SELECT COUNT(*) as total FROM view_alertas_perda_estoque WHERE diferenca_estoque > 0";
        $stmt_alertas = $db->prepare($query_alertas);
        $stmt_alertas->execute();
        $total_alertas = $stmt_alertas->fetch(PDO::FETCH_ASSOC)['total'] ?? 0;
    } else {
        $total_alertas = 0;
    }
} catch (Exception $e) {
    $total_alertas = 0;
}
?>

<div class="relatorios-container">
    <h2>📊 Relatórios e Analytics</h2>
    
    <div class="dashboard-cards">
        <div class="dashboard-card">
            <h3>Vendas Hoje</h3>
            <div class="numero"><?= $dashboard['vendas_hoje'] ?? 0 ?></div>
            <p>Comandas fechadas hoje</p>
        </div>
        
        <div class="dashboard-card">
            <h3>Faturamento Hoje</h3>
            <div class="numero"><?= formatarMoeda($dashboard['faturamento_hoje'] ?? 0) ?></div>
            <p>Valor vendido hoje</p>
        </div>
        
        <div class="dashboard-card <?= ($dashboard['alertas_estoque'] ?? 0) > 0 ? 'alerta' : '' ?>">
            <h3>Alertas Estoque</h3>
            <div class="numero <?= ($dashboard['alertas_estoque'] ?? 0) > 0 ? 'alerta' : '' ?>">
                <?= $dashboard['alertas_estoque'] ?? 0 ?>
            </div>
            <p>Produtos com estoque baixo</p>
        </div>
        
        <div class="dashboard-card <?= $total_alertas > 0 ? 'alerta' : '' ?>">
            <h3>Perdas Identificadas</h3>
            <div class="numero <?= $total_alertas > 0 ? 'alerta' : '' ?>">
                <?= $total_alertas ?>
            </div>
            <p>Diferenças no estoque</p>
        </div>
    </div>

    <!-- Seção de Alertas de Perda -->
    <div id="alertas-perda-container" class="alertas-section">
        <div class="alerta-item sucesso">Carregando alertas...</div>
    </div>

    <div class="relatorios-section">
        <div class="filtros-relatorios">
            <h3>Filtrar Relatórios</h3>
            <div class="filtros-grid">
                <div class="filtro-group">
                    <label>Data Início:</label>
                    <input type="date" id="data-inicio" class="form-input" value="<?= date('Y-m-d', strtotime('-7 days')) ?>">
                </div>
                <div class="filtro-group">
                    <label>Data Fim:</label>
                    <input type="date" id="data-fim" class="form-input" value="<?= date('Y-m-d') ?>">
                </div>
                <div class="filtro-group">
                    <label>Tipo de Relatório:</label>
                    <select id="tipo-relatorio" class="form-select">
                        <option value="vendas">Vendas por Período</option>
                        <option value="produtos">Produtos Mais Vendidos</option>
                        <option value="estoque">Movimentação de Estoque</option>
                    </select>
                </div>
                <div class="filtro-group">
                    <button class="btn btn-primary" onclick="gerarRelatorio()">Gerar Relatório</button>
                    <button class="btn" onclick="exportarRelatorio()">📥 Exportar</button>
                </div>
            </div>
        </div>

        <div class="resultados-relatorio">
            <h3>Produtos Mais Vendidos (Top 10)</h3>
            <?php if (count($top_produtos) > 0): ?>
            <div class="table-responsive">
                <table class="table">
                    <thead>
                        <tr>
                            <th>Produto</th>
                            <th>Categoria</th>
                            <th>Quantidade</th>
                            <th>Valor Total</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach($top_produtos as $produto): ?>
                        <tr>
                            <td><?= htmlspecialchars($produto['nome']) ?></td>
                            <td><?= htmlspecialchars($produto['categoria']) ?></td>
                            <td><?= $produto['total_vendido'] ?></td>
                            <td><?= formatarMoeda($produto['valor_total_vendido']) ?></td>
                        </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
            <?php else: ?>
            <div class="sem-dados">Nenhum dado disponível</div>
            <?php endif; ?>
        </div>

        <div class="graficos-section">
            <div class="grafico-card">
                <h4>Vendas por Dia (Últimos 7 dias)</h4>
                <canvas id="grafico-vendas"></canvas>
            </div>
            <div class="grafico-card">
                <h4>Top Categorias</h4>
                <canvas id="grafico-categorias"></canvas>
            </div>
            <div class="grafico-card">
                <h4>Vendas Mensais</h4>
                <canvas id="grafico-mensal"></canvas>
            </div>
        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script src="relatorios.js"></script>

<style>
.dashboard-cards {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 1.5rem;
    margin: 2rem 0;
}

.dashboard-card {
    background: white;
    padding: 1.5rem;
    border-radius: 10px;
    text-align: center;
    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    border-left: 4px solid #3498db;
}

.dashboard-card.alerta {
    border-left-color: #e74c3c;
}

.dashboard-card .numero {
    font-size: 2.5rem;
    font-weight: bold;
    color: #2c3e50;
    margin: 0.5rem 0;
}

.dashboard-card .numero.alerta {
    color: #e74c3c;
}

.alertas-section {
    background: #fff3cd;
    border: 1px solid #ffeaa7;
    border-radius: 10px;
    padding: 1.5rem;
    margin: 1rem 0;
}

.alerta-item {
    padding: 1rem;
    margin: 0.5rem 0;
    border-radius: 5px;
    border-left: 4px solid #e74c3c;
    background: white;
}

.alerta-item.perda {
    background: #f8d7da;
    border-left-color: #dc3545;
}

.alerta-item.sucesso {
    background: #d1edff;
    border-left-color: #3498db;
}

.filtros-relatorios {
    background: white;
    padding: 1.5rem;
    border-radius: 10px;
    margin: 2rem 0;
}

.filtros-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1rem;
    align-items: end;
}

.filtro-group {
    display: flex;
    flex-direction: column;
}

.graficos-section {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
    gap: 2rem;
    margin: 2rem 0;
}

.grafico-card {
    background: white;
    padding: 1.5rem;
    border-radius: 10px;
    height: 300px;
}

.sem-dados {
    text-align: center;
    padding: 2rem;
    color: #7f8c8d;
    font-style: italic;
    background: #f8f9fa;
    border-radius: 5px;
}
</style>

<?php require_once '../../includes/footer.php'; ?>