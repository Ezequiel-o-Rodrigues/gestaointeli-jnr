<?php
require_once '../../config/database.php';
require_once '../../includes/functions.php';
require_once '../../includes/header.php';

$database = new Database();
$db = $database->getConnection();

// Dados para o dashboard
$query_dashboard = "SELECT * FROM view_dashboard";
$stmt_dashboard = $db->prepare($query_dashboard);
$stmt_dashboard->execute();
$dashboard = $stmt_dashboard->fetch(PDO::FETCH_ASSOC);

// Produtos mais vendidos
$query_top_produtos = "SELECT * FROM view_produtos_mais_vendidos LIMIT 10";
$stmt_top_produtos = $db->prepare($query_top_produtos);
$stmt_top_produtos->execute();
$top_produtos = $stmt_top_produtos->fetchAll(PDO::FETCH_ASSOC);
?>

<div class="relatorios-container">
    <h2>📊 Relatórios e Analytics</h2>
    
    <div class="dashboard-cards">
        <div class="dashboard-card">
            <h3>Vendas Hoje</h3>
            <div class="numero"><?= $dashboard['vendas_hoje'] ?? 0 ?></div>
            <p>Comandas fechadas</p>
        </div>
        
        <div class="dashboard-card">
            <h3>Faturamento Hoje</h3>
            <div class="numero"><?= formatarMoeda($dashboard['faturamento_hoje'] ?? 0) ?></div>
            <p>Valor total vendido</p>
        </div>
        
        <div class="dashboard-card">
            <h3>Alertas Estoque</h3>
            <div class="numero <?= ($dashboard['alertas_estoque'] ?? 0) > 0 ? 'alerta' : '' ?>">
                <?= $dashboard['alertas_estoque'] ?? 0 ?>
            </div>
            <p>Produtos com estoque baixo</p>
        </div>
        
        <div class="dashboard-card">
            <h3>Ticket Médio</h3>
            <div class="numero"><?= formatarMoeda($dashboard['ticket_medio'] ?? 0) ?></div>
            <p>Valor médio por comanda</p>
        </div>
    </div>

    <div class="relatorios-section">
        <div class="filtros-relatorios">
            <h3>Filtrar Relatórios</h3>
            <div class="filtros-grid">
                <div class="filtro-group">
                    <label>Data Início:</label>
                    <input type="date" id="data-inicio" class="form-input">
                </div>
                <div class="filtro-group">
                    <label>Data Fim:</label>
                    <input type="date" id="data-fim" class="form-input">
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
</style>

<?php require_once '../../includes/footer.php'; ?>