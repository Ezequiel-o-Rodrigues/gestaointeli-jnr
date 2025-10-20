<?php
// Definir URL base
$base_url = ' /gestaointeli-jnr/ ';

// Incluir arquivos com caminhos absolutos
require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/includes/functions.php';
require_once __DIR__ . '/includes/header.php';
?>

<div class="welcome-section">
    <h2>Bem-vindo ao Sistema de Gerenciamento</h2>
    <p>Selecione um módulo para começar:</p>
</div>

<div class="modules-grid">
    <div class="module-card" onclick="location.href='/gestaointeli-jnr/modules/caixa/index.php'">
        <h3>💰 Caixa</h3>
        <p>Gerenciar vendas e comandas</p>
    </div>

    <div class="module-card" onclick="location.href='/gestaointeli-jnr/modules/estoque/index.php'">
        <h3>📦 Estoque</h3>
        <p>Controle de produtos e reposição</p>
    </div>

    <div class="module-card" onclick="location.href='/gestaointeli-jnr/modules/relatorios/index.php'">
        <h3>📊 Relatórios</h3>
        <p>Análises e métricas</p>
    </div>

    <div class="module-card" onclick="location.href='/gestaointeli-jnr/modules/admin/index.php'">
        <h3>⚙️ Admin</h3>
        <p>Configurações do sistema</p>
    </div>
</div>

<style>
.modules-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 2rem;
    margin: 3rem 0;
}

.module-card {
    background: white;
    padding: 2rem;
    border-radius: 10px;
    text-align: center;
    cursor: pointer;
    transition: all 0.3s;
    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
}

.module-card:hover {
    transform: translateY(-5px);
    box-shadow: 0 5px 20px rgba(0,0,0,0.15);
}

.module-card h3 {
    margin-bottom: 1rem;
    color: #2c3e50;
}
</style>

<?php 
require_once __DIR__ . '/includes/footer.php'; 
?>